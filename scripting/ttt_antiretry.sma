#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <sqlx>
#include <fun>
#include <ttt>

#define m_bitsDamageType 	76

new Handle:g_pSqlTuple, pluginon;
new g_szUserIP[33][20];
new g_iWarnings[33][3], g_iUserBanned[33], g_iUserPunish[33], g_iBadAim[33]; // 0 = special, 1 = innocent, 2 = continued
new cvar_ar_warnings_innocent, cvar_ar_warnings_special, cvar_ar_warnings_punishment, cvar_ar_warnings_bantime,
	cvar_ar_on, cvar_ar_warnings_continued, cvar_ar_warnings_players, cvar_ar_warnings_blind_time;

new g_pMsg_ScreeFade;

public plugin_init()
{
	register_plugin("[TTT] AntiRetry & Warning system", TTT_VERSION, TTT_AUTHOR);

	cvar_ar_on 					= my_register_cvar("ttt_ar_on",						"0");
	cvar_ar_warnings_special	= my_register_cvar("ttt_ar_warnings_special",		"3");
	cvar_ar_warnings_innocent	= my_register_cvar("ttt_ar_warnings_innocent",		"5");
	cvar_ar_warnings_continued	= my_register_cvar("ttt_ar_warnings_continued",		"3");
	cvar_ar_warnings_punishment	= my_register_cvar("ttt_ar_warnings_punishment",	"cdf");
	cvar_ar_warnings_bantime	= my_register_cvar("ttt_ar_warnings_bantime",		"60");
	cvar_ar_warnings_players	= my_register_cvar("ttt_ar_warnings_players",		"5");
	cvar_ar_warnings_blind_time	= my_register_cvar("ttt_ar_warnings_blind_time",	"60");

	register_clcmd("say /tttwarns", "check_warnings");
	register_clcmd("say_team /tttwarns", "check_warnings");

	RegisterHam(Ham_Killed, "player", "Ham_Killed_post", 1, true);
	RegisterHam(Ham_Spawn, "player", "Ham_Spawn_pre", 0, true);
	register_forward(FM_TraceLine, "Forward_TraceLine_post", 1);

	pluginon = get_pcvar_num(cvar_ar_on);
	g_pMsg_ScreeFade	=	get_user_msgid("ScreenFade");
}

public plugin_cfg()
	set_task(1.0, "check_plugin");

public check_plugin()
{
	pluginon = get_pcvar_num(cvar_ar_on);
	if(pluginon)
		MySQL_Init();
}

public plugin_end()
{
	if(pluginon)
	{
		table_clear();
		SQL_FreeHandle(g_pSqlTuple);
	}
}

public client_putinserver(id)
{
	if(pluginon)
	{
		reset_client(id);
		get_user_ip(id, g_szUserIP[id], charsmax(g_szUserIP[]), 1);
		MySQL_Load(id);
	}
}

public client_disconnect(id)
{
	if(pluginon)
	{
		MySQL_Save(id);
		reset_client(id);
	}
}

public ttt_gamemode(gamemode)
{
	if(pluginon && gamemode == RESTARTING)
	{
		table_clear();
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			table_insert(id);
		}
	}
}

public Ham_Spawn_pre(id)
{
	if(pluginon)
	{
		if(g_iUserPunish[id])
		{
			ttt_set_playerdata(id, PD_KARMA, 1);
			ttt_set_playerdata(id, PD_KARMATEMP, 1);
			client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_PUNISHMENT1");
			reset_client(id);
		}

		check_warnings(id);
	}
}

public Ham_Killed_post(victim, killer, shouldgib)
{
	if(!is_user_alive(killer) || killer == victim || (get_pdata_int(victim, m_bitsDamageType, 5) & DMG_BLAST)
		|| !pluginon || ttt_return_check(victim) || ttt_get_playerdata(victim, PD_KILLEDBYITEM) > -1)
		return;

	new state_killer = ttt_get_special_state(killer), state_victim = ttt_get_playerdata(victim, PD_KILLEDSTATE);
	if(state_killer == TRAITOR && state_victim == TRAITOR)
		add_warnings(killer, state_killer, state_victim, 0);
	else if((state_killer == DETECTIVE && state_victim == DETECTIVE) || (state_killer == INNOCENT && state_victim == DETECTIVE))
		add_warnings(killer, state_killer, state_victim, 0);
	else if((state_killer == INNOCENT && state_victim == INNOCENT) || (state_killer == DETECTIVE && state_victim == INNOCENT))
		add_warnings(killer, state_killer, state_victim, 1);
	else g_iWarnings[killer][2] = 0;
}

public Forward_TraceLine_post(Float:v1[3], Float:v2[3], noMonsters, id)
{
	if(!is_user_alive(id) || !g_iBadAim[id])
		return FMRES_IGNORED;

	new target = get_tr(TR_pHit);
	if(!is_user_alive(target))
		return FMRES_IGNORED;

	new hitzone = (1 << get_tr(TR_iHitgroup));
	if(g_iBadAim[id] & hitzone)
	{
		set_tr(TR_flFraction, 1.0);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

public MySQL_Init()
{
	static host[64], user[33], pass[32], db[32];
	get_cvar_string("amx_sql_host", host, charsmax(host));
	get_cvar_string("amx_sql_user", user, charsmax(user));
	get_cvar_string("amx_sql_pass", pass, charsmax(pass));
	get_cvar_string("amx_sql_db", db, charsmax(db));

	g_pSqlTuple = SQL_MakeDbTuple(host, user, pass, db);

	static error[128];
	new errorCode, Handle:SqlConnection = SQL_Connect(g_pSqlTuple, errorCode, error, charsmax(error));
	if(SqlConnection == Empty_Handle)
		set_fail_state(error);

	new Handle:queries = SQL_PrepareQuery(SqlConnection, "CREATE TABLE IF NOT EXISTS ttt_antiretry (id int(8) unsigned NOT NULL auto_increment, ip varchar(20) UNIQUE NOT NULL default '', karma int(8), warnings_s int(3), warnings_i int(3), punish int(3), PRIMARY KEY (id))");

	if(!SQL_Execute(queries))
	{
		SQL_QueryError(queries, error, charsmax(error));
		set_fail_state(error);
	}

	SQL_FreeHandle(queries);
	SQL_FreeHandle(SqlConnection); 
}

public MySQL_Load(id)
{
	if(!is_user_connected(id))
		return;

	static data[2];
	data[0] = id;

	static temp[96];
	formatex(temp, charsmax(temp), "SELECT * FROM ttt_antiretry WHERE ip = '%s'", g_szUserIP[id]);
	SQL_ThreadQuery(g_pSqlTuple, "register_client", temp, data, 1);
}

public MySQL_Save(id)
{
	if(!is_user_connected(id))
		return;

	static temp[192];
	if(g_iUserBanned[id])
		formatex(temp, charsmax(temp), "UPDATE ttt_antiretry SET karma = '500', warnings_s = '0', warnings_i = '0', punish = '0' WHERE ip = '%s'", g_szUserIP[id]);
	else formatex(temp, charsmax(temp), "UPDATE ttt_antiretry SET karma = '%d', warnings_s = '%d', warnings_i = '%d', punish = '%d' WHERE ip = '%s'", ttt_get_playerdata(id, PD_KARMATEMP), g_iWarnings[id][0], g_iWarnings[id][1], g_iUserPunish[id], g_szUserIP[id]);

	SQL_ThreadQuery(g_pSqlTuple, "IgnoreHandle", temp);
}

public register_client(failstate, Handle:query, error[], errcode, data[], datasize)
{
	if(failstate == TQUERY_CONNECT_FAILED)
		log_amx("%s Load - Could not connect to SQL database.  [%d] %s", TTT_TAG, errcode, error);
	else if(failstate == TQUERY_QUERY_FAILED)
		log_amx("%s Load query failed. [%d] %s", TTT_TAG, errcode, error);

	new id = data[0];
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	if(SQL_NumResults(query) > 0) 
	{
		new karma = SQL_ReadResult(query, 2);
		new warnings_s = SQL_ReadResult(query, 3);
		new warnings_i = SQL_ReadResult(query, 4);
		new punish = SQL_ReadResult(query, 5);

		if(karma > 0)
		{
			ttt_set_playerdata(id, PD_KARMATEMP, karma);
			ttt_set_playerdata(id, PD_KARMA, karma);
		}

		if(warnings_s > 0)
			g_iWarnings[id][0] = warnings_s;
		if(warnings_i > 0)
			g_iWarnings[id][1] = warnings_i;
		if(punish > 0)
			g_iUserPunish[id] = true;
	}
	else table_insert(id);

	return PLUGIN_HANDLED;
}

public IgnoreHandle(failstate, Handle:query, error[], errcode, data[], datasize)
{
	SQL_FreeHandle(query);
	return PLUGIN_HANDLED;
}

public add_warnings(killer, state_killer, state_victim, type)
{
	new num;
	static players[32];
	get_players(players, num);
	
	if(num-1 < get_pcvar_num(cvar_ar_warnings_players))
		return;

	if(type)
		g_iWarnings[killer][1]++;
	else g_iWarnings[killer][0]++;
	g_iWarnings[killer][2]++;

	ttt_set_stats(killer, STATS_RDM, ttt_get_player_stat(killer, STATS_RDM)+1);
	new special = get_pcvar_num(cvar_ar_warnings_special), innocent = get_pcvar_num(cvar_ar_warnings_innocent), continued = get_pcvar_num(cvar_ar_warnings_continued);

	if(g_iWarnings[killer][0] >= special || g_iWarnings[killer][1] >= innocent || g_iWarnings[killer][2] >= continued)
		punish_player(killer);
	else if(type == 0)
	{
		client_print_color(killer, print_team_default, "%s %L", TTT_TAG, killer, "TTT_WARNING1", killer, special_names[state_killer], killer, special_names[state_victim]);
		check_warnings(killer);
	}
}

public check_warnings(id)
{
	if(ttt_get_special_state(id) != INNOCENT && pluginon)
	{
		new specialKill = get_pcvar_num(cvar_ar_warnings_special), innocentKill = get_pcvar_num(cvar_ar_warnings_innocent), continued = get_pcvar_num(cvar_ar_warnings_continued);
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_WARNING2", g_iWarnings[id][0], specialKill, id, special_names[SPECIAL], g_iWarnings[id][1], innocentKill, id, special_names[INNOCENT], g_iWarnings[id][2], continued);
	}
}

public punish_player(id)
{
	if(!is_user_connected(id))
		return;

	static cvar[10];
	get_pcvar_string(cvar_ar_warnings_punishment, cvar, charsmax(cvar));
	if(!cvar[0])
		return;

	static const punishments[] =
	{
		(1<<0),	// a = kick,
		(1<<1),	// b = ban,
		(1<<2),	// c = remove karma,
		(1<<3),	// d = hp to 1,
		(1<<4),	// e = blind,
		(1<<5)	// f = bad aim
	};

	new flags = read_flags(cvar);
	static const size = sizeof(punishments);
	for(new i = 0; i < size; i++)
	{
		if(flags & punishments[i])
			pick_punishment(id, i);
	}
}

stock pick_punishment(killer, punishment)
{
	switch(punishment)
	{
		case 0:	server_cmd("kick #%d ^"You have been kicked from server for killing teammates!^"", get_user_userid(killer));
		case 1:
		{
			static reason[20];
			if(g_iWarnings[killer][0] >= get_pcvar_num(cvar_ar_warnings_special))
				formatex(reason, charsmax(reason), "SPECIAL %d/%d", g_iWarnings[killer][0], g_iWarnings[killer][0]);
			else if(g_iWarnings[killer][1] >= get_pcvar_num(cvar_ar_warnings_innocent))
				formatex(reason, charsmax(reason), "INNOCENT %d/%d", g_iWarnings[killer][1], g_iWarnings[killer][1]);
			else if(g_iWarnings[killer][2] >= get_pcvar_num(cvar_ar_warnings_continued))
				formatex(reason, charsmax(reason), "CONTINUED %d/%d", g_iWarnings[killer][2], g_iWarnings[killer][2]);

			server_cmd("amx_banip %d #%d TK:%s", get_pcvar_num(cvar_ar_warnings_bantime), get_user_userid(killer), reason);
			g_iUserBanned[killer] = true;
		}
		case 2: g_iUserPunish[killer] = true;
		case 3: if(is_user_alive(killer)) set_user_health(killer, 1);
		case 4: set_user_blind(killer);
		case 5: set_user_badaim(killer);
	}
}

stock set_user_badaim(id)
{
	if(task_exists(id))
		remove_task(id);

	g_iBadAim[id] = 0;
	client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_PUNISHMENT3");
	set_task(10.0, "randomize_hitzones", id, _, _, "b");
	randomize_hitzones(id);
}

public randomize_hitzones(id)
{
	if(is_user_alive(id))
	{
		for(new partIdx; partIdx < 3; partIdx++)
			g_iBadAim[id] |= (1 << 0) | (1 << random_num(1, 7));
	}
	else if(task_exists(id))
		remove_task(id);
}

stock set_user_blind(id)
{
	if(is_user_alive(id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_pMsg_ScreeFade, _, id);
		write_short(get_pcvar_num(cvar_ar_warnings_blind_time) * 1<<12);
		write_short(4*1<<12);
		write_short(0x0000);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(255);
		message_end();
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_PUNISHMENT2");
	}
}

stock reset_client(id)
{
	g_iWarnings[id][0] = false;
	g_iWarnings[id][1] = false;
	g_iWarnings[id][2] = false;
	g_iUserPunish[id] = false;
	g_iUserBanned[id] = false;
	g_iBadAim[id] = false;
	if(task_exists(id))
		remove_task(id);
}

stock table_clear()
{
	static temp[32];
	formatex(temp, charsmax(temp), "TRUNCATE TABLE ttt_antiretry");
	SQL_ThreadQuery(g_pSqlTuple, "IgnoreHandle", temp);
}

stock table_insert(id)
{
	static temp[192];
	formatex(temp, charsmax(temp), "INSERT INTO ttt_antiretry (ip, karma, warnings_s, warnings_i, punish) VALUES ('%s', '%d', '%d', '%d', '%d');", g_szUserIP[id], ttt_get_playerdata(id, PD_KARMATEMP), g_iWarnings[id][0], g_iWarnings[id][1], g_iUserPunish[id]);
	SQL_ThreadQuery(g_pSqlTuple, "IgnoreHandle", temp);
}

stock escape_mysql(string[], len)
{
	replace_all(string, len, "\\", "\\\\");
	replace_all(string, len, "\0", "\\0");
	replace_all(string, len, "\n", "\\n");
	replace_all(string, len, "\r", "\\r");
	replace_all(string, len, "\x1a", "\Z");
	replace_all(string, len, "'", "\'");
	replace_all(string, len, "^"", "\^"");
}