#include <amxmodx>
#include <engine>
#include <fun>
#include <cs_weapons_api>
#include <amx_settings_api>
#include <ttt>

#define WEAPON_CSWID CSW_UMP45
#define WEAPON_NAME "weapon_ump45"

new g_iItemID;
new g_szModels[3][TTT_FILELENGHT];
new cvar_weapon_damage, cvar_weapon_speed, cvar_weapon_ammo, cvar_weapon_clip, cvar_weapon_price, cvar_weapon_reload, cvar_weapon_recoil;

public plugin_precache()
{
	if(!amx_load_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_V", g_szModels[0], charsmax(g_szModels[])))
	{
		g_szModels[0] = "models/ttt/v_ump.mdl";
		amx_save_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_V", g_szModels[0]);
	}
	precache_model(g_szModels[0]);

	if(!amx_load_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_P", g_szModels[1], charsmax(g_szModels[])))
	{
		g_szModels[1] = "models/ttt/p_ump.mdl";
		amx_save_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_P", g_szModels[1]);
	}
	precache_model(g_szModels[1]);

	if(!amx_load_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_W", g_szModels[2], charsmax(g_szModels[])))
	{
		g_szModels[2] = "models/ttt/w_ump.mdl";
		amx_save_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_W", g_szModels[2]);
	}
	precache_model(g_szModels[2]);
}

public plugin_init()
{
	register_plugin("[TTT] Item: UMP Prototype", TTT_VERSION, TTT_AUTHOR);

	cvar_weapon_clip		= my_register_cvar("ttt_ump_clip",		"2");
	cvar_weapon_ammo		= my_register_cvar("ttt_ump_ammo",		"0");
	cvar_weapon_speed		= my_register_cvar("ttt_ump_speed",		"10.0");
	cvar_weapon_damage		= my_register_cvar("ttt_ump_damage",	"0.0");
	cvar_weapon_reload		= my_register_cvar("ttt_ump_reload",	"0.0");
	cvar_weapon_recoil		= my_register_cvar("ttt_ump_recoil",	"0.0");
	cvar_weapon_price		= my_register_cvar("ttt_price_ump",		"2");

	new name[TTT_ITEMLENGHT];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID6");
	g_iItemID = ttt_buymenu_add(name, get_pcvar_num(cvar_weapon_price), PC_DETECTIVE);
}

public ttt_item_selected(id, item, name[], price)
{
	if(g_iItemID == item)
	{
		if(user_has_weapon(id, WEAPON_CSWID))
			engclient_cmd(id, "drop", WEAPON_NAME);

		static data[STOREABLE_STRUCTURE];
		if(!data[STRUCT_CSWA_CSW])
		{
			data[STRUCT_CSWA_ITEMID] = g_iItemID;
			data[STRUCT_CSWA_CSW] = WEAPON_CSWID;
			data[STRUCT_CSWA_CLIP] = get_pcvar_num(cvar_weapon_clip);
			data[STRUCT_CSWA_MAXCLIP] = get_pcvar_num(cvar_weapon_clip);
			data[STRUCT_CSWA_AMMO] = get_pcvar_num(cvar_weapon_ammo);
			data[STRUCT_CSWA_STACKABLE] = true;
			data[STRUCT_CSWA_SILENCED] = -1;
			data[STRUCT_CSWA_SPEEDDELAY] = _:get_pcvar_float(cvar_weapon_speed);
			data[STRUCT_CSWA_DAMAGE] = _:get_pcvar_float(cvar_weapon_damage);
			data[STRUCT_CSWA_RELOADTIME] = _:get_pcvar_float(cvar_weapon_reload);
			data[STRUCT_CSWA_RECOIL] = _:get_pcvar_float(cvar_weapon_recoil);
			data[STRUCT_CSWA_MODEL_V] = g_szModels[0];
			data[STRUCT_CSWA_MODEL_P] = g_szModels[1];
			data[STRUCT_CSWA_MODEL_W] = g_szModels[2];
		}

		cswa_give_specific(id, data);

		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ITEM2", name, id, "TTT_ITEM5");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public cswa_damage(weapon_id, victim, attacker, Float:damage)
{
	if(get_weapon_edict(weapon_id, REPL_CSWA_ITEMID) == g_iItemID)
	{
		new Float:angles[3];
		new colors[3];
		new VictimState = ttt_get_playerstate(victim);
		if(VictimState == PC_DETECTIVE || VictimState == PC_TRAITOR || VictimState == PC_INNOCENT)
			{
				if(VictimState == PC_TRAITOR)
				colors = {255,0,0};
				if(VictimState == PC_DETECTIVE)
				colors = {0,0,255};
				if(VictimState == PC_INNOCENT)
				colors = {0,255,0};
				
				set_user_rendering(victim,kRenderFxGlowShell,colors[0],colors[1],colors[2],kRenderNormal,25);
				set_task( 2.5, "remove_glowump", victim );
			}
		entity_get_vector(victim, EV_VEC_angles, angles);

		angles[0] += random_float(-damage, damage);
		angles[1] += random_float(-damage, damage);
		entity_set_vector(victim, EV_VEC_angles, angles);

		angles[2] += random_float(-damage, damage);
		entity_set_vector(victim, EV_VEC_punchangle, angles);

		entity_set_int(victim, EV_INT_fixangle, 1);
	}
}
public remove_glowump (victim)
{
	set_user_rendering(victim,kRenderFxGlowShell,0,0,0,kRenderNormal,25);
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3082\\ f0\\ fs16 \n\\ par }
*/
