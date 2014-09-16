#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <ttt>
#include <amx_settings_api>

#define XO_WEAPON					4
#define m_pPlayer					41
#define m_flNextPrimaryAttack		46
#define m_flNextSecondaryAttack		47
#define m_flTimeWeaponIdle			48

enum _:TYPE
{
	K_NONE,
	K_TEMP,
	K_ON,
	K_BOTH
}

new Array:g_aKnifeModels;
new const g_szKnifeModels[][] = {"models/v_knife.mdl", "models/p_knife.mdl", "models/ttt/w_throwingknife.mdl"};
new const Float:g_szDroppedSize[][3] =
{
	{-20.0, -20.0, -5.0},
	{20.0, 20.0, 5.0}
};

new g_iKnifeType[33], g_iKilledByKnife[33], g_iItem_Knife, g_iNadeVelocity[33][2];
new cvar_dmgmult, cvar_pattack_rate, cvar_sattack_rate, cvar_pattack_recoil,
	cvar_sattack_recoil, cvar_price_knife, cvar_knife_glow, cvar_knife_velocity, cvar_knife_bounce;

public plugin_precache()
{
	new model[TTT_MAXFILELENGHT];
	g_aKnifeModels = ArrayCreate(TTT_MAXFILELENGHT, 3);

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Knife", "MODEL_V", g_aKnifeModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Knife", "MODEL_V", g_szKnifeModels[0]);
		precache_model(g_szKnifeModels[0]);
		ArrayPushString(g_aKnifeModels, g_szKnifeModels[0]);
	}
	else
	{
		ArrayGetString(g_aKnifeModels, 0, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Knife", "MODEL_P", g_aKnifeModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Knife", "MODEL_P", g_szKnifeModels[1]);
		precache_model(g_szKnifeModels[1]);
		ArrayPushString(g_aKnifeModels, g_szKnifeModels[1]);
	}
	else
	{
		ArrayGetString(g_aKnifeModels, 1, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Knife", "MODEL_W", g_aKnifeModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Knife", "MODEL_W", g_szKnifeModels[2]);
		precache_model(g_szKnifeModels[2]);
		ArrayPushString(g_aKnifeModels, g_szKnifeModels[2]);
	}
	else
	{
		ArrayGetString(g_aKnifeModels, 2, model, charsmax(model));
		precache_model(model);
	}
}

public plugin_init()
{
	register_plugin("[TTT] Item: Knife", TTT_VERSION, TTT_AUTHOR);

	cvar_dmgmult			= my_register_cvar("ttt_knife_multi",				"11.0");
	cvar_pattack_rate		= my_register_cvar("ttt_knife_primary_rate",		"0.6");
	cvar_sattack_rate		= my_register_cvar("ttt_knife_secondary_rate", 		"1.3");
	cvar_pattack_recoil		= my_register_cvar("ttt_knife_primary_recoil", 		"-3.6");
	cvar_sattack_recoil		= my_register_cvar("ttt_knife_secondary_recoil",	"-5.0");
	cvar_price_knife		= my_register_cvar("ttt_price_knife",				"3");
	cvar_knife_glow			= my_register_cvar("ttt_knife_glow",				"1");
	cvar_knife_velocity		= my_register_cvar("ttt_knife_velocity",			"1500");
	cvar_knife_bounce		= my_register_cvar("ttt_knife_bounce",				"0");

	register_think("grenade", "Think_Grenade");
	register_touch("grenade", "*", "Touch_Grenade");

	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_smokegrenade", "Ham_PrimaryAttack_Grenade_pre", 0);
	RegisterHam(Ham_Killed, "player", "Ham_Killed_pre", 0, true);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0, true);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "Ham_PrimaryAttack_post", 1);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "Ham_SecondaryAttack_post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Item_Deploy_post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_smokegrenade", "Ham_Item_Deploy_Grenade_post", 1);

	new name[TTT_ITEMNAME];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID11");
	g_iItem_Knife = ttt_buymenu_add(name, get_pcvar_num(cvar_price_knife), TRAITOR);

	register_clcmd("drop", "clcmd_drop");
	register_clcmd("weapon_knife", "clcmd_knife");
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_is_knife_kill", "_is_knife_kill");
	register_native("ttt_knife_holding", "_knife_holding");
}

public client_disconnect(id)
{
	g_iKnifeType[id] = K_NONE;
	g_iKilledByKnife[id] = false;
	g_iNadeVelocity[id][0] = false;
	g_iNadeVelocity[id][1] = false;
}

public ttt_gamemode(gamemode)
{
	if(gamemode == ENDED || gamemode == RESTARTING)
	{
		move_grenade();
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			g_iKilledByKnife[id] = false;
			g_iNadeVelocity[id][0] = false;
			g_iNadeVelocity[id][1] = false;

			if(is_user_alive(id) && g_iKnifeType[id] == K_ON)
				reset_user_knife(id);
			g_iKnifeType[id] = K_NONE;
		}
	}
}

public ttt_item_selected(id, item, name[], price)
{
	if(g_iItem_Knife == item)
	{
		if(get_user_weapon(id) == CSW_KNIFE)
			strip_knife(id, K_ON);
		else g_iKnifeType[id] = K_TEMP;

		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ITEM2", name, id, "TTT_ITEM5");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public clcmd_drop(id)
{
	if(g_iKnifeType[id] == K_ON)
	{
		clcmd_throw(id, 64, 1);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public clcmd_throw(id, vel, value)
{
	new ent;
	if(!user_has_weapon(id, CSW_SMOKEGRENADE))
		ent = ham_give_weapon(id, "weapon_smokegrenade", 1);
	else ent = fm_find_ent_by_owner(-1, "weapon_smokegrenade", id);

	g_iNadeVelocity[id][0] = vel;
	g_iNadeVelocity[id][1] = value;
	ExecuteHamB(Ham_Weapon_PrimaryAttack, ent);
	set_pdata_float(ent, m_flTimeWeaponIdle, 0.0, XO_WEAPON);
	ExecuteHam(Ham_Weapon_WeaponIdle, ent);
	strip_knife(id, K_NONE);
}

public clcmd_knife(id)
{
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		if(g_iKnifeType[id] == K_ON)
			strip_knife(id, K_TEMP);
		else if(g_iKnifeType[id] == K_TEMP)
			strip_knife(id, K_ON);
	}
}

public grenade_throw(id, ent, nade)
{
	if(nade == CSW_SMOKEGRENADE && is_user_alive(id) && g_iKnifeType[id] == K_ON)
	{
		static Float:velocity[3];
		VelocityByAim(id, g_iNadeVelocity[id][0], velocity);
		if(g_iNadeVelocity[id][1])
		{
			static Float:origin[3];
			entity_get_vector(id, EV_VEC_origin, origin);
			origin[0] += velocity[0];
			origin[1] += velocity[1];
			entity_set_origin(ent, origin);
		}

		entity_set_vector(ent, EV_VEC_velocity, velocity);
		entity_set_int(ent, EV_INT_iuser4, id);
		entity_set_float(ent, EV_FL_nextthink, get_gametime()+0.01);
		if(get_pcvar_num(cvar_knife_glow))
			UTIL_SetRendering(ent, kRenderFxGlowShell, Float:{255.0, 0.0, 0.0}, _, 50.0);

		if(entity_get_float(ent, EV_FL_dmgtime) != 0.0)
		{
			static model[TTT_MAXFILELENGHT];
			ArrayGetString(g_aKnifeModels, 2, model, charsmax(model));
			entity_set_model(ent, model);
		}
	}
}

public Think_Grenade(ent)
{
	if(!is_valid_ent(ent) || GetGrenadeType(ent) != CSW_SMOKEGRENADE || !entity_get_int(ent, EV_INT_iuser4) || ttt_get_game_state() != STARTED)
		return;

	static Float:origin[3], Float:velocity[3], Float:angles[3];
	entity_get_vector(ent, EV_VEC_origin, origin);

	if(entity_get_int(ent, EV_INT_flags) & FL_ONGROUND)
	{
		entity_set_vector(ent, EV_VEC_velocity, Float:{0.0, 0.0, 0.0});
		entity_set_size(ent, g_szDroppedSize[0], g_szDroppedSize[1]);
		entity_get_vector(ent, EV_VEC_angles, angles);

		angles[0] = 270.0;
		entity_set_vector(ent, EV_VEC_angles, angles);
		if(engfunc(EngFunc_PointContents, origin) == CONTENTS_SKY)
			give_knife(entity_get_int(ent, EV_INT_iuser4), ent);
	}
	else
	{
		entity_get_vector(ent, EV_VEC_velocity, velocity);
		vector_to_angle(velocity, angles);
		angles[0] += 270.0;
		entity_set_vector(ent, EV_VEC_angles, angles);
		origin[2]-=15.0;
	}

	if(is_valid_ent(ent))
		entity_set_float(ent, EV_FL_dmgtime, get_gametime() + 999999.0);
}

public Touch_Grenade(nade, id)
{
	if(!is_valid_ent(nade) || GetGrenadeType(nade) != CSW_SMOKEGRENADE || !entity_get_int(nade, EV_INT_iuser4) || ttt_get_game_state() != STARTED)
		return PLUGIN_CONTINUE;

	if(is_user_alive(id))
	{
		new owner = entity_get_edict(nade, EV_ENT_owner);
		if(!owner)
		{
			give_knife(id, nade);
			return PLUGIN_HANDLED;
		}
		else
		{
			if(owner == id)
				return PLUGIN_CONTINUE;

			emit_sound(id, CHAN_AUTO, "weapons/knife_hit4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			ExecuteHam(Ham_TakeDamage, id, owner, owner, 150.0, DMG_SLASH);
			entity_set_vector(nade, EV_VEC_velocity, Float:{0.0, 0.0, 0.0});
			entity_set_edict(nade, EV_ENT_owner, 0);
			drop_to_floor(nade);

			return PLUGIN_HANDLED;
		}
	}
	else
	{
		entity_set_edict(nade, EV_ENT_owner, 0);
		if(get_pcvar_num(cvar_knife_bounce))
		{
			static Float:velocity[3];
			entity_get_vector(nade, EV_VEC_velocity, velocity);
			if(velocity[2] > 0.0)
			{
				velocity[2] = -(velocity[2]/2.0);
				entity_set_vector(nade, EV_VEC_velocity, velocity);
			}

			return PLUGIN_HANDLED;
		}
		else
		{
			entity_set_vector(nade, EV_VEC_velocity, Float:{0.0, 0.0, 0.0});
			emit_sound(nade, CHAN_AUTO, "weapons/knife_hit4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
	if(is_user_connected(killer))
	{
		if(g_iKnifeType[killer])
			g_iKilledByKnife[victim] = true;
	}

	g_iKnifeType[victim] = K_NONE;
}

public Ham_PrimaryAttack_post(knife)
{	
	if(!is_valid_ent(knife))
		return;

	new id = get_pdata_cbase(knife, m_pPlayer, XO_WEAPON);
	if(is_user_connected(id) && g_iKnifeType[id] == K_ON && get_user_weapon(id) == CSW_KNIFE)
	{
		attack_post(id, knife, get_pcvar_float(cvar_pattack_rate), get_pcvar_float(cvar_pattack_recoil));
		clcmd_throw(id, get_pcvar_num(cvar_knife_velocity), 0);
	}
}

public Ham_SecondaryAttack_post(knife)
{	
	if(!is_valid_ent(knife))
		return;

	new id = get_pdata_cbase(knife, m_pPlayer, XO_WEAPON);
	if(is_user_connected(id) && g_iKnifeType[id] == K_ON)
		attack_post(id, knife, get_pcvar_float(cvar_sattack_rate), get_pcvar_float(cvar_sattack_recoil));
}

public Ham_Item_Deploy_post(knife)
{
	if(!is_valid_ent(knife))
		return;

	new id = get_pdata_cbase(knife, m_pPlayer, XO_WEAPON);
	if(is_user_alive(id) && g_iKnifeType[id] == K_ON)
	{
		static model[TTT_MAXFILELENGHT];
		ArrayGetString(g_aKnifeModels, 0, model, charsmax(model));
		entity_set_string(id, EV_SZ_viewmodel, model);
		ArrayGetString(g_aKnifeModels, 1, model, charsmax(model));
		entity_set_string(id, EV_SZ_weaponmodel, model);
		attack_post(id, knife, 0.5, 0.0);
	}
}

public Ham_Item_Deploy_Grenade_post(nade)
{
	if(!is_valid_ent(nade))
		return;

	new id = get_pdata_cbase(nade, m_pPlayer, XO_WEAPON);
	if(is_user_alive(id) && g_iKnifeType[id] == K_ON)
	{
		static model[TTT_MAXFILELENGHT];
		ArrayGetString(g_aKnifeModels, 0, model, charsmax(model));
		entity_set_string(id, EV_SZ_viewmodel, model);
		ArrayGetString(g_aKnifeModels, 1, model, charsmax(model));
		entity_set_string(id, EV_SZ_weaponmodel, model);
		attack_post(id, nade, 0.5, 0.0);
	}
}

public Ham_PrimaryAttack_Grenade_pre(nade)
{
	if(!is_valid_ent(nade))
		return;

	new id = get_pdata_cbase(nade, m_pPlayer, XO_WEAPON);
	if(is_user_alive(id) && g_iKnifeType[id] == K_ON)
	{
		set_pdata_float(nade, m_flTimeWeaponIdle, 0.0, XO_WEAPON);
		ExecuteHam(Ham_Weapon_WeaponIdle, nade);
	}
}

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage, damage_bits)
{	
	if(victim == attacker || !is_user_connected(attacker))
		return HAM_IGNORED;

	if(g_iKnifeType[attacker] == K_ON)
	{
		a_lot_of_blood(victim);
		SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmgmult));
	}

	return HAM_HANDLED;
}

public give_knife(id, knife)
{
	//pickup_weapon(id, CSW_KNIFE);
	strip_knife(id, K_ON);
	//ham_give_weapon(id, "weapon_knife");
	emit_sound(id, CHAN_WEAPON, "items/gunpickup2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	if(is_valid_ent(knife))
		remove_entity(knife);
}

public attack_post(id, knife, Float:flRate, Float:cvar)
{
	set_pdata_float(knife, m_flNextPrimaryAttack, flRate, XO_WEAPON);
	set_pdata_float(knife, m_flNextSecondaryAttack, flRate, XO_WEAPON);
	set_pdata_float(knife, m_flTimeWeaponIdle, flRate, XO_WEAPON);

	if(cvar > 0.0)
	{
		static Float:flPunchAngle[3];
		flPunchAngle[0] = cvar;

		entity_set_vector(id, EV_VEC_punchangle, flPunchAngle);
	}
}

public strip_knife(id, type)
{
	g_iKnifeType[id] = type;
	reset_user_knife(id);
}

public reset_user_knife(id)
{
	if(user_has_weapon(id, CSW_KNIFE))
		ExecuteHamB(Ham_Item_Deploy, find_ent_by_owner(-1, "weapon_knife", id));

	engclient_cmd(id, "weapon_knife");
	UTIL_PlayWeaponAnimation(id, 3);

	emessage_begin(MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), _, id);
	ewrite_byte(1);
	ewrite_byte(CSW_KNIFE);
	ewrite_byte(-1);
	emessage_end();
}

stock a_lot_of_blood(id)
{
	static iOrigin[3];
	get_user_origin(id, iOrigin);

	message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin);
	write_byte(TE_BLOODSTREAM);
	write_coord(iOrigin[0]);
	write_coord(iOrigin[1]);
	write_coord(iOrigin[2]+10);
	write_coord(random_num(-360, 360));
	write_coord(random_num(-360, 360));
	write_coord(-10);
	write_byte(70);
	write_byte(random_num(50, 100));
	message_end();

	new j;
	for(j = 0; j < 4; j++) 
	{
		message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin);
		write_byte(TE_WORLDDECAL);
		write_coord(iOrigin[0]+random_num(-100, 100));
		write_coord(iOrigin[1]+random_num(-100, 100));
		write_coord(iOrigin[2]-36);
		write_byte(random_num(190, 197));
		message_end();
	}
}

stock UTIL_PlayWeaponAnimation(const id, const seq)
{
	entity_set_int(id, EV_INT_weaponanim, seq);

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = id);
	write_byte(seq);
	write_byte(entity_get_int(id, EV_INT_body));
	message_end();
}

stock UTIL_SetRendering(ent, kRenderFx=kRenderFxNone, {Float,_}:fVecColor[3] = {0.0,0.0,0.0}, kRender=kRenderNormal, Float:flAmount=0.0)
{
	if(is_valid_ent(ent))
	{
		entity_set_int(ent, EV_INT_renderfx, kRenderFx);
		entity_set_vector(ent, EV_VEC_rendercolor, fVecColor);
		entity_set_int(ent, EV_INT_rendermode, kRender);
		entity_set_float(ent, EV_FL_renderamt, flAmount);
	}
}

stock GetGrenadeType(ent)
{
	if (get_pdata_int(ent, 96) & (1<<8))
		return CSW_C4;

	new bits = get_pdata_int(ent, 114);
	if (bits & (1<<0))
		return CSW_HEGRENADE;
	else if (bits & (1<<1))
		return CSW_SMOKEGRENADE;
	else if (!bits)
		return CSW_FLASHBANG;

	return 0;
}

public _is_knife_kill(plugin, params)
{
	new id = get_param(1);
	if(params != 1 || is_user_alive(id))
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params or user alive (ttt_is_knife_kill)");

	return g_iKilledByKnife[id];
}

public _knife_holding(plugin, params)
{
	if(params != 2)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_knife_holding)");

	new id = get_param(1);
	if(get_param(2))
		return g_iKnifeType[id] == K_TEMP ? true : false;

	return g_iKnifeType[id] == K_ON ? true : false;
}