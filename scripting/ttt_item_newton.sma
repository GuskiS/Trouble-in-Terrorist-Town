#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cs_weapons_api>
#include <amx_settings_api>
#include <ttt>

#define CSW_WEAPON CSW_FIVESEVEN
#define WEAPON_NAME "weapon_fiveseven"
#define m_bitsDamageType 76

new g_iItemID, g_iWasPushed[33];
new const g_szModels[][] = {"models/ttt/v_newton.mdl", "models/ttt/p_newton.mdl", "models/ttt/w_newton.mdl"};
new Array:g_aModels, cvar_weapon_damage, cvar_weapon_speed, cvar_weapon_ammo, cvar_weapon_clip, cvar_weapon_price, cvar_weapon_force;

public plugin_precache()
{
	precache_sound("weapons/sfpistol_clipin.wav");
	precache_sound("weapons/sfpistol_clipout.wav");
	precache_sound("weapons/sfpistol_draw.wav");
	precache_sound("weapons/sfpistol_idle.wav");
	precache_sound("weapons/sfpistol_shoot_end.wav");
	precache_sound("weapons/sfpistol_shoot_start.wav");
	precache_sound("weapons/sfpistol_shoot1.wav");

	new model[TTT_MAXFILELENGHT];
	g_aModels = ArrayCreate(TTT_MAXFILELENGHT, 3);

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Newton Launcher", "MODEL_V", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Newton Launcher", "MODEL_V", g_szModels[0]);
		precache_model(g_szModels[0]);
		ArrayPushString(g_aModels, g_szModels[0]);
	}
	else
	{
		ArrayGetString(g_aModels, 0, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Newton Launcher", "MODEL_P", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Newton Launcher", "MODEL_P", g_szModels[1]);
		precache_model(g_szModels[1]);
		ArrayPushString(g_aModels, g_szModels[1]);
	}
	else
	{
		ArrayGetString(g_aModels, 1, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Newton Launcher", "MODEL_W", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Newton Launcher", "MODEL_W", g_szModels[2]);
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
	register_plugin("[TTT] Item: Newton Launcher", TTT_VERSION, TTT_AUTHOR);

	cvar_weapon_damage		= my_register_cvar("ttt_newton_damage",		"0.0");
	cvar_weapon_speed		= my_register_cvar("ttt_newton_speed",		"2.0");
	cvar_weapon_ammo		= my_register_cvar("ttt_newton_ammo",		"10");
	cvar_weapon_clip		= my_register_cvar("ttt_newton_clip",		"1");
	cvar_weapon_force		= my_register_cvar("ttt_newton_force",		"100.0");
	cvar_weapon_price		= my_register_cvar("ttt_price_newton",		"1");

	RegisterHam(Ham_Killed, "player", "Ham_Killed_pre", 0, true);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0, true);

	new name[TTT_ITEMNAME];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID16");
	g_iItemID = ttt_buymenu_add(name, get_pcvar_num(cvar_weapon_price), TRAITOR);
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

public Ham_Killed_pre(victim, killer, shouldgib)
{
	if(!killer && (get_pdata_int(victim, m_bitsDamageType, 5) & DMG_FALL) && g_iWasPushed[victim])
		SetHamParamEntity(2, g_iWasPushed[victim]);

	g_iWasPushed[victim] = false;
}

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage)
{
	if(!ttt_return_check(attacker) && is_user_alive(inflictor) && attacker == inflictor && get_user_weapon(inflictor) == CSW_WEAPON)
	{
		new ent = find_ent_by_owner(-1, WEAPON_NAME, inflictor);
		if(get_weapon_edict(ent, REPL_CSWA_SET) == 2 && get_weapon_edict(ent, REPL_CSWA_ITEMID) == g_iItemID)
		{
			new Float:push[3], Float:velocity[3];
			entity_get_vector(victim, EV_VEC_velocity, velocity);
			create_velocity_vector(victim, attacker, push);
			push[0] += velocity[0];
			push[1] += velocity[1];
			entity_set_vector(victim, EV_VEC_velocity, push);
			g_iWasPushed[victim] = inflictor;
			return HAM_HANDLED;
		}
	}

	return HAM_IGNORED;
}

stock create_velocity_vector(victim, attacker, Float:velocity[3])
{
	if(!is_user_alive(victim) || !is_user_alive(attacker))
		return 0;

	new Float:vicorigin[3];
	new Float:attorigin[3];
	entity_get_vector(victim   , EV_VEC_origin , vicorigin);
	entity_get_vector(attacker , EV_VEC_origin , attorigin);

	new Float:origin2[3];
	origin2[0] = vicorigin[0] - attorigin[0];
	origin2[1] = vicorigin[1] - attorigin[1];

	new Float:largestnum = 0.0;

	if(floatabs(origin2[0]) > largestnum)
		largestnum = floatabs(origin2[0]);
	if(floatabs(origin2[1]) > largestnum)
		largestnum = floatabs(origin2[1]);

	origin2[0] /= largestnum;
	origin2[1] /= largestnum;

	velocity[0] = ( origin2[0] * (get_pcvar_float(cvar_weapon_force) * 3000) ) / entity_range(victim, attacker);
	velocity[1] = ( origin2[1] * (get_pcvar_float(cvar_weapon_force) * 3000) ) / entity_range(victim, attacker);
	if(velocity[0] <= 20.0 || velocity[1] <= 20.0)
		velocity[2] = random_float(400.0, 575.0);

	return 1;
}