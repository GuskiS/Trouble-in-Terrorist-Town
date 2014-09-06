#include <amxmodx>
#include <engine>
#include <cstrike>
#include <cs_weapons_api>
#include <amx_settings_api>
#include <ttt>

#define CSW_WEAPON CSW_C4
#define WEAPON_NAME "weapon_c4"

new g_iItemID;
new const g_szModels[][] = {"models/ttt/v_dnascanner.mdl", "models/ttt/p_dnascanner.mdl", "models/ttt/w_dnascanner.mdl"};
new Array:g_aModels, cvar_weapon_price, g_pMsg_StatusIcon;

public plugin_precache()
{
	new model[TTT_MAXFILELENGHT];
	g_aModels = ArrayCreate(TTT_MAXFILELENGHT, 3);

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "DNA Scanner", "MODEL_V", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "DNA Scanner", "MODEL_V", g_szModels[0]);
		precache_model(g_szModels[0]);
		ArrayPushString(g_aModels, g_szModels[0]);
	}
	else
	{
		ArrayGetString(g_aModels, 0, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "DNA Scanner", "MODEL_P", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "DNA Scanner", "MODEL_P", g_szModels[1]);
		precache_model(g_szModels[1]);
		ArrayPushString(g_aModels, g_szModels[1]);
	}
	else
	{
		ArrayGetString(g_aModels, 1, model, charsmax(model));
		precache_model(model);
	}

	if(!amx_load_setting_string_arr(TTT_SETTINGSFILE, "DNA Scanner", "MODEL_W", g_aModels))
	{
		amx_save_setting_string(TTT_SETTINGSFILE, "DNA Scanner", "MODEL_W", g_szModels[2]);
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
	register_plugin("[TTT] Item: DNA Scanner", TTT_VERSION, TTT_AUTHOR);

	cvar_weapon_price = my_register_cvar("ttt_price_dna", "1");
	g_pMsg_StatusIcon = get_user_msgid("StatusIcon");

	new name[TTT_ITEMNAME];
	formatex(name, charsmax(name), "%L", LANG_PLAYER, "TTT_ITEM_ID5");
	g_iItemID = ttt_buymenu_add(name, get_pcvar_num(cvar_weapon_price), DETECTIVE);
}

public plugin_natives()
{
	register_library("ttt");
	register_native("ttt_is_dnas_active", "_is_dnas_active");
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
			data[STRUCT_CSWA_CLIP] = -1;
			data[STRUCT_CSWA_MAXCLIP] = -1;
			data[STRUCT_CSWA_AMMO] = -1;
			data[STRUCT_CSWA_STACKABLE] = -1;
			data[STRUCT_CSWA_SILENCED] = -1;
			data[STRUCT_CSWA_SPEEDDELAY] = _:-1.0;
			data[STRUCT_CSWA_DAMAGE] = _:-1.0;
			data[STRUCT_CSWA_RELOADTIME] = _:0.0;
			ArrayGetString(g_aModels, 0, data[STRUCT_CSWA_MODEL_V], charsmax(data[STRUCT_CSWA_MODEL_V]));
			ArrayGetString(g_aModels, 1, data[STRUCT_CSWA_MODEL_P], charsmax(data[STRUCT_CSWA_MODEL_P]));
			ArrayGetString(g_aModels, 2, data[STRUCT_CSWA_MODEL_W], charsmax(data[STRUCT_CSWA_MODEL_W]));
		}
		cswa_give_specific(id, data);

		set_dna(id);
		client_print_color(id, print_team_default, "%s %L", TTT_TAG, id, "TTT_ITEM2", name, id, "TTT_ITEM5");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public Event_WeapPickup(id)
{
	if(read_data(1) == CSW_WEAPON)
	{
		new ent = find_ent_by_owner(-1, WEAPON_NAME, id);
		if(get_weapon_edict(ent, REPL_CSWA_SET) == 2 && get_weapon_edict(ent, REPL_CSWA_ITEMID) == g_iItemID)
			set_dna(id);
	}
}

stock set_dna(id)
{
	cs_set_user_plant(id, 0);
	cs_set_user_submodel(id, 0);

	message_begin(MSG_ONE, g_pMsg_StatusIcon, _, id);
	write_byte(0);
	write_string("c4");
	message_end();
}

// API
public _is_dnas_active(plugin, params)
{
	if(params != 1)
		return ttt_log_to_file(LOG_ERROR, "Wrong number of params (ttt_is_dnas_active)") -1;

	new id = get_param(1);
	if(get_user_weapon(id) == CSW_WEAPON)
	{
		new ent = find_ent_by_owner(-1, WEAPON_NAME, id);
		if(get_weapon_edict(ent, REPL_CSWA_SET) == 2 && get_weapon_edict(ent, REPL_CSWA_ITEMID) == g_iItemID)
			return 1;
	}

	return 0;
}