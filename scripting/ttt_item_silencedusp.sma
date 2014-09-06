#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <cs_weapons_api>
#include <amx_settings_api>
#include <ttt>

#define OFFSET_LINUX_WEAPONS		4
#define m_iPlayer					41
#define m_flNextSecondaryAttack		47

#define CSW_WEAPON CSW_USP
#define WEAPON_NAME "weapon_usp"

new g_iItemID;
new const g_szModels[][] = {"models/ttt/v_silencedusp.mdl", "models/ttt/p_silencedusp.mdl", "models/ttt/w_silencedusp.mdl"};
new Array:g_aModels, cvar_weapon_damage, cvar_weapon_speed, cvar_weapon_ammo, cvar_weapon_clip, cvar_weapon_price, g_iKilledWith[33];

public plugin_precache()
{
	new model[TTT_MAXFILELENGHT];
	g_aModels = ArrayCreate(TTT_MAXFILELENGHT, 3);

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Silenced USP", "MODEL_V", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Silenced USP", "MODEL_V", g_szModels[0]);
		precache_model(g_szModels[0]);
		ArrayPushString(g_aModels, g_szModels[0]);
	}
	else
	{
		ArrayGetString(g_aModels, 0, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Silenced USP", "MODEL_P", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Silenced USP", "MODEL_P", g_szModels[1]);
		precache_model(g_szModels[1]);
		ArrayPushString(g_aModels, g_szModels[1]);
	}
	else
	{
		ArrayGetString(g_aModels, 1, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Silenced USP", "MODEL_W", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Silenced USP", "MODEL_W", g_szModels[2]);
		precache_model(g_szModels[2]);
		ArrayPushString(g_aModels, g_szModels[2]);
	}
	else
	{
		ArrayGetString(g_aModels, 2, model, charsmax(model));
		precache_model(model);
	}
}

public plugin_init()
{
	register_plugin("[TTT] Item: Silent USP", TTT_VERSION, TTT_AUTHOR);

	cvar_weapon_damage		= my_register_cvar("ttt_usp_damage",	"2.0");
	cvar_weapon_speed		= my_register_cvar("ttt_usp_speed",		"-2.0");
	cvar_weapon_ammo		= my_register_cvar("ttt_usp_ammo",		"50");
	cvar_weapon_clip		= my_register_cvar("ttt_usp_clip",		"10");
	cvar_weapon_price		= my_register_cvar("ttt_price_usp",		"2");

	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_NAME, "Ham_SecondaryAttack_pre", 0);

	new name[TTT_ITEMNAME];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID10");
	g_iItemID = ttt_buymenu_add(name, get_pcvar_num(cvar_weapon_price), TRAITOR);
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_is_usp_kill", "_is_usp_kill");
}

public client_disconnect(id)
{
	g_iKilledWith[id] = false;
}

public ttt_item_selected(id, item, name[], price)
{
	if(g_iItemID == item)
	{
		if(user_has_weapon(id, CSW_WEAPON))
			engclient_cmd(id, "drop", WEAPON_NAME);

		static data[STOREABLE_STRUCTURE];
		if(!data[STRUCT_CSWA_CSW])
		{
			data[STRUCT_CSWA_ITEMID] = g_iItemID;
			data[STRUCT_CSWA_CSW] = CSW_WEAPON;
			data[STRUCT_CSWA_CLIP] = get_pcvar_num(cvar_weapon_clip);
			data[STRUCT_CSWA_MAXCLIP] = get_pcvar_num(cvar_weapon_clip);
			data[STRUCT_CSWA_AMMO] = get_pcvar_num(cvar_weapon_ammo);
			data[STRUCT_CSWA_STACKABLE] = true;
			data[STRUCT_CSWA_SILENCED] = true;
			data[STRUCT_CSWA_SPEEDDELAY] = _:get_pcvar_float(cvar_weapon_speed);
			data[STRUCT_CSWA_DAMAGE] = _:get_pcvar_float(cvar_weapon_damage);
			data[STRUCT_CSWA_RELOADTIME] = _:0.0;
			ArrayGetString(g_aModels, 0, data[STRUCT_CSWA_MODEL_V], charsmax(data[STRUCT_CSWA_MODEL_V]));
			ArrayGetString(g_aModels, 1, data[STRUCT_CSWA_MODEL_P], charsmax(data[STRUCT_CSWA_MODEL_P]));
			ArrayGetString(g_aModels, 2, data[STRUCT_CSWA_MODEL_W], charsmax(data[STRUCT_CSWA_MODEL_W]));
		}

		cswa_give_specific(id, data);

		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ITEM2", name, id, "TTT_ITEM5");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public ttt_gamemode(gamemode)
{
	if(gamemode == PREPARING || gamemode == RESTARTING)
	{
		new num;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
			g_iKilledWith[players[num]] = false;
	}
}

public cswa_killed(ent, victim, killer)
{
	if(get_weapon_edict(ent, REPL_CSWA_SET) == 2)
	{
		g_iKilledWith[victim] = true;
	}
}

public Ham_SecondaryAttack_pre(ent)
{
	if(!is_valid_ent(ent))
		return HAM_IGNORED;
		
	new id = get_pdata_cbase(ent, m_iPlayer, OFFSET_LINUX_WEAPONS);
	if(is_user_alive(id) && !ttt_return_check(id))
	{
		new ent = find_ent_by_owner(-1, WEAPON_NAME, id);
		if(get_weapon_edict(ent, REPL_CSWA_SET) == 2 && get_weapon_edict(ent, REPL_CSWA_ITEMID) == g_iItemID)
		{
			set_pdata_float(ent, m_flNextSecondaryAttack, 9999.0, OFFSET_LINUX_WEAPONS);
			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

// API
public _is_usp_kill(plugin, params)
{
	new id = get_param(1);
	if(params != 1 || is_user_alive(id))
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params or user alive (ttt_is_usp_kill)");

	return g_iKilledWith[id];
}