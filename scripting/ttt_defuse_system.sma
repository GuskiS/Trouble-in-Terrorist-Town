#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <cstrike>
#include <ttt>

#define MAX_C4 10

enum _:C4INFO
{
	STORED,
	ENT,
	WIRES,
	RIGHT,
	TIME
}

new const g_iWireColors[][] =
{
	"Red",
	"Green",
	"Blue",
	"White",
	"Black",
	"Yellow"
};

new g_iPlayerWires[33][2][sizeof(g_iWireColors)];
new g_iPlayerC4[33];
new g_iC4Info[MAX_C4][C4INFO];

public plugin_init()
{
	register_plugin("[TTT] Defusing system", TTT_VERSION, TTT_AUTHOR);
	register_forward(FM_EmitSound, "Forward_EmitSound_pre", 0);
}

public Forward_EmitSound_pre(id, channel, sample[])
{
	if(!is_user_alive(id) || ttt_return_check(id))
		return;

	if(equal(sample, "common/wpn_select.wav"))
	{
		new ent, body;
		static classname[32];
		get_user_aiming(id, ent, body);
		entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));

		if(equal(classname, "grenade"))
		{
			entity_get_string(ent, EV_SZ_model, classname, charsmax(classname));
			if(equal(classname, "models/w_c4.mdl"))
			{
				if(entity_range(id, ent) < 50.0)
					ttt_wires_show(id, ent);
				else client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_DEFUSE3");
			}
		}
	}
}

public bomb_planted(id)
{
	new c4 = -1;
	while((c4 = find_ent_by_model(c4, "grenade", "models/w_c4.mdl")))
	{
		if(!entity_get_int(c4, EV_INT_iuser1))
			set_task(0.2, "check_all", c4);
	}
}

public check_all(c4)
{
	new index = c4_store(c4), timer = floatround(cs_get_c4_explode_time(c4) - get_gametime()), wires;
	new maxtime = get_pcvar_num(get_cvar_pointer("ttt_c4_maxtime"))/sizeof(g_iWireColors);

	for(new i = 0; i < sizeof(g_iWireColors); i++)
	{
		if(timer > (maxtime * (i+1)))
			wires++;
	}

	if(wires == 1)
		wires = 2;

	g_iC4Info[index][WIRES] = wires;
	g_iC4Info[index][TIME] = timer;

	new Float:temp = ((wires-0.5)/wires)/0.5;
	new ran = random_num(floatround_floor, floatround_ceil);
	new rights = floatround(wires/temp, floatround_method:ran);

	if(wires == 2)
		rights = 1;

	g_iC4Info[index][RIGHT] = rights;
}

public ttt_gamemode(gamemode)
{
	if(gamemode == PREPARING || gamemode == RESTARTING)
	{
		c4_clear(-1);
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			reset_all(id);
			g_iPlayerC4[id] = 0;
		}
	}
}

public reset_all(id)
{
	for(new i = 0; i <= charsmax(g_iWireColors); i++)
	{
		g_iPlayerWires[id][0][i] = -1;
		g_iPlayerWires[id][1][i] = 0;
	}

	if(task_exists(id))
		remove_task(id);
}

public ttt_wires_show(id, ent)
{
	reset_all(id);
	get_c4_info(id, ent);

	new param[1];
	param[0] = ent;
	set_task(1.0, "check_distance", id, param, 1, "b");

	new menu = menu_create("\rWires", "ttt_wires_handler");
	for(new i = 0; i < g_iC4Info[c4_get(ent)][WIRES]; i++)
		menu_additem(menu, g_iWireColors[g_iPlayerWires[id][0][i]], "", 0);

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_NOCOLORS, 1);

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public check_distance(param[], id)
{
	if(!is_valid_ent(param[0]) || entity_range(id, param[0]) > 50.0)
	{
		remove_task(id);
		show_menu(id, 0, "^n", 1);
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_DEFUSE3");
	}
}

public ttt_wires_handler(id, menu, item)
{
	remove_task(id);
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	static command[6], name[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, command, charsmax(command), name, charsmax(name), callback);
	menu_destroy(menu);

	check_defusion(id, item, g_iPlayerC4[id]);
	return PLUGIN_HANDLED;
}

public get_c4_info(id, c4)
{
	if(!is_user_connected(id))
		return;

	g_iPlayerC4[id] = c4;
	new size = g_iC4Info[c4_get(c4)][WIRES];
	random_right(id, size, c4);

	for(new i = 0; i < size; i++)
		g_iPlayerWires[id][0][i] = random_order(id, size);
}

public random_order(id, size)
{
	new i, ran = -1;
	while(ran == -1)
	{
		ran = random_num(0, size-1);
		for(i = 0; i < size; i++)
			if(g_iPlayerWires[id][0][i] == ran)
				ran = -1;
	}

	return ran;
}

public random_right(id, size, c4)
{
	new ran, ret, i, right = g_iC4Info[c4_get(c4)][RIGHT];
	if(cs_get_user_defuse(id) && (size-right) != 1)
		right++;

	while(ret < right)
	{
		for(i = 0; i < size; i++)
		{
			ran = random_num(0, 1);
			if(ran && !g_iPlayerWires[id][1][i])
			{
				ret++;
				g_iPlayerWires[id][1][i] = ran;
			}

			if(ret >= right)
				break;
		}
	}
}

public check_defusion(id, item, c4)
{
	if(g_iPlayerWires[id][1][item])
	{
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("BarTime"), _, id);
		write_short(1);
		message_end();

		if(is_valid_ent(c4))
			remove_entity(c4);

		ttt_set_stats(id, STATS_BOMBD, ttt_get_player_stat(id, STATS_BOMBD)+1);
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_DEFUSE1");
	}
	else
	{
		cs_set_c4_explode_time(c4, get_gametime()+0.5);
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_DEFUSE2");
	}

	c4_clear(item);
}

stock c4_store(c4)
{
	new i;
	for(i = 0; i < MAX_C4; i++)
	{
		if(!g_iC4Info[i][STORED])
		{
			g_iC4Info[i][STORED] = 1;
			g_iC4Info[i][ENT] = c4;
			break;
		}
	}

	return i;
}

stock c4_get(c4)
{
	new i;
	for(i = 0; i < MAX_C4; i++)
		if(g_iC4Info[i][ENT] == c4)
			break;

	return i;
}

stock c4_clear(c4)
{
	for(new z, i = 0; i < MAX_C4; i++)
	{
		for(z = 0; z < C4INFO; z++)
		{
			if(c4 >= 0) g_iC4Info[c4][z] = 0;
			else g_iC4Info[i][z] = 0;
		}

		if(c4 >= 0) break;
	}
}