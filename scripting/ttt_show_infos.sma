#include <amxmodx>
#include <hamsandwich>
#include <cstrike>
#include <ttt>

new g_iCached[2], g_iKilledWho[33][33];
new const g_szIconNames[][] = 
{
	"suicide", "p228", "", "scout", "hegrenade", "xm1014", "c4", "mac10", "aug", "hegrenade", "elite", "fiveseven",
	"ump45", "sg550", "galil", "famas", "usp", "glock18", "awp", "mp5navy", "m249", "m3", "m4a1", "tmp", "g3sg1", "hegrenade",
	"deagle", "sg552", "ak47", "crowbar", "p90", "0", "1", "2", "3"
};

new const g_szColors[][] = 
{
	"#848284", // grey
	"#fc0204", // red
	"#0402fc", // blue
	"#048204", // green
	"#F57011", // orange
	"#E211F5"  // purple
};

public plugin_precache()
{
	static icon[32];
	for(new i = 0; i <= charsmax(g_szIconNames); i++)
	{
		if(i < 5 && strlen(g_szIconNames[i]) < 3) continue;
		formatex(icon, charsmax(icon), "gfx/ttt/%s.gif", g_szIconNames[i]);
		precache_generic(icon);
	}
}

public plugin_init()
{
	register_plugin("[TTT] Show infos", TTT_VERSION, TTT_AUTHOR);

	register_clcmd("say /tttme", "ttt_show_me");
	register_clcmd("say_team /tttme", "ttt_show_me");

	RegisterHam(Ham_Killed, "player", "Ham_Killed_pre", 0, true);
}

public ttt_gamemode(gamemode)
{
	if(gamemode == PREPARING || gamemode == RESTARTING)
	{
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			reset_player(id);
		}
	}
}

stock reset_player(id)
{
	new num, player;
	static players[32];
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		player = players[num];
		g_iKilledWho[id][player] = false;
	}
}

public ttt_winner(team)
{
	g_iCached[0] = false;
	new num, id;
	static players[32];
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		id = players[num];
		client_cmd(id, "-attack");
		client_cmd(id, "-attack2");
		show_motd_winner(id);
	}
}

public ttt_showinfo(id, target)
{
	new mode = ttt_get_game_state(); 
	if(!is_user_alive(target) && is_user_alive(id) &&  mode != ENDED && mode != OFF)
		show_motd_info(id, target);
}

public ttt_show_me(id)
{
	if(ttt_get_game_state() == OFF)
		return;

	if(!is_user_alive(id))
	{
		const SIZE = 1536;
		static msg[SIZE+1];
		new len;

		len += formatex(msg[len], SIZE - len, "<html><head><meta charset='utf-8'><style>body{background:#ebf3f8 no-repeat center top;}</style></head><body>");
		len += formatex(msg[len], SIZE - len, "</br><center><h2>%L</h2></center>", id, "TTT_WINNER_LINE7");

		new num, player, count;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			player = players[num];
			if(g_iKilledWho[id][player])
			{
				count++;
				len += formatex(msg[len], SIZE - len, "[%L] %n</br>", id, special_names[ttt_get_special_alive(player)], player);
			}
		}

		if(!count) len += formatex(msg[len], SIZE - len, "%L", id, "TTT_WINNER_LINE6");
		len += formatex(msg[len], SIZE - len, "</body></html>");

		show_motd(id, msg, "");
	}
	else client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ALIVE");
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
	if(!is_user_connected(victim) || !is_user_connected(killer) || ttt_get_game_state() == ENDED)
		return HAM_IGNORED;

	g_iKilledWho[killer][victim] = true;
	return HAM_HANDLED;
}

public show_motd_winner(id)
{
	if(!is_user_connected(id) || ttt_get_game_state() == OFF)
		return;

	const SIZE = 1536;
	static wholemsg[SIZE+1], msg[SIZE+1], motdname[64], staticsize;
	new zum, len;
	if(!g_iCached[0])
	{
		new i, highest, num, killedstate;
		new name[32], Traitors[256], Detectives[256], suicide[128], kills[128], c4[70], out[64], players[32];

		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			i = players[num];

			killedstate = ttt_get_special_alive(i);
			get_user_name(i, name, charsmax(name));

			if(ttt_get_special_state(i) == TRAITOR || killedstate == TRAITOR)
				format(Traitors, charsmax(Traitors), "%s, %s", name, Traitors);

			if(ttt_get_special_state(i) == DETECTIVE || killedstate == DETECTIVE)
				format(Detectives, charsmax(Detectives), "%s, %s", name, Detectives);

			if(ttt_get_playerdata(i, PD_KILLEDBY) == 3005)
				format(suicide, charsmax(suicide), "%s, %s", name, suicide);

			if(ttt_get_playerdata(i, PD_C4EXPLODED))
				format(c4, charsmax(c4), "%s, %s", name, c4);

			if(ttt_get_playerdata(i, PD_KILLCOUNT) > highest)
			{
				if(ttt_get_special_state(i) != DEAD)
					zum = ttt_get_special_state(i);
				else zum = killedstate;

				highest = ttt_get_playerdata(i, PD_KILLCOUNT);
				formatex(kills, charsmax(kills), "%L", LANG_SERVER, "TTT_WINNER_LINE4", g_szColors[zum], LANG_SERVER, special_names[zum], name, highest);
			}
		}

		if(strlen(Traitors) > 2)
			Traitors[strlen(Traitors)-2] = '^0';

		if(strlen(Detectives) > 2)
			Detectives[strlen(Detectives)-2] = '^0';

		if(strlen(suicide) > 2)
			suicide[strlen(suicide)-2] = '^0';

		if(strlen(c4) > 2)
			c4[strlen(c4)-2] = '^0';

		new winner = ttt_get_winner();
		if(winner == DETECTIVE)
			winner++;

		if(winner == TRAITOR)
			formatex(out, charsmax(out), "%L", LANG_SERVER, "TTT_TWIN");
		else if(winner == INNOCENT)
			formatex(out, charsmax(out), "%L", LANG_SERVER, "TTT_IWIN");

		len += formatex(msg[len], SIZE - len, "<html><head><meta charset='utf-8'><style>body{background:#ebf3f8 url('gfx/ttt/%d.gif') no-repeat center top;}</style></head><body>", winner);
		len += formatex(msg[len], SIZE - len, "</br><center><h1>%s</h1></center>", out);

		if(strlen(Detectives) > 0)
			len += formatex(msg[len], SIZE - len, "<b style='color:%s'>%L: %s</b><br/>", g_szColors[DETECTIVE], LANG_SERVER, special_names[DETECTIVE], Detectives);
		len += formatex(msg[len], SIZE - len, "<b style='color:%s'>%L: %s</b><br/><br/>", g_szColors[TRAITOR], LANG_SERVER, special_names[TRAITOR], Traitors);

		if(strlen(kills) > 0)
			len += formatex(msg[len], SIZE - len, "%s<br/>", kills);

		if(strlen(suicide) > 0)
			len += formatex(msg[len], SIZE - len, "<b style='color:%s'>%L<br/>", g_szColors[SPECIAL], LANG_SERVER, "TTT_WINNER_LINE2", suicide);

		if(strlen(c4) > 0)
			len += formatex(msg[len], SIZE - len, "<b style='color:%s'>%L<br/>", g_szColors[SPECIAL], LANG_SERVER, "TTT_WINNER_LINE3", c4);

		formatex(motdname, charsmax(motdname), "%L", LANG_SERVER, "TTT_WINNER_LINE1");
		g_iCached[0] = true;
		staticsize = len;
	}
	len = staticsize;
	formatex(wholemsg, charsmax(msg), "%s", msg);

	len += formatex(wholemsg[len], SIZE - len, "%L</br>", LANG_SERVER, "TTT_WINNER_LINE7");
	new num, player, count;
	static players[32];
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		player = players[num];
		if(g_iKilledWho[id][player])
		{
			count++;
			len += formatex(wholemsg[len], SIZE - len, "%L [%L] %n</br>", LANG_SERVER, "TTT_WINNER_LINE7", LANG_SERVER, special_names[ttt_get_special_alive(player)], player);
		}
	}

	if(!count) formatex(wholemsg[len], SIZE - len, "%L", id, "TTT_WINNER_LINE6");
	
	new karma = ttt_get_playerdata(id, PD_KARMA), karmatemp = ttt_get_playerdata(id, PD_KARMATEMP);
	zum = ttt_get_special_alive(id);
	len += formatex(wholemsg[len], SIZE - len, "%L<br/>", LANG_SERVER, "TTT_WINNER_LINE5", g_szColors[zum], karma, g_szColors[zum], karmatemp-karma, g_szColors[zum], karmatemp);
	len += formatex(wholemsg[len], SIZE - len, "</body></html>");

	show_motd(id, wholemsg, motdname);
	wholemsg[0] = '^0';
}

public show_motd_info(id, target)
{
	static name[32], killmsg[64];
	get_user_name(target, name, charsmax(name));
	new minutes = (ttt_get_playerdata(target, PD_KILLEDTIME) / 60) % 60;
	new seconds = ttt_get_playerdata(target, PD_KILLEDTIME) % 60;
	ttt_get_kill_message(target, ttt_get_playerdata(target, PD_KILLEDBY), killmsg, charsmax(killmsg), 0);

	const SIZE = 1536;
	static msg[SIZE+1], motdname[64];
	new len, killedstate = ttt_get_special_alive(target);
	if(killedstate > 3)
		killedstate = 0;

	len += formatex(msg[len], SIZE - len, "<html><head><meta charset='utf-8'><style>body{background:#ebf3f8 url('gfx/ttt/%d.gif') no-repeat center top;}</style></head><body>", killedstate);
	len += formatex(msg[len], SIZE - len, "</br><center><h1>%L %s</h1>", id, special_names[killedstate], name);
	len += formatex(msg[len], SIZE - len, "<h1>%L</h1>", id, "TTT_INFO_LINE3", g_szColors[killedstate], ttt_get_bodydata(target, BODY_TIME));
	len += formatex(msg[len], SIZE - len, "%L <img src='gfx/ttt/%s.gif'></center>", id, "TTT_INFO_LINE2", g_szColors[killedstate], minutes, seconds, killmsg);
	len += formatex(msg[len], SIZE - len, "</body></html>");
	formatex(motdname, charsmax(motdname), "%L", id, "TTT_INFO_LINE1");

	show_motd(id, msg, motdname);
}
