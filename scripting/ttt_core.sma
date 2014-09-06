#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <cs_teams_api>
#include <timer_controller>
#include <ttt>

#define TASK_SURVIVAL 1111
#define TASK_ORPHEU 2222
#define m_bitsDamageType 76
#define OFFSET_LINUX_WEAPONS 4 
new const m_rgpPlayerItems_CWeaponBox[6] = {34, 35, ...};

new const g_szGameModes[Game][] =
{
	"unset",
	"off",
	"preparing",
	"restarting",
	"started",
	"ended"
};

const DMG_SOMETHING = DMG_GENERIC | DMG_SLASH | DMG_BURN 
	| DMG_FREEZE | DMG_FALL | DMG_BLAST | DMG_SHOCK | DMG_DROWN 
	| DMG_NERVEGAS | DMG_POISON | DMG_RADIATION | DMG_ACID;
	
// RESETABLE
new g_iGame, g_iSpecialCount[Special], g_iRoundSpecial[Special];
new g_iStoredInfo[33][PlayerData];
new g_iMultiCount = 1, g_iMultiSeconds = 1;
new Trie:g_tCvarsToFile;
//
// NON RESETABLE
new cvar_traitors, cvar_detectives, cvar_karma_damage,
	cvar_preparation_time, cvar_karma_multi, cvar_karma_start,
	cvar_credits_tra_start, cvar_credits_tra_count, cvar_credits_tra_detkill, cvar_credits_tra_countkill,
	cvar_credits_det_start, cvar_credits_tra_repeat, cvar_damage_modifier,
	cvar_credits_det_bonussurv, cvar_credits_det_survtime, cvar_show_deathmessage;
new g_Msg_TeamInfo, g_iGameModeForward;
new Float:g_fFreezeTime, Float:g_fRoundTime, Float:g_fRoundStart;
new g_iMaxDetectives, g_iMaxTraitors, g_iMaxPlayers;
//

public plugin_init()
{
	register_plugin("[TTT] Core", TTT_VERSION, TTT_AUTHOR);
	register_cvar("ttt_server_version", TTT_VERSION, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

	cvar_traitors					= mynew_register_cvar("ttt_traitors",					"4");
	cvar_detectives					= mynew_register_cvar("ttt_detectives",					"8");
	cvar_preparation_time			= mynew_register_cvar("ttt_preparation_time",			"10");
	cvar_credits_tra_start			= mynew_register_cvar("ttt_credits_tra_start",			"2");
	cvar_credits_tra_count			= mynew_register_cvar("ttt_credits_tra_count",			"0.25");
	cvar_credits_tra_repeat			= mynew_register_cvar("ttt_credits_tra_repeat",			"1");
	cvar_credits_tra_detkill		= mynew_register_cvar("ttt_credits_tra_detkill",		"1");
	cvar_credits_tra_countkill		= mynew_register_cvar("ttt_credits_tra_countkill",		"1");
	cvar_credits_det_start			= mynew_register_cvar("ttt_credits_det_start",			"1");
	cvar_credits_det_bonussurv		= mynew_register_cvar("ttt_credits_det_bonussurv",		"1");
	cvar_credits_det_survtime		= mynew_register_cvar("ttt_credits_det_survtime",		"45.0");
	cvar_karma_damage				= mynew_register_cvar("ttt_karma_damage",				"0.25");
	cvar_karma_multi				= mynew_register_cvar("ttt_karma_multi",				"50");
	cvar_karma_start				= mynew_register_cvar("ttt_karma_start",				"500");
	cvar_show_deathmessage			= mynew_register_cvar("ttt_show_deathmessage",			"abeg");
	cvar_damage_modifier			= mynew_register_cvar("ttt_damage_modifier",			"1.0");

	g_Msg_TeamInfo		=	get_user_msgid("TeamInfo");

	register_event("TextMsg", "Event_RoundRestart", "a", "2&#Game_C", "2&#Game_w");
	register_event("HLTV", "Event_HLTV", "a", "1=0", "2=0");
	register_event("DeathMsg", "Event_DeathMsg", "a");
	register_logevent("Event_EndPreptime", 2, "1=Round_Start");
	register_logevent("Event_EndRound", 2, "1=Round_End");

	register_forward(FM_AddToFullPack, "Forward_AddToFullPack_post", 1);

	RegisterHam(Ham_Killed, "player", "Ham_Killed_pre", 0, true);
	RegisterHam(Ham_Killed, "player", "Ham_Killed_post", 1, true);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0, true);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_post", 1, true);

	g_iGameModeForward = CreateMultiForward("ttt_gamemode", ET_IGNORE, FP_CELL);

	g_iMaxPlayers = get_maxplayers();
	register_dictionary("ttt.txt");
}

public plugin_end()
	set_game_state(PREPARING);

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_get_special_state", "_get_special_state");
	register_native("ttt_set_special_state", "_set_special_state");
	register_native("ttt_get_special_count", "_get_special_count");
	register_native("ttt_set_special_count", "_set_special_count");
	register_native("get_roundtime", "_get_roundtime");
	register_native("ttt_get_playerdata", "_get_playerdata");
	register_native("ttt_set_playerdata", "_set_playerdata");
	register_native("ttt_set_karma_modifier", "_set_karma_modifier");
	register_native("ttt_get_game_state", "_get_game_state");
	register_native("ttt_set_game_state", "_set_game_state");
	register_native("ttt_get_special_alive", "_get_special_alive");
	register_native("ttt_register_cvar", "_register_cvar");
}

public plugin_cfg()
{
	auto_exec_config(TTT_CONFIGFILE);
	g_fRoundTime = get_pcvar_float(get_cvar_pointer("mp_roundtime"));
	TrieDestroy(g_tCvarsToFile);
}

public client_disconnect(id)
{
	set_task(0.5, "reset_client", id);
	set_special_state(id, NONE);
}

public client_putinserver(id)
{
	reset_client(id);
	g_iStoredInfo[id][PD_KILLEDBY] = -1;
	set_task(11.0, "startup_info", id);

	static karma;
	karma = get_pcvar_num(cvar_karma_start);
	g_iStoredInfo[id][PD_KARMATEMP] = karma;
	g_iStoredInfo[id][PD_KARMA] = karma;
}

public startup_info(id)
{
	if(get_game_state() == STARTED && !is_user_alive(id))
	{
		set_special_state(id, DEAD);
		Show_All();
	}

	// Please don't remove this :)
	client_print_color(id, print_team_default, "%s Mod created by ^3%s^1, ^4skype:guskis1^1, version: ^3%s^1!", TTT_TAG, TTT_AUTHOR, TTT_VERSION);
}

public Event_RoundRestart()
{
	if(get_game_state() != RESTARTING)
	{
		reset_all();
		set_game_state(RESTARTING);
	}
}

public Event_HLTV()
{
	if(get_game_state() != PREPARING)
	{
		new cvar = get_pcvar_num(cvar_preparation_time);
		if(!cvar)
			set_pcvar_num(cvar_preparation_time, cvar = 1);
		g_fFreezeTime = float(cvar);
		set_task(0.1, "set_timer");

		g_fRoundTime = get_pcvar_float(get_cvar_pointer("mp_roundtime"));
		g_fRoundStart = get_gametime();
		reset_all();

		set_game_state(PREPARING);
	}
}

public set_timer()
	RoundTimerSet(0, get_pcvar_num(cvar_preparation_time));

public Event_EndRound()
{
	if(get_game_state() != ENDED)
	{
		reset_all();
		set_game_state(ENDED);
	}
}

public Event_EndPreptime()
{
	if(task_exists(TASK_ORPHEU))
		remove_task(TASK_ORPHEU);
	set_task(float(get_pcvar_num(cvar_preparation_time)), "do_the_magic", TASK_ORPHEU);
}

public do_the_magic()
{
	RoundTimerSet(floatround(g_fRoundTime));

	new num;
	static players[32];
	get_players(players, num);
	if(num < 3)
	{
		set_game_state(OFF);
		client_print_color(0, print_team_default, "%s %L", TTT_TAG, LANG_PLAYER, "TTT_MODOFF1");
		return;
	}

	new trai = get_pcvar_num(cvar_traitors), dete = get_pcvar_num(cvar_detectives);
	g_iMaxTraitors = (num/trai);
	if(!g_iMaxTraitors)
		g_iMaxTraitors = 1;

	g_iMaxDetectives = (num/dete);
	if(g_iMaxTraitors+g_iMaxDetectives>num)
	{
		set_pcvar_num(cvar_detectives, 8);
		set_pcvar_num(cvar_traitors, 4);
		g_iMaxTraitors = (num/trai);

		if(!g_iMaxTraitors)
			g_iMaxTraitors = 1;
	
		g_iMaxDetectives = (num/dete);
		client_print_color(0, print_team_default, "%s %L", TTT_TAG, LANG_PLAYER, "TTT_MODOFF2");
	}
	while(specials_needed() != 0)
		pick_specials();

	new id;
	for(--num; num >= 0; num--)
	{
		id = players[num];
		if(!is_user_alive(id)) continue;
		g_iStoredInfo[id][PD_KARMA] = g_iStoredInfo[id][PD_KARMATEMP];

		if(get_special_state(id) != DETECTIVE && get_special_state(id) != TRAITOR)
		{
			set_special_state(id, INNOCENT);
			ttt_set_player_stat(id, STATS_INN, ttt_get_player_stat(id, STATS_INN)+1);
			cs_set_player_team(id, CS_TEAM_CT, false);
		}

		entity_set_float(id, EV_FL_frags, float(g_iStoredInfo[id][PD_KARMA]));
		cs_set_user_deaths(id, g_iStoredInfo[id][PD_KILLEDDEATHS]);
	}

	new i;
	for(i = 0; i < Special; i++)
		g_iRoundSpecial[i] = get_special_count(i);

	set_task(get_pcvar_float(cvar_credits_det_survtime), "give_survival_credits", TASK_SURVIVAL, _, _, "b");
	
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		id = players[num];
		set_fake_team(id, get_special_state(id));
	}

	set_game_state(STARTED);
}

public Event_DeathMsg()
{
	new killer = read_data(1); 
	new victim = read_data(2);
	static weapon[16];
	read_data(4, weapon, charsmax(weapon));

	if(is_user_connected(killer))
	{
		static newweap[32];
		g_iStoredInfo[victim][PD_KILLEDBY] = killer;
		g_iStoredInfo[killer][PD_KILLCOUNT]++;
		formatex(newweap, charsmax(newweap), "weapon_%s", weapon);
		g_iStoredInfo[victim][PD_KILLEDWEAP] = get_weaponid(newweap);
	}
	
	static cvar[10];
	get_pcvar_string(cvar_show_deathmessage, cvar, charsmax(cvar));
	if(cvar[0])
		ttt_make_deathmsg(killer, victim, read_data(3), weapon, read_flags(cvar));

	if(equali(weapon, "worldspawn"))
		g_iStoredInfo[victim][PD_KILLEDWEAP] = DEATHS_SUICIDE;
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
	if(ttt_return_check(victim))
		return HAM_IGNORED;

	if(get_pdata_int(victim, m_bitsDamageType) & DMG_SOMETHING)
		add_death_info(victim, killer, get_pdata_int(victim, m_bitsDamageType, 5));

	g_iStoredInfo[victim][PD_KILLEDSTATE] = get_special_state(victim);
	g_iStoredInfo[victim][PD_KILLEDTIME] = floatround(floatmul(g_fRoundTime, 60.0) - get_round_time());
	g_iStoredInfo[victim][PD_KILLEDDEATHS]++;

	karma_modifier(killer, victim, g_iStoredInfo[victim][PD_KARMATEMP], 1, 0);

	set_special_state(victim, DEAD);
	return HAM_HANDLED;
}

public add_death_info(victim, killer, dmg)
{
	new msg = get_deathmessage(0, dmg);
	if(is_user_connected(killer))
	{
		g_iStoredInfo[victim][PD_KILLEDBY] = killer;
		g_iStoredInfo[killer][PD_KILLCOUNT]++;
	}
	else g_iStoredInfo[victim][PD_KILLEDBY] = msg;

	g_iStoredInfo[victim][PD_KILLEDWEAP] = msg;
}

public get_deathmessage(id, dmg)
{
	if(!id)
	{
		if(dmg & DMG_GENERIC)
			dmg = DEATHS_GENERIC;
		else if(dmg & DMG_SLASH)
			dmg = DEATHS_SLASH;
		else if(dmg & DMG_BURN)
			dmg = DEATHS_BURN;
		else if(dmg & DMG_FREEZE)
			dmg = DEATHS_FREEZE;
		else if(dmg & DMG_FALL)
			dmg = DEATHS_FALL;
		else if(dmg & DMG_BLAST)
			dmg = DEATHS_BLAST;
		else if(dmg & DMG_SHOCK)
			dmg = DEATHS_SHOCK;
		else if(dmg & DMG_DROWN)
			dmg = DEATHS_DROWN;
		else if(dmg & DMG_NERVEGAS)
			dmg = DEATHS_NERVEGAS;
		else if(dmg & DMG_POISON)
			dmg = DEATHS_POISON;
		else if(dmg & DMG_RADIATION)
			dmg = DEATHS_RADIATION;
		else if(dmg & DMG_ACID)
			dmg = DEATHS_ACID;
		else dmg = DEATHS_SUICIDE;
	}
	else dmg = g_iStoredInfo[id][PD_KILLEDWEAP];

	return dmg;
}

public Ham_Killed_post(victim, killer, shouldgib)
{
	if(ttt_return_check(victim))
		return HAM_IGNORED;

	if(!(0 <= killer <= g_iMaxPlayers))
		killer = 0;

	new num, i, bonus;
	static players[32], name[32];
	if(float(get_special_count(DEAD)+get_special_count(TRAITOR)-g_iRoundSpecial[TRAITOR])/float(g_iRoundSpecial[INNOCENT]+g_iRoundSpecial[DETECTIVE])
	> get_pcvar_float(cvar_credits_tra_count) * g_iMultiCount)
	{
		bonus = get_pcvar_num(cvar_credits_tra_countkill);
		get_players(players, num, "a");
		for(--num; num >= 0; num--)
		{
			i = players[num];

			if(get_special_state(i) == TRAITOR)
			{
				g_iStoredInfo[i][PD_CREDITS] += bonus;
				client_print_color(i, print_team_default, "%s %L", TTT_TAG, i, "TTT_AWARD1", bonus, floatround(get_pcvar_float(cvar_credits_tra_count)* g_iMultiCount*100), i, special_names[INNOCENT]);
			}
		}

		if(get_pcvar_num(cvar_credits_tra_repeat))
			g_iMultiCount++;
		else g_iMultiCount = 100;
	}

	new killer_state = get_special_state(killer), victim_state = get_special_alive(victim);
	if(killer_state == TRAITOR)
	{
		if(victim_state == DETECTIVE)
		{
			bonus = get_pcvar_num(cvar_credits_tra_detkill);
			g_iStoredInfo[killer][PD_CREDITS] += bonus;
			get_user_name(victim, name, charsmax(name));
			client_print_color(killer, print_team_default, "%s %L", TTT_TAG, killer, "TTT_AWARD2", bonus, killer, special_names[DETECTIVE], name);
		}
		
		if(victim_state == DETECTIVE || victim_state == INNOCENT)
			ttt_set_player_stat(killer, STATS_KILLS_T, ttt_get_player_stat(killer, STATS_KILLS_T)+1);
	}

	if(victim_state == TRAITOR)
	{
		if(killer_state == INNOCENT)
			ttt_set_player_stat(killer, STATS_KILLS_I, ttt_get_player_stat(killer, STATS_KILLS_I)+1);
		else if(killer_state == DETECTIVE)
			ttt_set_player_stat(killer, STATS_KILLS_D, ttt_get_player_stat(killer, STATS_KILLS_D)+1);
	}

	if(is_user_connected(killer) && killer != victim)
	{
		get_user_name(killer, name, charsmax(name));
		client_print_color(victim, print_team_default, "%s %L", TTT_TAG, victim, "TTT_KILLED1", name, victim, special_names[get_special_alive(killer)]);
	}
	else client_print_color(victim, print_team_default, "%s %L", TTT_TAG, victim, "TTT_SUICIDE");

	if(killer != 0 && killer != victim)
	{
		get_user_name(victim, name, charsmax(name));
		if(killer_state == INNOCENT || killer_state == DETECTIVE)
			client_print_color(killer, print_team_default, "%s %L", TTT_TAG, killer, "TTT_KILLED2", name);
		else if(killer_state == TRAITOR || victim_state == TRAITOR)
			client_print_color(killer, print_team_default, "%s %L", TTT_TAG, killer, "TTT_KILLED3", name, killer, special_names[victim_state]);
	}

	set_task(0.1, "Show_All");
	return HAM_HANDLED;
}

public Show_All()
{
	if(get_game_state() == STARTED)
	{
		new num, i, specstate;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			i = players[num];

			specstate = get_special_state(i);
			if(specstate == DEAD || specstate == NONE)
			{
				set_attrib_special(i, 1, TRAITOR, NONE, DEAD);
				if(!g_iStoredInfo[i][PD_SCOREBOARD])
					set_attrib_special(i, 0, INNOCENT, DETECTIVE);
			}
		}
	}
}

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage, DamageBits)
{
	if(!ttt_return_check(attacker))
	{
		new Float:modifier = g_iStoredInfo[attacker][PD_KARMA]/1000.0;
		if(modifier > 0.05)
		{
			damage *= (modifier*get_pcvar_float(cvar_damage_modifier));
			if(cs_get_user_team(attacker) != cs_get_user_team(victim))
				damage *= 0.35;

			if(damage < 1.0)
				damage = 1.0;

		}
		else damage = 0.0;

		SetHamParamFloat(4, damage);
		return HAM_HANDLED;
	}

	return HAM_IGNORED;
}

public Ham_TakeDamage_post(victim, inflictor, attacker, Float:damage, DamageBits)
{
	if(!ttt_return_check(attacker))
	{
		new dmg = floatround(entity_get_float(victim, EV_FL_dmg_take));
		karma_modifier(attacker, victim, dmg, 0, 0);
		return HAM_HANDLED;
	}

	return HAM_IGNORED;
}

public Forward_AddToFullPack_post(es_handle, e, ent, host, hostflags, id, pSet)
{
    if(id && host != ent && get_orig_retval() && is_user_alive(host) && is_user_alive(ent))
    {
		static entTeam, hostTeam;
		entTeam = get_special_state(ent);
		hostTeam = get_special_state(host);
		if(entTeam != INNOCENT)
		{
			if(hostTeam == TRAITOR)
			{
				set_es(es_handle, ES_RenderFx, kRenderFxGlowShell);
				set_es(es_handle, ES_RenderColor, g_iTeamColors[entTeam]);
				set_es(es_handle, ES_RenderAmt, 35);
			}
			else if(hostTeam == DETECTIVE || hostTeam == INNOCENT)
			{
				if(entTeam != TRAITOR)
				{
					set_es(es_handle, ES_RenderFx, kRenderFxGlowShell);
					set_es(es_handle, ES_RenderColor, g_iTeamColors[entTeam]);
					set_es(es_handle, ES_RenderAmt, 35);
				}
			}
		}
    }
}

public pick_specials()
{
	new id, randomNum, num;
	static players[32];

	get_players(players, num);
	while(id == 0)
	{
		id = players[random(num)];
		if(get_special_state(id) == TRAITOR || get_special_state(id) == DETECTIVE)
			id = 0;
	}

	static msg[96], name[32];
	randomNum = specials_needed();
	get_user_name(id, name, charsmax(name));
	switch(randomNum)
	{
		case TRAITOR:
		{
			g_iStoredInfo[id][PD_CREDITS] = get_pcvar_num(cvar_credits_tra_start);
			set_special_state(id, randomNum);
			ttt_set_player_stat(id, STATS_TRA, ttt_get_player_stat(id, STATS_TRA)+1);

			formatex(msg, charsmax(msg), "[%L] %s choosen (ID:%d)", id, special_names[randomNum], name, id);
			ttt_log_to_file(LOG_DEFAULT, msg);
			cs_set_player_team(id, CS_TEAM_T, false);
		}
		case DETECTIVE:
		{
			if(num >= get_pcvar_num(cvar_detectives))
			{
				g_iStoredInfo[id][PD_CREDITS] = get_pcvar_num(cvar_credits_det_start);
				set_special_state(id, randomNum);
				ttt_set_player_stat(id, STATS_DET, ttt_get_player_stat(id, STATS_DET)+1);

				formatex(msg, charsmax(msg), "[%L] %s choosen (ID:%d)", id, special_names[randomNum], name, id);
				ttt_log_to_file(LOG_DEFAULT, msg);
				cs_set_player_team(id, CS_TEAM_CT, false);
			}
		}
		case NONE: return;
	}
}

public specials_needed()
{
	if(g_iMaxTraitors > get_special_count(TRAITOR))
		return TRAITOR;
	else if(g_iMaxDetectives > get_special_count(DETECTIVE))
		return DETECTIVE;

	return NONE;
}

public give_survival_credits()
{
	static players[32];
	new num, id, bonus = get_pcvar_num(cvar_credits_det_bonussurv);
	get_players(players, num, "a");
	for(--num; num >= 0; num--)
	{
		id = players[num];
		if(get_special_state(id) == DETECTIVE)
		{
			g_iStoredInfo[id][PD_CREDITS] += bonus;
			client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_AWARD4", bonus, floatround(get_pcvar_float(cvar_credits_det_survtime))*g_iMultiSeconds);
			g_iMultiSeconds++;
		}
	}
}

public reset_all()
{
	static players[32];
	new num, id, i;
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		id = players[num];

		set_special_state(id, NONE);
		for(i = 0; i < PlayerData; i++)
		{
			if(i == PD_KARMA || i == PD_KARMATEMP || i == PD_KILLEDDEATHS) continue;
			if(i == PD_KILLEDBY || i == PD_KILLEDBYITEM)
				g_iStoredInfo[id][i] = -1;
			else g_iStoredInfo[id][i] = 0;
		}
		if(task_exists(id))
			remove_task(id);
		set_attrib_all(id, 0);
	}

	//if(get_game_state() == ENDED || get_game_state() == RESTARTING)
	//	set_game_state(OFF);

	g_iMultiSeconds = 1;
	g_iMultiCount = 1;

	if(task_exists(TASK_SURVIVAL))
		remove_task(TASK_SURVIVAL);
}

public reset_client(id)
{
	for(new i = 0; i < PlayerData; i++)
	{
		if(i == PD_KILLEDBY || i == PD_KILLEDBYITEM)
			g_iStoredInfo[id][i] = -1;
		else g_iStoredInfo[id][i] = 0;
	}

	set_special_state(id, NONE);
	set_attrib_all(id, 0);
}

public karma_modifier(attacker, victim, modifier, type, when)
{
	if (attacker == 0)
		attacker = victim;

	if(!is_user_connected(attacker) || !is_user_connected(victim) || get_game_state() == OFF)
		return;

	static players[32];
	new num, karmamulti, two, ivictim, iattacker;
	get_players(players, num);
	if(type == 1)
	{
		karmamulti = floatround(get_pcvar_num(cvar_karma_multi)*(modifier/1000.0));
		two = (3*(g_iMaxPlayers-1)-(num-1))/(g_iMaxPlayers-1);
	}
	else if(type == 0)
	{
		karmamulti = modifier*0.25 < 1 ? 1 : floatround(modifier*get_pcvar_float(cvar_karma_damage));
		two = 1;
	}

	ivictim = !when ? get_special_state(victim) : g_iStoredInfo[victim][PD_KILLEDSTATE];
	iattacker = is_user_alive(attacker) ? get_special_state(attacker) : g_iStoredInfo[attacker][PD_KILLEDSTATE];

	if(attacker == victim && type != 2)
		g_iStoredInfo[attacker][PD_KARMASELF] = karmamulti*two;

	if(type == 2)
		g_iStoredInfo[attacker][PD_KARMATEMP] += modifier;
	else
	{
		switch(iattacker)
		{
			case TRAITOR: //attacker is traitor
			{
				switch(ivictim)
				{
					case TRAITOR:					g_iStoredInfo[attacker][PD_KARMATEMP] -= karmamulti*two;
					case DETECTIVE, INNOCENT:		g_iStoredInfo[attacker][PD_KARMATEMP] += karmamulti/two;
				}
			}
			case DETECTIVE, INNOCENT: //attacker is detective or innocent
			{
				switch(ivictim)
				{
					case TRAITOR:					g_iStoredInfo[attacker][PD_KARMATEMP] += karmamulti/two;
					case DETECTIVE, INNOCENT:		g_iStoredInfo[attacker][PD_KARMATEMP] -= karmamulti*two;
				}
			}
		}
	}

	karma_reset(attacker);
}

public karma_reset(id)
{
	if(g_iStoredInfo[id][PD_KARMATEMP] > 1000)
		g_iStoredInfo[id][PD_KARMATEMP] = 1000;
	else if(g_iStoredInfo[id][PD_KARMATEMP] < 1)
		g_iStoredInfo[id][PD_KARMATEMP] = 1;
}

public set_game_state(which)
{
	if(g_iGame && g_iGame < ENDED && which == RESTARTING)
		log_amx("[TTT] Game has restarted :( (game: %d)", g_iGame);

	g_iGame = which;
	static msg[32];
	formatex(msg, charsmax(msg), "Gamemode set to %s", g_szGameModes[which]);
	ttt_log_to_file(LOG_GAMETYPE, msg);

	new ret;
	ExecuteForward(g_iGameModeForward, ret, which);
}

public get_game_state()
	return g_iGame;

public get_special_state(id)
	return g_iStoredInfo[id][PD_PLAYERSTATE];

public get_special_count(msg)
	return g_iSpecialCount[msg];

public get_special_alive(id)
{
	if(!is_user_alive(id))
		return g_iStoredInfo[id][PD_KILLEDSTATE];
	else return get_special_state(id);

	return -1;
}

public set_special_state(id, msg)
{
	if(!is_user_connected(id) || get_special_state(id) == msg)
		return;

	if(get_special_state(id))
		set_special_count(get_special_state(id), -1);

	g_iStoredInfo[id][PD_PLAYERSTATE] = msg;
	set_special_count(msg, 1);
}

public set_special_count(msg, num)
{
	if(num == -1)
		g_iSpecialCount[msg]--;
	else if(num == 1)
		g_iSpecialCount[msg]++;
	else g_iSpecialCount[msg] = 0;
}

public set_fake_team(id, getstate)
{
	new num, i, specstate;
	static players[32];
	get_players(players, num);

	for(--num; num >= 0; num--)
	{
		i = players[num];
		specstate = get_special_state(i);
		switch(getstate)
		{
			case INNOCENT, DETECTIVE:
			{
				if(specstate == DETECTIVE)
					set_fake_message(id, i, "CT");
				else set_fake_message(id, i, "TERRORIST");
			}
			case TRAITOR:
			{
				if(specstate == TRAITOR || specstate == DETECTIVE)
				{
					set_fake_message(id, i, "CT");
					if(specstate == DETECTIVE)
						set_attrib_special(i, 4, TRAITOR, NONE, DEAD);
				}
				else set_fake_message(id, i, "TERRORIST");
			}
		}
	}
}

public set_fake_message(id, i, msg[])
{
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_TeamInfo, _, id);
	write_byte(i);
	write_string(msg);
	message_end();
}

public Float:get_round_time()
	return get_gametime() - g_fRoundStart - g_fFreezeTime;

stock weapon_in_box(ent)
{
    new weapon;
    for(new i = 1; i < 6; i++)
    {
        weapon = get_pdata_cbase(ent, m_rgpPlayerItems_CWeaponBox[i], OFFSET_LINUX_WEAPONS);
        if(weapon > 0)
            return cs_get_weapon_id(weapon);
    }

    return 0;
}  

stock mynew_register_cvar(name[], string[], flags = 0, Float:fvalue = 0.0)
{
	new_register_cvar(name, string);
	return register_cvar(name, string, flags, fvalue);
}

stock new_register_cvar(name[], string[], plug[] = "ttt_core.amxx")
{
	static path[96];
	if(!path[0])
	{
		get_localinfo("amxx_configsdir", path, charsmax(path));
		format(path, charsmax(path), "%s/%s", path, TTT_CONFIGFILE);
	}

	new file;
	if(!g_tCvarsToFile)
		g_tCvarsToFile = TrieCreate();

	if(!file_exists(path))
	{
		file = fopen(path, "wt");
		if(!file)
			return 0;
	}
	else
	{
		file = fopen(path, "rt");
		if(!file)
			return 0;

		if(!TrieGetSize(g_tCvarsToFile))
		{
			new newline[48];
			static line[128];
			while(!feof(file))
			{
				fgets(file, line, charsmax(line));
				if(line[0] == ';' || !line[0])
					continue;

				parse(line, newline, charsmax(newline));
				remove_quotes(newline);
				TrieSetCell(g_tCvarsToFile, newline, 1, false);
			}
		}
		fclose(file);
		file = fopen(path, "at");
	}

	if(!TrieKeyExists(g_tCvarsToFile, name))
	{
		fprintf(file, "%-32s %-8s // ^"%s^"^n", name, string, plug);
		TrieSetCell(g_tCvarsToFile, name, 1, false);
	}

	fclose(file);
	return 1;
}

// API
public _get_special_state(plugin, params)
{
	if(params != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_special_state)") -1;

	new id = get_param(1);
	return get_special_state(id);
}

public _get_special_count(plugin, params)
{
	if(params != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_special_count)") -1;

	new msg = get_param(1);
	return get_special_count(msg);
}

public _set_special_state(plugin, params)
{
	if(params != 2)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_set_special_state)");

	new id = get_param(1);
	new msg = get_param(2);
	set_special_state(id, msg);

	return 1;
}

public _set_special_count(plugin, params)
{
	if(params != 2)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_set_special_count)");

	new msg = get_param(1);
	new num = get_param(2);
	set_special_count(msg, num);

	return 1;
}

public Float:_get_roundtime()
	return get_round_time();

public _get_playerdata(plugin, params)
{
	if(params != 2)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_playerdata)") -1;

	new id = get_param(1);
	new datatype = get_param(2);

	return g_iStoredInfo[id][datatype];
}

public _set_playerdata(plugin, params)
{
	if(params != 3)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_set_playerdata)");

	new id = get_param(1);
	new datatype = get_param(2);
	new newdata = get_param(3);

	g_iStoredInfo[id][datatype] = newdata;
	if(datatype == PD_KARMATEMP)
		karma_reset(id);

	return 1;
}

public _set_karma_modifier(plugin, params)
{
	if(params != 5)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_set_karma_modifier)");

	new killer = get_param(1);
	new victim = get_param(2);
	new modifier = get_param(3);
	new type = get_param(4);
	new when = get_param(5);

	karma_modifier(killer, victim, modifier, type, when);
	return 1;
}

public _set_game_state(plugin, params)
{
	if(params != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_set_game_state)");

	new which = get_param(1);
	set_game_state(which);
	return 1;
}

public _get_game_state(plugin, params)
	return get_game_state();

public _get_special_alive(plugin, params)
{
	if(params != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_special_alive)");

	new id = get_param(1);
	return get_special_alive(id);
}

public _register_cvar(plugin, params)
{
	if(params != 2)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_register_cvar)");

	static name[48], string[16], pluginname[48];
	get_string(1, name, charsmax(name));
	get_string(2, string, charsmax(string));
	get_plugin(plugin, pluginname, charsmax(pluginname));

	return new_register_cvar(name, string, pluginname);
}
