#include <amxmodx>
#include <cstrike>
#include <ttt>

enum _:ItemData
{
    ItemName[TTT_ITEMNAME],
    ItemCost,
	ItemTeam
}

new g_iTotalItems = -1, g_iSetupItems = -1;
new g_iItemForward, Array:g_iItems, Array:g_iSetup;

new const g_sBuyCommands[][] =  
{ 
    "buy", "buyequip", "usp", "glock", "deagle", "p228", "elites", "fn57", "m3", "xm1014", "mp5", "tmp", "p90", "mac10", "ump45", "ak47",  
    "galil", "famas", "sg552", "m4a1", "aug", "scout", "awp", "g3sg1", "sg550", "m249", "vest", "vesthelm", "flash", "hegren", 
    "sgren", "defuser", "nvgs", "shield", "primammo", "secammo", "km45", "9x19mm", "nighthawk", "228compact", "12gauge", 
    "autoshotgun", "smg", "mp", "c90", "cv47", "defender", "clarion", "krieg552", "bullpup", "magnum", "d3au1", "krieg550", 
    "buyammo1", "buyammo2", "cl_autobuy", "cl_rebuy", "cl_setautobuy", "cl_setrebuy"
};

public plugin_precache()
	precache_sound("items/gunpickup2.wav");

public plugin_init()
{
	register_plugin("[TTT] Item menu base", TTT_VERSION, TTT_AUTHOR);

	register_clcmd("say /buy", "ttt_buymenu_show");
	register_clcmd("say_team /buy", "ttt_buymenu_show");

	g_iItems = ArrayCreate(ItemData);
	g_iSetup = ArrayCreate(SetupData);

	g_iItemForward = CreateMultiForward("ttt_item_selected", ET_STOP, FP_CELL, FP_CELL, FP_STRING, FP_CELL);
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_buymenu_add", "_buymenu_add");
	register_native("ttt_item_setup_add", "_item_setup_add");
	register_native("ttt_item_setup_remove", "_item_setup_remove");
	register_native("ttt_item_setup_update", "_item_setup_update");
	register_native("ttt_item_setup_get", "_item_setup_get");
	register_native("ttt_is_item_setup", "_is_item_setup");
	register_native("ttt_get_item_name", "_get_item_name");
}

public ttt_gamemode(gamemode)
{
	if(gamemode == PREPARING)
		ArrayClear(g_iSetup);
}

public client_command(id)
{
	if(ttt_return_check(id) || !is_user_alive(id))
		return PLUGIN_CONTINUE;

	new i;
	static command[16];
	read_argv(0, command, charsmax(command));
	for(i = 0; i <= charsmax(g_sBuyCommands); i++)
	{
		if(equal(command, g_sBuyCommands[i]))
		{
			if(!task_exists(id))
				set_task(0.1, "ttt_buymenu_show", id);

			return PLUGIN_HANDLED;
		}
	}

	if(equal(command, "client_buy_open"))
	{
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("BuyClose"), _, id);
		message_end();
		ttt_buymenu_show(id);
	}

	return PLUGIN_CONTINUE;
}

public ttt_buymenu_show(id)
{
	if(ttt_return_check(id) || !is_user_alive(id))
		return PLUGIN_HANDLED;

	new team = ttt_get_special_state(id);
	if(g_iTotalItems == -1)
	{
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_NOITEMSTOTAL");
		return PLUGIN_HANDLED;
	}

	new	i, inno;
	static data[ItemData], item[128], num[3];
	new iMenu = menu_create("\rTTT Buy menu", "ttt_buymenu_handle");
	for(i = 0; i < g_iTotalItems; i++)
    {
		ArrayGetArray(g_iItems, i, data);
		if(data[ItemCost] == -1) continue;
		if(data[ItemTeam] == INNOCENT)
			inno++;

		if((data[ItemTeam] == SPECIAL && (team == TRAITOR || team == DETECTIVE)) || team == data[ItemTeam])
		{
			formatex(item, charsmax(item), "%s\R\y%i												", data[ItemName], data[ItemCost]);
			num_to_str(i, num, charsmax(num));
			menu_additem(iMenu, item, num);
		}
    }

	if(!inno && team == INNOCENT)
	{
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_NOITEMSTEAM", id, special_names[team]);
		return PLUGIN_HANDLED;
	}

	menu_display(id, iMenu, 0);
	return PLUGIN_HANDLED;
}

public ttt_buymenu_handle(id, menu, item)
{
	if(ttt_return_check(id) || !is_user_alive(id))
		return PLUGIN_HANDLED;

	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	new itemid = str_to_num(num);
	static data[ItemData];
	ArrayGetArray(g_iItems, itemid, data);

	if((data[ItemTeam] == SPECIAL && ttt_get_special_state(id) != TRAITOR && ttt_get_special_state(id) != DETECTIVE) || (ttt_get_special_state(id) != data[ItemTeam] && SPECIAL != data[ItemTeam]))
	{
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ITEM3", id, special_names[data[ItemTeam]], data[ItemName]);
		return PLUGIN_HANDLED;
	}

	new credits = ttt_get_playerdata(id, PD_CREDITS);
	if(credits < data[ItemCost])
	{
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ITEM4", data[ItemName], data[ItemCost]);
		return PLUGIN_HANDLED;
	}

	new ret;
	ExecuteForward(g_iItemForward, ret, id, itemid, data[ItemName], data[ItemCost]);

	if(ret == PLUGIN_HANDLED)
	{
		//emit_sound(id, CHAN_WEAPON, "items/gunpickup2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
		client_cmd(id, "spk ^"%s^"", "items/gunpickup2.wav");
		ttt_set_playerdata(id, PD_CREDITS, credits-data[ItemCost]);
	}

	static msg[70], name[32];
	get_user_name(id, name, charsmax(name));
	formatex(msg, charsmax(msg), "Player %s bought item %s with ID %d", name, data[ItemName], itemid);
	ttt_log_to_file(LOG_ITEM, msg);

	return PLUGIN_HANDLED;
}

public _buymenu_add(plugin, param)
{
	static data[ItemData];
	get_string(1, data[ItemName], charsmax(data[ItemName]));
	data[ItemCost] = get_param(2);
	data[ItemTeam] = get_param(3);

	ArrayPushArray(g_iItems, data);
	if(g_iTotalItems == -1)
		g_iTotalItems = 0;

	g_iTotalItems++;
	return (g_iTotalItems - 1);
}

public _item_setup_add(plugin, param)
{
	static data[SetupData];
	data[SETUP_ITEMID] = get_param(1);
	data[SETUP_ITEMENT] = get_param(2);
	data[SETUP_ITEMTIME] = get_param(3);
	data[SETUP_ITEMOWNER] = get_param(4);
	data[SETUP_ITEMTRACER] = get_param(5);
	data[SETUP_ITEMACTIVE] = get_param(6);
	get_string(7, data[SETUP_ITEMNAME], charsmax(data[SETUP_ITEMNAME]));

	ArrayPushArray(g_iSetup, data);
	g_iSetupItems = ArraySize(g_iSetup);

	return (g_iSetupItems -1);
}

public _item_setup_remove(plugin, param)
{
	new item = get_param(1);
	if(item > -1)
	{
		new data[SetupData] = {0, 0, ...};
		ArraySetArray(g_iSetup, item, data);
		return 1;
	}

	return -1;
}

public _item_setup_get(plugin, param)
{
	new item = get_param(1);
	if(item > -1)
	{
		static data[SetupData];
		ArrayGetArray(g_iSetup, item, data);

		set_array(2, data, sizeof(data));
		return 1;
	}

	return -1;
}

public _item_setup_update(plugin, param)
{
	new item = get_param(1);
	if(item > -1)
	{
		static data[SetupData];
		get_array(2, data, sizeof(data));

		ArraySetArray(g_iSetup, item, data);
		return 1;
	}

	return -1;
}

public _is_item_setup(plugin, param)
{
	if(param != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_is_item_setup)") -1;

	if(g_iSetupItems > 0 && ArraySize(g_iSetup))
	{
		new ent = get_param(1);
		new i, data[SetupData], msg = -1;
		for(i = 0; i < g_iSetupItems-1; i++)
		{
			ArrayGetArray(g_iSetup, i, data);
			if(ent == data[SETUP_ITEMENT])
			{
				msg = i;
				break;
			}
		}
		return msg;
	}

	return -1;
}

public _get_item_name(plugin, param)
{
	if(param != 3)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_item_name)") -1;

	new data[SetupData];
	ArrayGetArray(g_iSetup, get_param(1), data);

	set_string(2, data[ItemName], get_param(3));

	return 1;
}