#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <engine>
#include <ttt>

#define logdir "addons/amxmodx/logs/ttt"
#define TTT_LOG_SIZE 192

new g_szFileNames[2][64] = {"", "addons/amxmodx/logs/ttt/ttt_errors.log"};
new g_iDamageHolder[33][33]; //ATTACKER - VICTIM
new cvar_logging, cvar_logging_error, cvar_logging_type;

new const g_szLogMessages[][] =
{
	"DEFAULT",
	"ERROR",
	"GAMETYPE",
	"ITEM",
	"KILL",
	"DAMAGE",
	"MISC"
};

public plugin_init()
{
	register_plugin("[TTT] Logging", TTT_VERSION, TTT_AUTHOR);

	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_post", 1, true);
	RegisterHam(Ham_Killed, "player", "Ham_Killed_post", 1, true);

	cvar_logging				= my_register_cvar("ttt_logging",			"1");
	cvar_logging_error			= my_register_cvar("ttt_logging_error",		"1");// separate error logs
	cvar_logging_type			= my_register_cvar("ttt_logging_type",		"abcdefg"); // a=default, b=error, c=gametype, d=item, e=kill, f=damage, g=misc

	new time[10];
	get_time("%Y%m%d", time, charsmax(time)); 
	formatex(g_szFileNames[0], charsmax(g_szFileNames[]), "%s/TTT%s.log", logdir, time);
	
	new out[64], mapname[32];
	get_mapname(mapname, charsmax(mapname));
	formatex(out, charsmax(out), "Map changed to %s", mapname);
	add_to_log(LOG_DEFAULT, out);
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_log_to_file", "_log_to_file");
}

public client_putinserver(id)
{
	static name[32], out[64];
	get_user_name(id, name, charsmax(name));
	formatex(out, charsmax(out), "%s joined the game", name);
	add_to_log(LOG_DEFAULT, out);
}

public client_disconnect(id)
{
	new num, victim;
	static players[32], name[32], out[64];
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		victim = players[num];
		g_iDamageHolder[id][victim] = 0;
	}

	get_user_name(id, name, charsmax(name));
	formatex(out, charsmax(out), "%s disconnected", name);
	add_to_log(LOG_DEFAULT, out);
}

public ttt_gamemode(gamemode)
{
	if(gamemode == ENDED)
	{
		static players[32];
		new num, attacker;

		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			attacker = players[num];
			log_all_damage(attacker);
		}
	}
}

public log_all_damage(attacker)
{
	static players[32], ids[2];
	new num, victim;

	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		victim = players[num];
		if(g_iDamageHolder[attacker][victim] > 0)
		{
			ids[0] = attacker;
			ids[1] = victim;
			set_task(0.1, "log_damage", _, ids, 2);
		}
	}
}

public Ham_Killed_post(victim, killer, shouldgib)
{
	if(ttt_return_check(killer))
		return;

	static name[32], killmsg[64], msg[TTT_LOG_SIZE];
	get_user_name(victim, name, charsmax(name));
	ttt_get_kill_message(victim, killer, killmsg, charsmax(killmsg), 1);

	formatex(msg, charsmax(msg), "[%L] %s was killed by %s", LANG_PLAYER, special_names[ttt_get_playerdata(victim, PD_KILLEDSTATE)], name, killmsg);
	add_to_log(LOG_KILL, msg);

	new ids[2];
	ids[0] = killer;
	ids[1] = victim;
	set_task(0.1, "log_damage", _, ids, 2);
}

public Ham_TakeDamage_post(victim, inflictor, attacker, Float:damage, DamageBits)
{
	if(ttt_return_check(attacker))
		return;

	new dmg = floatround(entity_get_float(victim, EV_FL_dmg_take));
	g_iDamageHolder[attacker][victim] += dmg;
}

public log_damage(param[])
{
	new attacker = param[0], victim = param[1];
	if(g_iDamageHolder[attacker][victim] > 0)
	{
		new aliveV = ttt_get_special_alive(victim), aliveK = ttt_get_special_alive(attacker);
		static name[2][32];
		
		get_user_name(attacker, name[0], charsmax(name[]));
		get_user_name(victim, name[1], charsmax(name[]));
		
		new msg[TTT_LOG_SIZE];
		formatex(msg, charsmax(msg), "[%L] %s attacked [%L] %s with %d damage", LANG_PLAYER, special_names[aliveV], name[0], LANG_PLAYER, special_names[aliveK], name[1], g_iDamageHolder[attacker][victim]);
		add_to_log(LOG_DAMAGE, msg);
		g_iDamageHolder[attacker][victim] = 0;
	}
}

public _log_to_file(plugin, params)
{
	new cvar = get_pcvar_num(cvar_logging);

	if(!cvar)
		return -1;

	new type = get_param(1);
	if(params != 2)
		return add_to_log(LOG_ERROR, "Wrong number of params (ttt_log_to_file)");

	static msg[TTT_LOG_SIZE];
	get_string(2, msg, charsmax(msg));
	add_to_log(type, msg);

	return 0;
}

stock add_to_log(type, msg[])
{
	if(!get_pcvar_num(cvar_logging))
		return 0;

	new num;
	static players[32];
	get_players(players, num);
	if(num < 3 && (type != LOG_ERROR && type != LOG_DEFAULT))
		return 0;

	static cvar[10];
	get_pcvar_string(cvar_logging_type, cvar, charsmax(cvar));
	if(!cvar[0])
		return 0;

	if(read_flags(cvar) & type)
	{
		static out[TTT_LOG_SIZE], time[24];
		get_time("%m/%d/%Y - %H:%M:%S", time, charsmax(time));
		format(out, charsmax(out), "[TTT] %s: [%s] --- %s", time, g_szLogMessages[bit_to_int(type)], msg);
		write_to_file(g_szFileNames[0], out);

		if(type == LOG_ERROR && get_pcvar_num(cvar_logging_error))
			write_to_file(g_szFileNames[1], out);
		return 1;
	}

	return 0;
}

stock write_to_file(file[], msg[])
{
	if(!dir_exists(logdir))
		mkdir(logdir);

	if(!file_exists(file))
	{
		new filenew = fopen(file, "wt");
		fclose(filenew);
	}

	write_file(file, msg);
}

// AKA log2(n)
stock bit_to_int(n)
{
	new count;
	while(n != 1)
	{
		n = n/2;
		count++;
		if(count > 7)
			break;
	}

	return count;
}