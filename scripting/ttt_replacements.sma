#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <cstrike>
#include <ttt>
#include <amx_settings_api>
#include <cs_weapons_api>

#define LINUX_WEAPON_OFF			4
#define m_flNextPrimaryAttack		46
#define m_flNextSecondaryAttack		47

new const g_szCrowbarModel[][] = {"models/ttt/v_crowbar.mdl", "models/ttt/p_crowbar.mdl"};
new const g_szGrenadeModel[][] = {"models/ttt/v_hegrenade.mdl", "models/ttt/p_hegrenade.mdl", "models/ttt/w_hegrenade.mdl"};
new const g_szCrowbarSound[][] = {"weapons/cbar_hitbod2.wav", "weapons/cbar_hitbod1.wav", "weapons/bullet_hit2.wav",  "weapons/cbar_miss1.wav"};
new const g_szHeadShotSound[][] = {"player/headshot1.wav", "player/headshot2.wav", "player/headshot3.wav"};

new const g_szWeaponsList[][] = 
{
	"weapon_p228", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_aug",
	"weapon_elite", "weapon_fiveseven",	"weapon_ump45", "weapon_sg550", "weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18",
	"weapon_awp", "weapon_mp5navy", "weapon_m249", "weapon_m3",	"weapon_m4a1", "weapon_tmp", "weapon_g3sg1",
	"weapon_deagle", "weapon_sg552", "weapon_ak47", "weapon_knife", "weapon_p90"
};

new HamHook:g_HamPrimaryAttack[sizeof(g_szWeaponsList)], HamHook:g_HamSecondaryAttack[sizeof(g_szWeaponsList)],
	HamHook:g_HamItemDeploy[sizeof(g_szWeaponsList)];
new Array:g_aCrowbarModels, Array:g_aGrenadeModels;
new g_szPlayerModel[32];

public plugin_precache()
{
	new i, model[TTT_MAXFILELENGHT];
	g_aCrowbarModels = ArrayCreate(TTT_MAXFILELENGHT, 2);
	g_aGrenadeModels = ArrayCreate(TTT_MAXFILELENGHT, 3);

// PLAYER
	if(!amx_load_setting_string(TTT_SETTINGSFILE, "Player model", "MODEL", g_szPlayerModel, charsmax(g_szPlayerModel)))
	{
		g_szPlayerModel = "terror";
		amx_save_setting_string(TTT_SETTINGSFILE, "Player model", "MODEL", g_szPlayerModel);
	}

	formatex(model, charsmax(model), "models/player/%s/%s.mdl", g_szPlayerModel, g_szPlayerModel);
	precache_model(model);

// END

// CROWBAR
	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Crowbar", "MODEL_V", g_aCrowbarModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Crowbar", "MODEL_V", g_szCrowbarModel[0]);
		precache_model(g_szCrowbarModel[0]);
		ArrayPushString(g_aCrowbarModels, g_szCrowbarModel[0]);
	}
	else
	{
		ArrayGetString(g_aCrowbarModels, 0, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Crowbar", "MODEL_P", g_aCrowbarModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Crowbar", "MODEL_P", g_szCrowbarModel[1]);
		precache_model(g_szCrowbarModel[1]);
		ArrayPushString(g_aCrowbarModels, g_szCrowbarModel[1]);
	}
	else
	{
		ArrayGetString(g_aCrowbarModels, 1, model, charsmax(model));
		precache_model(model);
	}
// END

// GRENADE
	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Grenade", "MODEL_V", g_aGrenadeModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Grenade", "MODEL_V", g_szGrenadeModel[0]);
		precache_model(g_szGrenadeModel[0]);
		ArrayPushString(g_aGrenadeModels, g_szGrenadeModel[0]);
	}
	else
	{
		ArrayGetString(g_aGrenadeModels, 0, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Grenade", "MODEL_P", g_aGrenadeModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Grenade", "MODEL_P", g_szGrenadeModel[1]);
		precache_model(g_szGrenadeModel[1]);
		ArrayPushString(g_aGrenadeModels, g_szGrenadeModel[1]);
	}
	else
	{
		ArrayGetString(g_aGrenadeModels, 1, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "Grenade", "MODEL_W", g_aGrenadeModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "Grenade", "MODEL_W", g_szGrenadeModel[2]);
		precache_model(g_szGrenadeModel[2]);
		ArrayPushString(g_aGrenadeModels, g_szGrenadeModel[2]);
	}
	else
	{
		ArrayGetString(g_aGrenadeModels, 2, model, charsmax(model));
		precache_model(model);
	}
// END

	for(i = 0; i <= charsmax(g_szCrowbarSound); i++)
		precache_sound(g_szCrowbarSound[i]);

	for(i = 0; i <= charsmax(g_szHeadShotSound); i++)
		precache_sound(g_szHeadShotSound[i]);
}

public plugin_init()
{
	register_plugin("[TTT] Replacements", TTT_VERSION, TTT_AUTHOR);

	new const g_szBlockSet[][] =
	{
		"BombDrop",
		"BombPickup",
		"DeathMsg",
		"ScoreInfo",
		"Radar",
		"Money"
	};

	new const g_szMessageBlock[][] =
	{
		"ScoreAttrib",
		"TextMsg",
		"SendAudio",
		"Scenario",
		"StatusIcon"
	};
	new i;
	for(i = 0; i <= charsmax(g_szBlockSet); i++)
		set_msg_block(get_user_msgid(g_szBlockSet[i]), BLOCK_SET);

	for(i = 0; i <= charsmax(g_szMessageBlock); i++)
		register_message(get_user_msgid(g_szMessageBlock[i]), "Message_Block");

	register_forward(FM_EmitSound, "Forward_EmitSound_pre", 0);
	register_forward(FM_GetGameDescription, "Forward_GetGameDescription_pre", 0);

	RegisterHam(Ham_Spawn, "player", "Ham_Spawn_post", 1, true);
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Knife_Deploy_post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_hegrenade", "Ham_Knife_Deploy_post", 1);

	for(i = 0; i <= charsmax(g_szWeaponsList); i++)
	{
		DisableHamForward((g_HamPrimaryAttack[i] = RegisterHam(Ham_Weapon_PrimaryAttack, g_szWeaponsList[i], "Ham_BlockWeapon_post", 1)));
		DisableHamForward((g_HamSecondaryAttack[i] = RegisterHam(Ham_Weapon_SecondaryAttack, g_szWeaponsList[i], "Ham_BlockWeapon_post", 1)));
		DisableHamForward((g_HamItemDeploy[i] = RegisterHam(Ham_Item_Deploy, g_szWeaponsList[i], "Ham_BlockWeapon_post", 1)));
	}
}

public cswa_killed(ent, victim, killer)
{
	ttt_set_playerdata(victim, PD_KILLEDBYITEM, get_weapon_edict(ent, REPL_CSWA_ITEMID));
}

public ttt_gamemode(gamemode)
{
	if(gamemode == PREPARING)
		my_ham_hooks(true);
	else if(gamemode == STARTED || gamemode == OFF)
		my_ham_hooks(false);
}

public grenade_throw(id, ent, nade)
{
	if(nade == CSW_HEGRENADE && is_user_alive(id))
	{
		if(entity_get_float(ent, EV_FL_dmgtime) != 0.0)
		{
			static model[TTT_MAXFILELENGHT];
			if(!model[0])
				ArrayGetString(g_aGrenadeModels, 2, model, charsmax(model));
			entity_set_model(ent, model);
		}
	}
}

public Message_Block(msgid, dest, id)
{
	if(get_msg_args() > 1)
	{
		static message[128];
		if(get_msg_args() == 5)
			get_msg_arg_string(5, message, charsmax(message));

		if(equal(message, "#Fire_in_the_hole"))
			return PLUGIN_HANDLED;

		get_msg_arg_string(2, message, charsmax(message));
		if(equal(message, "%!MRAD_BOMBPL") || equal(message, "%!MRAD_BOMBDEF") || equal(message, "%!MRAD_terwin") || equal(message, "%!MRAD_ctwin") || equal(message, "%!MRAD_FIREINHOLE"))
			return PLUGIN_HANDLED;

		if(equal(message, "#Killed_Teammate") || equal(message, "#Game_teammate_kills") || equal(message, "#Game_teammate_attack") || equal(message, "#C4_Plant_At_Bomb_Spot"))
			return PLUGIN_HANDLED;

		if(equal(message, "#Bomb_Planted") || equal(message, "#Game_bomb_drop") || equal(message, "#Game_bomb_pickup") || equal(message, "#Got_bomb") || equal(message, "#C4_Plant_Must_Be_On_Ground"))
			return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public Forward_GetGameDescription_pre()
{
	forward_return(FMV_STRING, "Trouble in Terrorist Town");
	return FMRES_SUPERCEDE;
}

public Forward_EmitSound_pre(id, channel, sample[])
{
	if(!is_user_connected(id))
		return FMRES_IGNORED;

	if(equal(sample, "player/bhit_helmet-1.wav"))
	{
		emit_sound(id, CHAN_BODY, g_szHeadShotSound[random_num(0, 2)], 1.0, ATTN_NORM, 0, PITCH_NORM);
		return FMRES_SUPERCEDE;
	}

	if((equal(sample, "player/die", 10) || equal(sample, "player/death6.wav")) && !is_user_alive(id) && ttt_get_playerdata(id, PD_KILLEDBYITEM) > -1)
		return FMRES_SUPERCEDE;
	
	if(equal(sample, "weapons/knife_", 14))
	{
		new knife = ttt_knife_holding(id, 0), temp = ttt_knife_holding(id, 1);
		if(!knife && (!temp || temp))
		{
			switch(sample[17])
			{
				case('b'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[0], 1.0, ATTN_NORM, 0, PITCH_NORM);
				case('w'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[1], 1.0, ATTN_NORM, 0, PITCH_LOW);
				case('s'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[3], 1.0, ATTN_NORM, 0, PITCH_NORM);
				case('1', '2'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[2], random_float(0.5, 1.0), ATTN_NORM, 0, PITCH_NORM);
			}
			return FMRES_SUPERCEDE;
		}
	}

	return FMRES_IGNORED;
}

public Ham_Spawn_post(id)
{
	if(is_user_alive(id))
	{
		static model[20];
		cs_get_user_model(id, model, charsmax(model));

		if(!equal(model, g_szPlayerModel))
			cs_set_user_model(id, g_szPlayerModel);
	}
}

public Ham_BlockWeapon_post(const ent)
{
	new Float:time = get_roundtime()*(-1.0);
	set_pdata_float(ent, m_flNextPrimaryAttack, time, LINUX_WEAPON_OFF);
	set_pdata_float(ent, m_flNextSecondaryAttack, time, LINUX_WEAPON_OFF);
}

public Ham_Knife_Deploy_post(ent)
{
	new id = get_weapon_owner(ent);
	if(is_user_alive(id))
	{
		static model[TTT_MAXFILELENGHT];
		ArrayGetString(g_aCrowbarModels, 0, model, charsmax(model));
		entity_set_string(id, EV_SZ_viewmodel, model);
		ArrayGetString(g_aCrowbarModels, 1, model, charsmax(model));
		entity_set_string(id, EV_SZ_weaponmodel, model);
	}
}

my_ham_hooks(val)
{
	if(val)
	{
		for(new i = 0; i <= charsmax(g_szWeaponsList); i++)
		{
			EnableHamForward(g_HamPrimaryAttack[i]);
			EnableHamForward(g_HamSecondaryAttack[i]);
			EnableHamForward(g_HamItemDeploy[i]);
		}
	}
	else
	{
		for(new i = 0; i <= charsmax(g_szWeaponsList); i++)
		{
			DisableHamForward(g_HamPrimaryAttack[i]);
			DisableHamForward(g_HamSecondaryAttack[i]);
			DisableHamForward(g_HamItemDeploy[i]);
		}
	}
}