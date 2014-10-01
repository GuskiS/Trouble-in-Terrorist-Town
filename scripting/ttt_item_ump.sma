#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <cs_weapons_api>
#include <amx_settings_api>
#include <ttt>

#define CSW_WEAPON CSW_UMP45
#define WEAPON_NAME "weapon_ump45"

new g_iItemID;
new const g_szModels[][] = {"models/ttt/v_ump.mdl", "models/ttt/p_ump.mdl", "models/ttt/w_ump.mdl"};
new Array:g_aModels, cvar_weapon_damage, cvar_weapon_speed, cvar_weapon_ammo, cvar_weapon_clip, cvar_weapon_price;

public plugin_precache()
{
	new model[TTT_MAXFILELENGHT];
	g_aModels = ArrayCreate(TTT_MAXFILELENGHT, 3);

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_V", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_V", g_szModels[0]);
		precache_model(g_szModels[0]);
		ArrayPushString(g_aModels, g_szModels[0]);
	}
	else
	{
		ArrayGetString(g_aModels, 0, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_P", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_P", g_szModels[1]);
		precache_model(g_szModels[1]);
		ArrayPushString(g_aModels, g_szModels[1]);
	}
	else
	{
		ArrayGetString(g_aModels, 1, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_W", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "UMP Prototype", "MODEL_W", g_szModels[2]);
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
	register_plugin("[TTT] Item: UMP Prototype", TTT_VERSION, TTT_AUTHOR);

	cvar_weapon_damage		= my_register_cvar("ttt_ump_damage",	"0.0");
	cvar_weapon_speed		= my_register_cvar("ttt_ump_speed",		"0.8");
	cvar_weapon_ammo		= my_register_cvar("ttt_ump_ammo",		"30");
	cvar_weapon_clip		= my_register_cvar("ttt_ump_clip",		"10");
	cvar_weapon_price		= my_register_cvar("ttt_price_ump",		"1");

	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0, true);

	new name[TTT_ITEMNAME];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID6");
	g_iItemID = ttt_buymenu_add(name, get_pcvar_num(cvar_weapon_price), DETECTIVE);
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
			data[STRUCT_CSWA_SILENCED] = -1;
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

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage)
{
	if(is_user_alive(inflictor) && attacker == inflictor && get_user_weapon(inflictor) == CSW_WEAPON && !ttt_return_check(attacker))
	{
		new ent = find_ent_by_owner(-1, WEAPON_NAME, inflictor);
		if(get_weapon_edict(ent, REPL_CSWA_SET) == 2 && get_weapon_edict(ent, REPL_CSWA_ITEMID) == g_iItemID)
		{
			new Float:angles[3];
			entity_get_vector(victim, EV_VEC_angles, angles);

			angles[0] += random_float(-damage, damage);
			angles[1] += random_float(-damage, damage);
			entity_set_vector(victim, EV_VEC_angles, angles);

			angles[2] += random_float(-damage, damage);
			entity_set_vector(victim, EV_VEC_punchangle, angles);

			entity_set_int(victim, EV_INT_fixangle, 1);
			return HAM_HANDLED;
		}
	}

	return HAM_IGNORED;
}