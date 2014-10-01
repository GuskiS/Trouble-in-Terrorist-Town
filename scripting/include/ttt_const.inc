#if defined _ttt_const_included
  #endinput
#endif
#define _ttt_const_included

#define TTT_VERSION "2.4.2"
#define TTT_AUTHOR "GuskiS"
#define TTT_TAG				"^3[^4TTT^3]^1"

#define TTT_DEADBODY		"ttt_dead_body"
#define TTT_HPSTATION		"ttt_hp_station"
#define TTT_DEATHSTATION	"ttt_death_station"
#define TTT_C4_SUB			"ttt_c4_subent"

#define TTT_TOTAL_BACKPACK	20 // Max backpack items.
#define TTT_ITEMNAME		64 // Max length of items name.
#define TTT_MAXFILELENGHT	64
#define TTT_SETTINGSFILE	"ttt_mod.ini"
#define TTT_CONFIGFILE		"ttt_mod.cfg"

#define TTT_IGNORED		1
#define TTT_HANDLED		2
#define TTT_OVERRIDE	3
#define TTT_SUPERCEDE	4

#pragma semicolon 1

stock const g_iTeamColors[][] =
{
	{0, 255, 0},
	{255, 50, 0},
	{0, 50, 255},
	{0, 255, 0},
	{0, 255, 0},
	{0, 0, 0}
};

enum _:Stats
{
	STATS_GWK,			// Game winning kills
	STATS_KILLS_I,		// Kills as Innocent // Right ones
	STATS_KILLS_D,		// Kills as Detective
	STATS_KILLS_T,		// Kills as Traitor
	STATS_RDM,			// Team kills
	STATS_INN,			// Times innocent
	STATS_DET,			// Times detective
	STATS_TRA,			// Times traitor
	STATS_BOMBP,		// Bomb planted
	STATS_BOMBE,		// Bomb exploded
	STATS_BOMBD,		// Bomb defused
	STATS_POINTS		// Total points
}

enum _:LogMessages(<<= 1)
{
	LOG_DEFAULT = 1,
	LOG_ERROR,
	LOG_GAMETYPE,
	LOG_ITEM,
	LOG_KILL,
	LOG_DAMAGE,
	LOG_MISC
}

enum _:BodyData
{
	BODY_TIME,		// DNA active time
	BODY_KILLER,	// ID who killed
	BODY_TRACER,	// ID who is tracing killer
	BODY_ACTIVE,	// Is actually tracing happening
	BODY_ENTID,		// Bodies entid
	BODY_CALLD		// Does this body calls Detective to inspect it?
}

enum _:SetupData
{
	SETUP_ITEMID,		// Item ID obviously
	SETUP_ITEMENT,		// Set up items entid
	SETUP_ITEMTIME,		// Time for DNA, I think
	SETUP_ITEMOWNER,	// Items owner ID
	SETUP_ITEMTRACER,	// Tracers ID
	SETUP_ITEMACTIVE,	// Is tracing active
	SETUP_ITEMNAME[32]	// Items name
}

enum _:PlayerData
{
	PD_KILLEDBY,		// Killers ID
	PD_KILLEDWEAP,		// Weapons ID
	PD_KILLEDTIME,		// Some time, get_roundtime I guess
	PD_KILLEDSTATE,		// Killed state
	PD_KILLEDDEATHS,	// Players death count
	PD_KILLCOUNT,		// Players kill count
	PD_IDENTIFIED,		// Is he identified?
	PD_KARMA,			// Players karma, the one used in damge calculations
	PD_KARMATEMP,		// Temporary karma, the one actually being changed all the time
	PD_KARMASELF,		// If >0 this will be given to player. Usefull if kills him self, cause then karma is reduced
	PD_CREDITS,			// Players credits
	PD_C4EXPLODED,		// Did he explode C4 :O
	PD_SCOREBOARD,		// Holds info about scoreboard (1 means cant change)
	PD_PLAYERSTATE,		// Why the fuck is this last one? ;o
	PD_KILLEDBYITEM     // If killed by item, stores that item ID
}

enum _:Special
{
	NONE,
	TRAITOR,
	DETECTIVE,
	INNOCENT,
	DEAD,
	SPECIAL
}

enum _:Game
{
	UNSET,
	OFF,
	PREPARING,
	RESTARTING,
	STARTED,
	ENDED
}

enum _:DEATHS(+= 1)
{
	DEATHS_SUICIDE = 3000,
	DEATHS_GENERIC,
	DEATHS_SLASH,
	DEATHS_BURN,
	DEATHS_FREEZE,
	DEATHS_FALL,
	DEATHS_BLAST,
	DEATHS_SHOCK,
	DEATHS_DROWN,
	DEATHS_NERVEGAS,
	DEATHS_POISON,
	DEATHS_RADIATION,
	DEATHS_ACID
}