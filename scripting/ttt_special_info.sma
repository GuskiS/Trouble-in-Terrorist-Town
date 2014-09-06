#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <ttt>
#include <amx_settings_api>
#include <xs>

new const g_szDSprite[] = "sprites/ttt/team_d.spr";
new const g_szTSprite[] = "sprites/ttt/team_t.spr";

new cvar_show_health;
new g_iBodyEnts[33], g_iBodyCount, Float:g_fShowTime[33];
new g_iStatusSync, g_iKarmaSync, g_pDetectiveSpr, g_pTraitorSpr, g_iActiveTarget[33];

public plugin_precache()
{
	new sprites[TTT_MAXFILELENGHT];
	if(!amx_load_setting_string(TTT_SETTINGSFILE, "Player Icons", "TRAITOR", sprites, charsmax(sprites)))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Player Icons", "TRAITOR", g_szTSprite);
		g_pTraitorSpr = precache_model(g_szTSprite);
	}
	else g_pTraitorSpr = precache_model(sprites);

	if(!amx_load_setting_string(TTT_SETTINGSFILE, "Player Icons", "DETECTIVE", sprites, charsmax(sprites)))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Player Icons", "DETECTIVE", g_szDSprite);
		g_pDetectiveSpr = precache_model(g_szDSprite);
	}
	else g_pDetectiveSpr = precache_model(sprites);
}

public plugin_init()
{
	register_plugin("[TTT] Special player info", TTT_VERSION, TTT_AUTHOR);
	cvar_show_health = my_register_cvar("ttt_show_health", "1");

	register_event("StatusValue", "Event_StatusValue_S", "be", "1=2", "2!0");
	register_event("StatusValue", "Event_StatusValue_H", "be", "1=1", "2=0");

	g_iStatusSync = CreateHudSyncObj();
	g_iKarmaSync = CreateHudSyncObj();
}

public client_putinserver(id)
{
	set_task(1.0, "show_status", id, _, _, "b");
}

public client_disconnect(id)
{
	if(task_exists(id))
		remove_task(id);
}

public ttt_gamemode(gamemode)
{
	if(gamemode == ENDED)
	{
		for(new i = 0; i < g_iBodyCount; i++)
			g_iBodyEnts[i] = false;
		g_iBodyCount = 0;
	}
}

public ttt_spawnbody(owner, ent)
{
	g_iBodyEnts[g_iBodyCount] = ent;
	g_iBodyCount++;
}

public client_PreThink(id)
{
	if(ttt_return_check(id) || !is_user_alive(id) || g_fShowTime[id] > get_gametime())
		return;
    
	static Float:fOrigin[2][3], origin[3];
	entity_get_vector(id, EV_VEC_origin, fOrigin[0]);
	get_user_origin(id, origin, 3);
	IVecFVec(origin, fOrigin[1]);
	if(get_distance_f(fOrigin[0], fOrigin[1]) > 100.0)
		return;

	new ent, fake;
	for(new i = 0; i < g_iBodyCount; i++)
	{
		fake = g_iBodyEnts[i];
		if(!is_valid_ent(fake) || !is_visible(id, fake))
			continue;

		if(get_dat_deadbody(fake, fOrigin[0], fOrigin[1]))
		{
			ent = fake;
			break;
		}
	}

	if(ent)
	{
		new target = entity_get_int(ent, EV_INT_iuser1);
		if(is_user_alive(target))
			return;
	
		new R, G = 50, B;
		static out[64];
		if(ttt_get_playerdata(target, PD_IDENTIFIED))
		{
			new killedstate = ttt_get_playerdata(target, PD_KILLEDSTATE);
			R = g_iTeamColors[killedstate][0];
			G = g_iTeamColors[killedstate][1];
			B = g_iTeamColors[killedstate][2];
			static name[32];
			get_user_name(target, name, charsmax(name));
			formatex(out, charsmax(out), "[%L] %s", id, special_names[killedstate], name);
		}
		else
		{
			R = 255;
			G = 222;
			if(ttt_get_special_state(id) == TRAITOR)
				formatex(out, charsmax(out), "%L --- [%L]", id, "TTT_UNIDENTIFIED", id, special_names[ttt_get_playerdata(target, PD_KILLEDSTATE)]);
			else formatex(out, charsmax(out), "%L", id, "TTT_UNIDENTIFIED");
		}
    
		g_fShowTime[id] = get_gametime() + 0.95;
		set_hudmessage(R, G, B, -1.0, 0.60, 1, 0.01, 1.0, 0.05, 0.01, -1);
		ShowSyncHudMsg(id, g_iStatusSync, "%s", out);
	}
	else
	{
		new body;
		get_user_aiming(id, ent, body);
		if(is_valid_ent(ent))
		{
			static classname[32];
			entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));
		
			if(equal(classname, TTT_DEATHSTATION) && ttt_get_special_state(id) == TRAITOR)
			{
				new target = entity_get_int(ent, EV_INT_iuser1);
				if(!is_user_connected(target))
					return;
		
				static name[32];
				get_user_name(target, name, charsmax(name));
				set_hudmessage(g_iTeamColors[TRAITOR][0], g_iTeamColors[TRAITOR][1], g_iTeamColors[TRAITOR][2], -1.0, 0.60, 1, 0.01, 1.0, 0.01, 0.01, -1);
				ShowSyncHudMsg(id, g_iStatusSync, "%s --- [%L]", name, id, "TTT_ITEM_ID8");
				g_fShowTime[id] = get_gametime() + 0.95;
			}
		}
	}
}

public Event_StatusValue_S(id)
{
	if(!is_user_connected(id) || ttt_get_game_state() == ENDED)
		return;

	static name[32];
	new message[128];
	new pid = read_data(2);
	get_user_name(pid, name, charsmax(name));
	new R, G, B;

	new pidState = ttt_get_special_state(pid), idState = ttt_get_special_state(id), useState;
	if(pidState == DETECTIVE)
		useState = DETECTIVE;
	else if(pidState == TRAITOR && idState == TRAITOR)
		useState = TRAITOR;
	else useState = INNOCENT;

	R = g_iTeamColors[useState][0];
	G = g_iTeamColors[useState][1];
	B = g_iTeamColors[useState][2];

	new karma = ttt_get_playerdata(pid, PD_KARMA);
	set_hudmessage(R, G, B, -1.0, 0.60, 1, 0.01, 3.0, 0.01, 0.01, -1);
	remove_special_sprite(id, g_iActiveTarget[id]);

	if(get_pcvar_num(cvar_show_health))
		formatex(message, charsmax(message), "%s -- [Karma = %d] [HP = %d]", name, karma, get_user_health(pid));
	else formatex(message, charsmax(message), "%s -- [Karma = %d]", name, karma);

	if((idState == INNOCENT || idState == DETECTIVE) && pidState != DETECTIVE)
	{
		if(!ttt_get_hide_name(pid))
			ShowSyncHudMsg(id, g_iStatusSync, "%s", message);
	}
	else if(pid != g_iActiveTarget[id])
	{
		if(ttt_get_game_state() == PREPARING || ttt_get_game_state() == OFF)
			ShowSyncHudMsg(id, g_iStatusSync, "%s", message);
		else 
		{
			format(message, charsmax(message), "[%L] %s", id, special_names[pidState], message);
			ShowSyncHudMsg(id, g_iStatusSync, "%s", message);
		}

		if(pidState == DETECTIVE)
			show_special_sprite(id, pid, DETECTIVE);
		else if(pidState == TRAITOR && idState == TRAITOR)
			show_special_sprite(id, pid, TRAITOR);
	}

	g_iActiveTarget[id] = pid;
}

public Event_StatusValue_H(id)
{
	ClearSyncHud(id, g_iStatusSync);
	remove_special_sprite(id, g_iActiveTarget[id]);
}

public show_special_sprite(id, target, which)
{
	if(!is_user_connected(id) || !is_user_connected(target))
		return;

	message_begin(MSG_ONE, SVC_TEMPENTITY, _, id);
	write_byte(TE_PLAYERATTACHMENT);
	write_byte(target);
	write_coord(45);
	if(which == TRAITOR)
		write_short(g_pTraitorSpr);
	else if(which == DETECTIVE)
		write_short(g_pDetectiveSpr);
	write_short(30);
	message_end();
}

public remove_special_sprite(id, target)
{
	if(!is_user_connected(id) || !is_user_connected(target))
		return;

	message_begin(MSG_ONE, SVC_TEMPENTITY, _, id);
	write_byte(TE_KILLPLAYERATTACHMENTS);
	write_byte(target);
	message_end();

	g_iActiveTarget[id] = 0;
}

public show_status(alive)
{
	new dead = alive;
	if(!is_user_alive(dead))
	{
		alive = entity_get_int(dead, EV_INT_iuser2);
		if(!is_user_alive(alive))
			return;
	}

	new R, G, B;
	new aliveState = ttt_get_special_state(alive), deadState = ttt_get_special_state(dead);
	if(deadState == DEAD || deadState == NONE)
	{
		R = g_iTeamColors[deadState][0];
		G = g_iTeamColors[deadState][1];
		B = g_iTeamColors[deadState][2];
	}
	else
	{
		R = g_iTeamColors[aliveState][0];
		G = g_iTeamColors[aliveState][1];
		B = g_iTeamColors[aliveState][2];
	}
	
	set_hudmessage(R, G, B, 0.02, 0.87, 0, 6.0, 1.1, 0.0, 0.0, -1);
	new karma = ttt_get_playerdata(alive, PD_KARMA);

	if(deadState == DEAD || deadState == NONE)
		ShowSyncHudMsg(dead, g_iKarmaSync, "[Karma = %d]", karma);
	else if(aliveState != DETECTIVE && aliveState != TRAITOR)
		ShowSyncHudMsg(alive, g_iKarmaSync, "[Karma = %d] [%L]", karma, alive, special_names[aliveState]);
	else ShowSyncHudMsg(alive, g_iKarmaSync, "[Karma = %d] [%L] [Credits = %d]", karma, alive, special_names[aliveState], ttt_get_playerdata(alive, PD_CREDITS));
}