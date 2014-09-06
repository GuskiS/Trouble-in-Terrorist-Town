#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <ttt>
#include <xs>

enum (+= 1111)
{
	TASK_OBJECTCAPS = 1111,
	TASK_VICTIM
}

new g_iRoundSpecial[Special];
new g_iBodyInfo[33][BodyData];
new g_pShowInfoForward, g_pCreateBodyForward;
new cvar_credits_det_trakill, cvar_credits_det_bonusdead;

public plugin_init()
{
	register_plugin("[TTT] Dead Body", TTT_VERSION, TTT_AUTHOR);

	cvar_credits_det_trakill		= my_register_cvar("ttt_credits_det_trakill",	"1");
	cvar_credits_det_bonusdead		= my_register_cvar("ttt_credits_det_bonusdead",	"1");

	register_event("ClCorpse", "Message_ClCorpse", "a", "10=0");
	register_forward(FM_EmitSound, "Forward_EmitSound_pre", 0);
	RegisterHam(Ham_Killed, "player", "Ham_Killed_pre", 0, true);

	g_pShowInfoForward = CreateMultiForward("ttt_showinfo", ET_IGNORE, FP_CELL, FP_CELL);
	g_pCreateBodyForward = CreateMultiForward("ttt_spawnbody", ET_IGNORE, FP_CELL, FP_CELL);
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_get_bodydata", "_get_bodydata");
	register_native("ttt_set_bodydata", "_set_bodydata");
	register_native("ttt_clear_bodydata", "_clear_bodydata");
}

public client_disconnect(id)
{
	reset_all(id);
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
	if(ttt_return_check(victim))
		return HAM_IGNORED;

	if(is_user_connected(killer))
	{
		new Float:distance = entity_range(killer, victim);
		if(distance > 2399.0)
			distance = 2399.0;
		ttt_set_playerdata(victim, PD_KILLEDDISTANCE, floatround(distance));
		new timer = floatround((2400.0-distance)*(0.05));

		g_iBodyInfo[victim][BODY_TIME] = timer;
		g_iBodyInfo[victim][BODY_KILLER] = killer;
		g_iBodyInfo[victim][BODY_TRACER] = 0;
		g_iBodyInfo[victim][BODY_ACTIVE] = true;
		g_iBodyInfo[victim][BODY_CALLD] = 0;

		set_task(1.0, "reduce_time", TASK_VICTIM+victim, _, _, "b", timer);
	}

	return HAM_HANDLED;
}

public reduce_time(taskid)
{
	new victim = taskid - TASK_VICTIM, killer = g_iBodyInfo[victim][BODY_KILLER];
	if(!is_user_alive(killer) || g_iBodyInfo[victim][BODY_TIME] < 1)
	{
		remove_task(taskid);
		return;
	}

	g_iBodyInfo[victim][BODY_TIME]--;
}

public ttt_gamemode(gamemode)
{
	if(gamemode == ENDED || gamemode == RESTARTING)
		remove_entity_name(TTT_DEADBODY);

	if(gamemode == PREPARING || gamemode == RESTARTING)
	{
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			reset_all(id);
		}
	}

	if(gamemode == STARTED)
		set_task(1.0, "round_specials");
}

public reset_all(id)
{
	for(new i = 0; i < sizeof(g_iBodyInfo[]); i++)
		g_iBodyInfo[id][i] = 0;
}

public round_specials()
{
	for(new i = 0; i <= charsmax(g_iRoundSpecial); i++)
		g_iRoundSpecial[i] = ttt_get_special_count(i);
}

public Message_ClCorpse()
{
	new id = read_data(12);
	if(ttt_return_check(id))
		return;

	static Float:origin[3], model[32];
	read_data(1, model, charsmax(model));
	origin[0] = read_data(2)/128.0;
	origin[1] = read_data(3)/128.0;
	origin[2] = read_data(4)/128.0;
	new seq = read_data(9);

	create_body(id, origin, model, seq);
}

public create_body(id, Float:origin[3], model[], seq)
{
	new ent = create_entity("info_target");
	g_iBodyInfo[id][BODY_ENTID] = ent;
	new ret;
	ExecuteForward(g_pCreateBodyForward, ret, id, ent);
	entity_set_string(ent, EV_SZ_classname, TTT_DEADBODY);

	static out[64];
	formatex(out, charsmax(out), "models/player/%s/%s.mdl", model, model);
	entity_set_model(ent, out);
	entity_set_origin(ent, origin);
	entity_set_size(ent, Float:{-1.0, -1.0, -1.0}, Float:{1.0, 1.0, 1.0});

	entity_set_float(ent, EV_FL_frame, 255.0);
	entity_set_int(ent, EV_INT_sequence, seq);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);

	entity_set_int(ent, EV_INT_iuser1, id);
}

public Forward_EmitSound_pre(id, channel, sample[])
{
	if(!is_user_alive(id) || ttt_return_check(id))
		return;

	if(equal(sample, "common/wpn_denyselect.wav"))
	{
		new Float:fOrigin[2][3], origin[3];
		entity_get_vector(id, EV_VEC_origin, fOrigin[0]);
		get_user_origin(id, origin, 3);
		IVecFVec(origin, fOrigin[1]);
		if(get_distance_f(fOrigin[0], fOrigin[1]) > 60.0)
			return;

		new ent, fake;
		for(new i = 0; i < 33; i++)
		{
			fake = g_iBodyInfo[i][BODY_ENTID];
			if(!is_valid_ent(fake) || !is_visible(id, fake))
				continue;

			if(get_dat_deadbody(fake, fOrigin[0], fOrigin[1]))
			{
				ent = fake;
				break;
			}
		}

		if(ent) used_use(id, ent);
	}
}

public used_use(id, ent)
{
	if(!is_user_alive(id))
		return;

	new bodyowner = entity_get_int(ent, EV_INT_iuser1);

	if((ttt_get_special_state(id) == DETECTIVE || ttt_get_playerdata(bodyowner, PD_IDENTIFIED) == 1 || g_iRoundSpecial[DETECTIVE] == 0))
	{
		new ret;
		ExecuteForward(g_pShowInfoForward, ret, id, bodyowner);

		if(!ttt_get_playerdata(bodyowner, PD_IDENTIFIED))
		{
			set_attrib_all(bodyowner, 1);
			ttt_set_playerdata(bodyowner, PD_IDENTIFIED, true);
			ttt_set_playerdata(bodyowner, PD_SCOREBOARD, true);

			if(ttt_get_playerdata(bodyowner, PD_KILLEDSTATE) == TRAITOR && ttt_get_special_count(DETECTIVE) > 0)
			{
				new bonus, credits;
				static name[32];
				get_user_name(bodyowner, name, charsmax(name));

				new num, i;
				static players[32];
				get_players(players, num, "a");
				for(--num; num >= 0; num--)
				{
					i = players[num];
					if(ttt_get_special_state(i) == DETECTIVE)
					{
						bonus = get_pcvar_num(cvar_credits_det_bonusdead);
						credits = ttt_get_playerdata(i, PD_CREDITS) + bonus;

						ttt_set_playerdata(i, PD_CREDITS, credits);
						client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_AWARD3", bonus, id, special_names[TRAITOR], name);

						if(ttt_get_playerdata(bodyowner, PD_KILLEDBY) == i)
						{
							bonus = get_pcvar_num(cvar_credits_det_trakill);
							credits = ttt_get_playerdata(i, PD_CREDITS) + bonus;
							ttt_set_playerdata(i, PD_CREDITS, credits);
							client_print_color(i, print_team_default, "%s %L", TTT_TAG, i, "TTT_AWARD2", bonus, i, special_names[TRAITOR], name);
						}
					}
				}
			}
		}
	}
}

public _get_bodydata(plugin, params)
{
	if(params != 2)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_bodydata)")-1;

	new body = get_param(1);
	new datatype = get_param(2);

	return g_iBodyInfo[body][datatype];
}

public _set_bodydata(plugin, params)
{
	if(params != 3)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_set_bodydata)");

	new body = get_param(1);
	new datatype = get_param(2);
	new newdata = get_param(3);

	g_iBodyInfo[body][datatype] = newdata;

	return 1;
}

public _clear_bodydata(plugin, params)
{
	if(params != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_clear_bodydata)");

	new body = get_param(1);
	if(task_exists(TASK_VICTIM+body))
		remove_task(TASK_VICTIM+body);

	for(new i = 0; i < sizeof(g_iBodyInfo[]); i++)
		g_iBodyInfo[body][i] = 0;

	return 1;
}