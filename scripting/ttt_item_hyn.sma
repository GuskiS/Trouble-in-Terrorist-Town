#include <amxmodx>
#include <ttt>

new g_iItem_HYN, cvar_price_hyn, g_iItemBought;
new g_iHasHYN[33], g_iItem_Backpack[33];

public plugin_init()
{
	register_plugin("[TTT] Item: Hide your name", TTT_VERSION, TTT_AUTHOR);

	cvar_price_hyn = my_register_cvar("ttt_price_hyn", "1");

	new name[TTT_ITEMLENGHT];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID7");
	g_iItem_HYN = ttt_buymenu_add(name, get_pcvar_num(cvar_price_hyn), PC_TRAITOR);
}

public ttt_gamemode(gamemode)
{
	if(!g_iItemBought)
		return;

	if(gamemode == GAME_PREPARING || gamemode == GAME_RESTARTING)
	{
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			g_iHasHYN[id] = false;
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
		new hide = ttt_get_playerdata(id, PD_HIDENAME);
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_HYN", hide ? "de" : "", name);
		ttt_set_playerdata(id, PD_HIDENAME, !hide);
		ttt_backpack_show(id);
	}

	return PLUGIN_CONTINUE;
}