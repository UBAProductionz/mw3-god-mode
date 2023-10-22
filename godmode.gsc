/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
These are all of the functions / lines repsonsible for the god mode glitch in MW3 and Ghosts.
An explanation of how to do this glitch and how it came to be are the following:

How to get god mode:
    1. Set the game mode to search & destroy
    2. Set lives to unlimited
    3. Enable a bomb carrier class

    4. Spawn on the attacking team and get a predator missile
    5. Pull out the predator and step over the bomb right before you get put into it
    6. Die

You are now invisible and invincible.

How it came to be:

The MW2 devs came up with a tertiary player state called fauxDead that exists in between life and death
so that the player is technically still "alive" if they are killed while using a killstreak.

isFauxDead is only true when isUsingRemote is also true. Meaning a faux death will only happen while the
player is using a ridable killstreak.

While the player is faux dead, they are both invisible and invincible.

The MW2 devs wrote the initRideKillstreak_internal function under the assumption that a player must die
before respawning.

During the development of MW2, many of the devs left Activision and founded Respawn Entertainment.
This forced Activision to replace them with people from Sledgehammer and other studios in order to release MW3.
For whatever reason, they ignored the aforementioned assumption and decided to implement a bomb carrier
class in private match for game modes such as search and destroy and capture the flag. This feature not 
only applies a new loadout, but it also fully respawns the player without them ever dying.

When opening up the laptop, the function killstreakUseWaiter is called and a notify and endon for it go out.
This means that only one instance of the function can be running at a time for each player.
Right after this, isUsingremote gets set to true.

During a 1 second interval before the killstreak begins, it checks to make sure the player didn't disconnect,
die, or switch back to their other weapon, which would cancel the killstreak. 

God mode happens when the player steps over the bomb within this 1 second interval.

The player is respawned, and a new instance of killstreakUseWaiter gets called, ending the previous one.
Since all of the function calls for the killstreak nested within the old instance of killstreakUseWaiter 
aren't threaded, none of them ever return. It's as if the killstreak is forever frozen in that 1 second interval.

Since isUsingremote was already set at this point but the control lock for the killstreak hasn't happened yet,
the player is free to move around like normal. But since isUsingRemote is set to true, their next death will
still be a faux death. This makes them invisible, invincible, and able to run around and shoot at the same time.
*/

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// determines if the player is alive or faux dead / actually dead
isReallyAlive( player )
{
	if ( isAlive( player ) && !isDefined( player.fauxDead ) )
		return true;
		
	return false;
}


// why player doesn't take damage in faux death
Callback_PlayerDamage_internal( eInflictor, eAttacker, victim, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{	
	if ( !isReallyAlive( victim ) )
		return;
}


// why player is invisible in faux death
PlayerKilled_internal( eInflictor, attacker, victim, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration, isFauxDeath )
{
    if ( isFauxDeath )
		victim PlayerHide();
}


// kills the player with a faux death only if they're using a killstreak
_suicide()
{
	if ( self isUsingRemote() && !isDefined( self.fauxDead ) )
		self thread maps\mp\gametypes\_damage::PlayerKilled_internal( self, self, self, 10000, "MOD_SUICIDE", "frag_grenade_mp", (0,0,0), "none", 0, 1116, true );

	else if( !self isUsingRemote() && !isDefined( self.fauxDead ) )
		self suicide();	
}


Callback_PlayerDamage_internal( eInflictor, eAttacker, victim, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{	
	victim finishPlayerDamageWrapper( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime, stunFraction );
}


finishPlayerDamageWrapper( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime, stunFraction )
{
	if ( (self isUsingRemote() ) && (iDamage >= self.health) && !(iDFlags & level.iDFLAGS_STUN) )
	{
		PlayerKilled_internal( eInflictor, eAttacker, self, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, 0, true );
	}
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// assigns tryUsePredatorMissile to the global killstreakfuncs
// this is the init for the remote missile file
init()
{
    level.killstreakFuncs["predator_missile"] = ::tryUsePredatorMissile;
}


// gets called every time the player respawns.
// ends any previous instances of the function.
killstreakUseWaiter()
{
    self notify( "killstreakUseWaiter" );
    self endon( "killstreakUseWaiter" );

    for (;;)
    {
        self waittill( "weapon_change",  var_0  );
        killstreakUsePressed();
    }
}


// starts the killstreak code. (if taking out a predator, tryUsePredatorMissile is called here)
killstreakUsePressed()
{   
    streakName = self.pers["killstreaks"][self.killstreakIndexWeapon].streakName;
    lifeId = self.pers["killstreaks"][self.killstreakIndexWeapon].lifeId;

    if ( !self [[ level.killstreakFuncs[streakName] ]]( lifeId ) )
        return 0;
}


// makes it so isUsingRemote is true and starts ridable killstreak code
tryUsePredatorMissile( var_0 )
{
    maps\mp\_utility::setUsingRemote( "remotemissile" );
    maps\mp\killstreaks\_killstreaks::initRideKillstreak();
}


// useless wrapper function?
initRideKillstreak( var_0 )
{
    initRideKillstreak_internal( var_0 );
}


/*
    while the laptop is out and the player is about to enter the killstreak, this waits 1 second to see if
    the player either disconnected, died, or switched back to a different weapon. it will cancel the
    killstreak and reset variables such as isUsingRemote if any of those happen.
*/
initRideKillstreak_internal( var_0 )
{
    common_scripts\utility::waittill_any_timeout( 1.0, "disconnect", "death", "weapon_switch_started" );
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// applying the bomb carrier class actually respawns the player
// instead of just giving the loadout.
applyBombCarrierClass()
{
    thread maps\mp\gametypes\_playerlogic::spawnPlayer( 1 );
}


// when a player spawns it sends out a notify
spawnPlayer( var_0 )
{
    self notify( "spawned_player" );
}


// any time the player spawns, killstreakUseWaiter gets called
onPlayerSpawned()
{
    for (;;)
    {
        self waittill( "spawned_player" );
        thread killstreakUseWaiter();
    }
}