#include <amxmodx>
#include <sqlx>
#include <ttt>

new const g_iPointValue[Stats-1] =
{
	100,      // Game winning kills
	150,      // Kills as Innocent // Right ones
	100,      // Kills as Detective
	100,      // Kills as Traitor
	-100,     // Team kills
	10,       // Times innocent
	10,       // Times detective
	10,       // Times traitor
	50,       // Bomb planted
	50,       // Bomb exploded
	50        // Bomb defused
};            

new g_iPlayerStats[33][Stats], g_szPlayerName[33][32], cvar_stats, pluginon;
new Handle:g_pSqlTuple, Trie:g_tTop10Players[10];

public plugin_init()
{
	register_plugin("[TTT] Stats System", TTT_VERSION, TTT_AUTHOR);

	cvar_stats = my_register_cvar("ttt_stats", "0");
	pluginon = get_pcvar_num(cvar_stats);
	register_clcmd("say /ttttop", "show_top10");
	register_clcmd("say_team /ttttop", "show_top10");
	register_clcmd("say /tttstats", "show_stats");
	register_clcmd("say_team /tttstats", "show_stats");
}

public plugin_cfg()
	set_task(1.0, "check_plugin");

public check_plugin()
{
	pluginon = get_pcvar_num(cvar_stats);
	if(pluginon)
	{
		MySQL_Init();
		for(new i = 0; i < 10; i++)
			g_tTop10Players[i] = TrieCreate();
		MySQL_TOP10();
	}
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_set_player_stat", "_set_player_stat");
	register_native("ttt_get_player_stat", "_get_player_stat");
}

public plugin_end()
{
	if(pluginon)
		SQL_FreeHandle(g_pSqlTuple);
}

public client_putinserver(id)
{
	if(pluginon)
	{
		reset_client(id);
		get_user_name(id, g_szPlayerName[id], charsmax(g_szPlayerName[]));
		escape_mysql(g_szPlayerName[id], charsmax(g_szPlayerName[]));
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

public client_infochanged(id)
{
	if(!is_user_connected(id) || !pluginon)
		return PLUGIN_CONTINUE;

	static newname[32], oldname[32];
	get_user_name(id, oldname, charsmax(oldname));
	get_user_info(id, "name", newname, charsmax(newname));

	if(!equali(newname, oldname))
	{
		reset_client(id);
		get_user_info(id, "name", g_szPlayerName[id], charsmax(g_szPlayerName[]));
		escape_mysql(g_szPlayerName[id], charsmax(g_szPlayerName[]));
		MySQL_Load(id);
	}

	return PLUGIN_CONTINUE;
}

public MySQL_Init()
{
	static host[64], user[33], pass[32], db[32];
	get_cvar_string("amx_sql_host", host, charsmax(host));
	get_cvar_string("amx_sql_user", user, charsmax(user));
	get_cvar_string("amx_sql_pass", pass, charsmax(pass));
	get_cvar_string("amx_sql_db", db, charsmax(db));

	g_pSqlTuple = SQL_MakeDbTuple(host, user, pass, db);

	static error[256];
	new errorCode, Handle:SqlConnection = SQL_Connect(g_pSqlTuple, errorCode, error, charsmax(error));
	if(SqlConnection == Empty_Handle)
		set_fail_state(error);

	new Handle:queries = SQL_PrepareQuery(SqlConnection, "CREATE TABLE IF NOT EXISTS ttt_stats (id int(8) unsigned NOT NULL auto_increment, player_name varchar(33) UNIQUE NOT NULL default '', gwk int(10), kills_i int(10), kills_d int(10), kills_t int(10), rdm int(10), innocent int(15), detective int(10), traitor int(10), bomb_planted int(10), bomb_exploded int(10), bomb_defused int(10), total_points int(32), PRIMARY KEY (id))");

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
	new data[2];
	data[0] = id;

	static temp[96];
	format(temp, charsmax(temp), "SELECT * FROM ttt_stats WHERE player_name = '%s'", g_szPlayerName[id]);
	SQL_ThreadQuery(g_pSqlTuple, "MySQL_Load_", temp, data, 1);
}

public MySQL_Save(id)
{
	count_points(id);
	static temp[512];
	format(temp, charsmax(temp), "UPDATE ttt_stats SET gwk = '%d', kills_i = '%d', kills_d = '%d', kills_t = '%d', rdm = '%d', innocent = '%d', detective = '%d', traitor = '%d', bomb_planted = '%d', bomb_exploded = '%d', bomb_defused = '%d', total_points = '%d' WHERE player_name = '%s'",
	g_iPlayerStats[id][STATS_GWK], g_iPlayerStats[id][STATS_KILLS_I], g_iPlayerStats[id][STATS_KILLS_D], g_iPlayerStats[id][STATS_KILLS_T], g_iPlayerStats[id][STATS_RDM], g_iPlayerStats[id][STATS_INN], g_iPlayerStats[id][STATS_DET], g_iPlayerStats[id][STATS_TRA], g_iPlayerStats[id][STATS_BOMBP], g_iPlayerStats[id][STATS_BOMBE], g_iPlayerStats[id][STATS_BOMBD], g_iPlayerStats[id][STATS_POINTS], g_szPlayerName[id]);

	SQL_ThreadQuery(g_pSqlTuple, "IgnoreHandle", temp);
}

public MySQL_Load_(failstate, Handle:query, error[], errcode, data[], datasize)
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
		new i;
		for(i = 0; i < Stats; i++)
			g_iPlayerStats[id][i] = SQL_ReadResult(query, i+2);
	}
	else table_insert(id);

	return PLUGIN_HANDLED;
}

public IgnoreHandle(failstate, Handle:query, error[], errcode, data[], datasize)
{
	SQL_FreeHandle(query);
	return PLUGIN_HANDLED;
}

public MySQL_TOP10()
{
	static temp[64];
	format(temp, charsmax(temp), "SELECT * FROM ttt_stats ORDER BY total_points DESC LIMIT 10");
	SQL_ThreadQuery(g_pSqlTuple, "MySQL_TOP10_", temp);
}

public MySQL_TOP10_(failstate, Handle:query, error[], errcode, data[], datasize)
{
	if(failstate == TQUERY_CONNECT_FAILED)
		log_amx("%s Load - Could not connect to SQL database.  [%d] %s", TTT_TAG, errcode, error);
	else if(failstate == TQUERY_QUERY_FAILED)
		log_amx("%s Load query failed. [%d] %s", TTT_TAG, errcode, error);

	if(SQL_NumResults(query) > 0) 
	{
		for(new num[3], j, i = 0; i < 10; i++)
		{
			static name[32];
			SQL_ReadResult(query, 1, name, charsmax(name));
			TrieSetString(g_tTop10Players[i], "1", name, true);
			
			for(j = 2; j < 14; j++)
			{
				num_to_str(j, num, charsmax(num));
				TrieSetCell(g_tTop10Players[i], num, SQL_ReadResult(query, j), true);
			}
			SQL_NextRow(query);
		}
	}

	return PLUGIN_HANDLED;
}

public show_top10(id)
{
	if(!pluginon)
		return;

	const SIZE = 1536;
	static msg[SIZE+1], motdname[64], cached;
	if(!cached)
	{
		new len;
		len += formatex(msg[len], SIZE - len, "<html><head><style>table,td,th { border:1px solid black; border-collapse:collapse; }</style></head><body bgcolor='#ebf3f8'><table style='width:748px'>");
		len += formatex(msg[len], SIZE - len, "<th>Nr.</th><th>Name</th><th>Points</th><th>GWK</th><th>Kills as I</th><th>Kills as D</th><th>Kills as T</th><th>Team kills</th>");
		
		static name[32], value;
		for(new i = 0; i < 10; i++)
		{
			len += formatex(msg[len], SIZE - len, "<tr>");
			len += formatex(msg[len], SIZE - len, "<td>%d.</td>", i+1);

			TrieGetString(g_tTop10Players[i], "1", name, charsmax(name));
			len += formatex(msg[len], SIZE - len, "<td>%s</td>", name);

			TrieGetCell(g_tTop10Players[i], "13", value);
			len += formatex(msg[len], SIZE - len, "<td>%d</td>", value);

			TrieGetCell(g_tTop10Players[i], "2", value);
			len += formatex(msg[len], SIZE - len, "<td>%d</td>", value);
			TrieGetCell(g_tTop10Players[i], "3", value);
			len += formatex(msg[len], SIZE - len, "<td>%d</td>", value);
			TrieGetCell(g_tTop10Players[i], "4", value);
			len += formatex(msg[len], SIZE - len, "<td>%d</td>", value);
			TrieGetCell(g_tTop10Players[i], "5", value);
			len += formatex(msg[len], SIZE - len, "<td>%d</td>", value);
			TrieGetCell(g_tTop10Players[i], "6", value);
			len += formatex(msg[len], SIZE - len, "<td>%d</td>", value);

			len += formatex(msg[len], SIZE - len, "</tr>");
		}
		len += formatex(msg[len], SIZE - len, "</table></body></html>");
		formatex(motdname, charsmax(motdname), "Stats");
		cached = true;
	}
	show_motd(id, msg, motdname);
}

public show_stats(id)
{
	if(!pluginon)
		return;

	if(is_user_alive(id) && ttt_get_game_state() == STARTED)
	{
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ALIVE");
		return;
	}

	count_points(id);
	const SIZE = 1536;
	static msg[SIZE+1], motdname[64];

	new len;
	len += formatex(msg[len], SIZE - len, "<html><head><style>table,td,th { border:1px solid black; border-collapse:collapse; }</style></head><body bgcolor='#ebf3f8'><table style='width:748px'>");
	len += formatex(msg[len], SIZE - len, "<th>Name</th><th>Points</th><th>GWK</th><th>Kills as I</th><th>Kills as D</th><th>Kills as T</th><th>Team kills</th>");

	len += formatex(msg[len], SIZE - len, "<tr><td>%s</td>", g_szPlayerName[id]);
	len += formatex(msg[len], SIZE - len, "<td>%d</td>", g_iPlayerStats[id][STATS_POINTS]);

	len += formatex(msg[len], SIZE - len, "<td>%d</td>", g_iPlayerStats[id][STATS_GWK]);
	len += formatex(msg[len], SIZE - len, "<td>%d</td>", g_iPlayerStats[id][STATS_KILLS_I]);
	len += formatex(msg[len], SIZE - len, "<td>%d</td>", g_iPlayerStats[id][STATS_KILLS_D]);
	len += formatex(msg[len], SIZE - len, "<td>%d</td>", g_iPlayerStats[id][STATS_KILLS_T]);
	len += formatex(msg[len], SIZE - len, "<td>%d</td>", g_iPlayerStats[id][STATS_RDM]);
	len += formatex(msg[len], SIZE - len, "</tr></table></body></html>");
	formatex(motdname, charsmax(motdname), "Stats");

	show_motd(id, msg, motdname);
}

stock reset_client(id)
{
	new i;
	for(i = 0; i < Stats-1; i++)
		g_iPlayerStats[id][i] = 0;
}

stock count_points(id)
{
	new i, points;
	for(i = 0; i < Stats-1; i++)
		points += (g_iPlayerStats[id][i] * g_iPointValue[i]);

	g_iPlayerStats[id][STATS_POINTS] = points;
}

stock table_insert(id)
{
	static temp[512];
	format(temp, charsmax(temp), "INSERT INTO ttt_stats (player_name, gwk, kills_i, kills_d, kills_t, rdm, innocent, detective, traitor, bomb_planted, bomb_exploded, bomb_defused, total_points) VALUES ('%s', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d');",
	g_szPlayerName[id], g_iPlayerStats[id][STATS_GWK], g_iPlayerStats[id][STATS_KILLS_I], g_iPlayerStats[id][STATS_KILLS_D], g_iPlayerStats[id][STATS_KILLS_T], g_iPlayerStats[id][STATS_RDM], g_iPlayerStats[id][STATS_INN], g_iPlayerStats[id][STATS_DET], g_iPlayerStats[id][STATS_TRA], g_iPlayerStats[id][STATS_BOMBP], g_iPlayerStats[id][STATS_BOMBE], g_iPlayerStats[id][STATS_BOMBD], g_iPlayerStats[id][STATS_POINTS]);
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

// API
public _set_player_stat(plugin, params)
{
	if(!pluginon)
		return -1;

	if(params != 3)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_set_player_stat)");

	new stat = get_param(2);
	new id = get_param(1);
	new num = get_param(3);

	g_iPlayerStats[id][stat] = num;

	return 1;
}

public _get_player_stat(plugin, params)
{
	if(!pluginon)
		return -1;

	if(params != 2)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_player_stat)");

	new stat = get_param(2);
	new id = get_param(1);
	return g_iPlayerStats[id][stat];
}