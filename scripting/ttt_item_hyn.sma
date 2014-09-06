#include <amxmodx>
#include <ttt>

new g_iItem_HYN, cvar_price_hyn, g_iItemBought;
new g_iHasHYN[33], g_iActiveHYN[33], g_iItem_Backpack[33];

public plugin_init()
{
	register_plugin("[TTT] Item: Hide your name", TTT_VERSION, TTT_AUTHOR);

	cvar_price_hyn = my_register_cvar("ttt_price_hyn", "1");

	new name[TTT_ITEMNAME];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID7");
	g_iItem_HYN = ttt_buymenu_add(name, get_pcvar_num(cvar_price_hyn), TRAITOR);
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_get_hide_name", "_get_hide_name");
}

public ttt_gamemode(gamemode)
{
	if(!g_iItemBought)
		return;

	if(gamemode == PREPARING || gamemode == RESTARTING)
	{
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			g_iHasHYN[id] = false;
			g_iActiveHYN[id] = false;
			g_iItem_Backpack[id] = -1;
		}
		g_iItemBought = false;
	}
}

public ttt_item_selected(id, item, name[], price)
{
	if(g_iItem_HYN == item)
	{
		g_iHasHYN[id] = true;
		g_iItemBought = true;
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ITEM2", name, id, "TTT_ITEM_BACKPACK", name);
		g_iItem_Backpack[id] = ttt_backpack_add(id, name);

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public ttt_item_backpack(id, item, name[])
{
	if(g_iHasHYN[id] && g_iItem_Backpack[id] == item)
	{
		client_print_color(id, print_team_default, "%s %L", "%s %L", TTT_TAG, id, "TTT_HYN", g_iActiveHYN[id] ? "de" : "", name);
		g_iActiveHYN[id] = !g_iActiveHYN[id];
		ttt_backpack_show(id);
	}

	return PLUGIN_CONTINUE;
}

public _get_hide_name(plugin, params)
{
	if(params != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_get_hide_name)");

	new id = get_param(1);
	return g_iActiveHYN[id];
}