#if defined _ttt_stocks_included
  #endinput
#endif
#define _ttt_stocks_included

#if !defined _ttt_included
	#include <ttt>
#endif

stock const death_messages[][] =
{
	"TTT_KILL_SUICIDE",
	"TTT_KILL_GENERIC",
	"TTT_KILL_SLASH",
	"TTT_KILL_BURN",
	"TTT_KILL_FREEZE",
	"TTT_KILL_FALL",
	"TTT_KILL_BLAST",
	"TTT_KILL_SHOCK",
	"TTT_KILL_DROWN",
	"TTT_KILL_NERVEGAS",
	"TTT_KILL_POISON",
	"TTT_KILL_RADIATION",
	"TTT_KILL_ACID"
};

stock const special_names[][] =
{
	"TTT_NONE",
	"TTT_TRAITOR",
	"TTT_DETECTIVE",
	"TTT_INNOCENT",
	"TTT_DEAD",
	"TTT_SPECIAL"
};

stock is_dead_body(classname[])
{
	if(equal(classname, TTT_DEADBODY))
		return 1;
	return 0;
}

stock ttt_return_check(id)
{
	new game = ttt_get_game_state();
	if(!is_user_connected(id) || game == OFF || game == ENDED)
		return 1;

	return 0;
}

stock ttt_set_stats(id, stat, num)
{
	static pointer;
	if(!pointer)
		pointer = get_cvar_pointer("ttt_stats");

	if(pointer && get_pcvar_num(pointer))
		ttt_set_player_stat(id, stat, num);
}

stock auto_exec_config(const szName[])
{
	new szFileName[32];
	new iLen = copy(szFileName, charsmax(szFileName), szName);
	if(iLen <= 4 || !equal(szFileName[iLen-4], ".cfg"))
		add(szFileName, charsmax(szFileName), ".cfg");

	new szConfigPath[96];
	get_localinfo("amxx_configsdir", szConfigPath, charsmax(szConfigPath));
	format(szConfigPath, charsmax(szConfigPath), "%s/%s", szConfigPath, szFileName);

	if(file_exists(szConfigPath))
	{
		server_cmd("exec %s", szConfigPath);
		server_exec();
		return 1;
	}

	return 0;
}

stock create_icon_origin(id, Float:origin[3], sprite, scale) // By sontung0
{
	if(!is_in_viewcone(id, origin))
		return;

	new Float:fMyOrigin[3];
	entity_get_vector(id, EV_VEC_origin, fMyOrigin);

	new Float:fMiddle[3], Float:fHitPoint[3];
	xs_vec_sub(origin, fMyOrigin, fMiddle);
	trace_line(-1, fMyOrigin, origin, fHitPoint);

	new Float:fWallOffset[3], Float:fDistanceToWall;
	fDistanceToWall = vector_distance(fMyOrigin, fHitPoint) - 10.0;
	normalize(fMiddle, fWallOffset, fDistanceToWall);

	new Float:fSpriteOffset[3];
	xs_vec_add(fWallOffset, fMyOrigin, fSpriteOffset);

	te_sprite(id, fSpriteOffset, sprite, scale);
}

stock te_sprite(id, Float:origin[3], sprite, scale) // By sontung0
{	
	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id);
	write_byte(TE_SPRITE);
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2]));
	write_short(sprite);
	write_byte(scale);
	write_byte(255);
	message_end();
}

stock normalize(Float:fIn[3], Float:fOut[3], Float:fMul) // By sontung0
{
	new Float:fLen = xs_vec_len(fIn);
	xs_vec_copy(fIn, fOut);
	
	fOut[0] /= fLen, fOut[1] /= fLen, fOut[2] /= fLen;
	fOut[0] *= fMul, fOut[1] *= fMul, fOut[2] *= fMul;
}

stock ttt_is_jailmap()
{
	static mapname[32];
	get_mapname(mapname, charsmax(mapname));

	if(equali(mapname, "jail_", 5) || equali(mapname, "jb_", 3) || equali(mapname, "jailbreak_", 10))
		return 1;

	return 0;
}

stock ttt_make_deathmsg(killer, victim, headshot, const weapon[], flags)
{
	if(!is_user_connected(victim) || !is_user_connected(killer))
		return;

	static const cvar_state[] =
	{
		(1<<0),	// a = NONE,
		(1<<1),	// b = TRAITOR,
		(1<<2),	// c = DETECTIVE,
		(1<<3),	// d = INNOCENT,
		(1<<4),	// e = DEAD,
		(1<<5),	// f = SPECIAL,
		(1<<6),	// g = show victim
		(1<<7)	// h = show killer
	};

	static const size = Special+2;
	new show[Special+2];
	for(new i; i < size; i++)
	{
		if(flags & cvar_state[i])
			show[i] = i;
	}
	
	static msg;
	if(!msg)
		msg = get_user_msgid("DeathMsg");

	static players[32];
	new i, j, should, specstate, num;
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		i = players[num];
		specstate = ttt_get_special_state(i);
		
		should = false;
		if(i == victim && show[Special])
			should = true;
		else if(i == killer && show[Special+1])
			should = true;
		else
		{
			for(j = 0; j < Special; j++)
			{
				if(specstate == show[j])
				{
					should = true;
					break;
				}
			}
		}

		if(should)
		{
			message_begin(MSG_ONE_UNRELIABLE, msg, _, i);
			write_byte(killer);
			write_byte(victim);
			write_byte(headshot);
			write_string(weapon);
			message_end();
		}
	}	
}

stock ttt_get_kill_message(victim, killer, message[], len, type=0)
{
	if(!is_user_alive(victim))
	{
		static const weapon_names[][] = 
		{
			"suicide", "p228", "", "scout", "hegrenade", "xm1014", "c4", "mac10", "aug", "hegrenade", "elite", "fiveseven",
			"ump45", "sg550", "galil", "famas", "usp", "glock18", "awp", "mp5navy", "m249", "m3", "m4a1", "tmp", "g3sg1", "hegrenade",
			"deagle", "sg552", "ak47", "crowbar", "p90"
		};

		static weapmsg[32];
		new item_id = ttt_get_playerdata(victim, PD_KILLEDBYITEM);
		if(item_id > -1)
			ttt_get_item_name(item_id, weapmsg, charsmax(weapmsg));
		else
		{
			//killer = ttt_get_playerdata(victim, KILLEDBY);
			new weap = ttt_get_playerdata(victim, PD_KILLEDWEAP);
			if(weap >= 3000)
				formatex(weapmsg, charsmax(weapmsg), "%L", LANG_PLAYER, death_messages[weap-3000]);
			else formatex(weapmsg, charsmax(weapmsg), "%s", weapon_names[weap]);
		}

		if(type)
		{
			if(is_user_connected(killer))
			{
				static name[32];
				get_user_name(killer, name, charsmax(name));
				formatex(message, len, "[%L] %s with %s", LANG_PLAYER, special_names[ttt_get_special_alive(killer)], name, weapmsg);
			}
			else formatex(message, len, "%s", weapmsg);
		}
		else formatex(message, len, "%s", weapmsg);

		return 1;
	}

	return 0;
}

stock get_dat_deadbody(ent, Float:startOrigin[3], Float:endOrigin[3])
{
	if(!is_valid_ent(ent))
		return false;

	xs_vec_sub(endOrigin, startOrigin, endOrigin);
	xs_vec_mul_scalar(endOrigin, 10.0, endOrigin);
	xs_vec_add(startOrigin, endOrigin, endOrigin);
	engfunc(EngFunc_TraceModel, startOrigin, endOrigin, HULL_POINT, ent, 0);
	if(get_tr2(0, TR_pHit) == ent)
		return true;

	return false;
}

stock set_attrib_all(id, msg)
{
	if(!is_user_connected(id))
		return;

	static g_Msg_ScoreAttrib;
	if(!g_Msg_ScoreAttrib)
		g_Msg_ScoreAttrib = get_user_msgid("ScoreAttrib");

	message_begin(MSG_BROADCAST, g_Msg_ScoreAttrib);
	write_byte(id);
	write_byte(msg);
	message_end();
}

stock set_attrib_special(id, msg, special1, special2=-1, special3=-1, special4=-1)
{
	if(!is_user_connected(id))
		return;

	static g_Msg_ScoreAttrib;
	if(!g_Msg_ScoreAttrib)
		g_Msg_ScoreAttrib = get_user_msgid("ScoreAttrib");

	new num, i, specstate;
	static players[32];
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		i = players[num];
		specstate = ttt_get_special_state(i);
		if(specstate == special1 || specstate == special2 || specstate == special3 || specstate == special4)
		{
			message_begin(MSG_ONE_UNRELIABLE, g_Msg_ScoreAttrib, _, i);
			write_byte(id);
			write_byte(msg);
			message_end();
		}
	}
}

stock move_grenade()
{
	new ent = -1;
	while((ent = find_ent_by_class(ent, "grenade")))
		entity_set_origin(ent, Float:{-8191.0, -8191.0, -8191.0});

	return 1;
}

stock my_register_cvar(name[], string[], flags = 0, Float:fvalue = 0.0)
{
	ttt_register_cvar(name, string);
	return register_cvar(name, string, flags, fvalue);
}

stock get_weapon_owner(ent)
	return get_pdata_cbase(ent, 41, 4);

stock strip_weapons(id)
{
	if(!is_user_alive(id))
		return;

	static const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|
		(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90);
	static const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE);
	static const GRENADES_WEAPONS_BIT_SUM = (1<<CSW_HEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_C4);
	new weapons[32], num_weapons, index, weaponid;
	get_user_weapons(id, weapons, num_weapons);

	static wname[32];
	for (index = 0; index < num_weapons; index++)
	{
		weaponid = weapons[index];
		
		if(((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM) || ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM) || ((1<<weaponid) & GRENADES_WEAPONS_BIT_SUM))
		{
			get_weaponname(weaponid, wname, charsmax(wname));

			ham_strip_weapon(id, wname);
			cs_set_user_bpammo(id, weaponid, 0);
		}
	}

	set_pdata_float(id, 116, 0.0); // m_fHasPrimary
	remove_user_shield(id);
}

stock ham_strip_weapon(index, const weapon[])
{
	if(!is_user_alive(index))
		return false;

	new weaponid = get_weaponid(weapon);
	if(!weaponid)
		return false;

	new weapon_ent = fm_find_ent_by_owner(-1, weapon, index);
	if (!weapon_ent)
		return false;

	new current_weapon_ent = fm_cs_get_current_weapon_ent(index);
	new current_weapon = pev_valid(current_weapon_ent) ? cs_get_weapon_id(current_weapon_ent) : -1;
	if(current_weapon == weaponid)
		ExecuteHamB(Ham_Weapon_RetireWeapon, weapon_ent);

	if (!ExecuteHamB(Ham_RemovePlayerItem, index, weapon_ent))
		return false;

	user_has_weapon(index, weaponid, 0);
	ExecuteHamB(Ham_Item_Kill, weapon_ent);
	remove_user_shield(index);
	//set_pev(index, pev_weapons, pev(index, pev_weapons) & ~(1<<weaponid));

	return true;
}

stock ham_give_weapon(id, weapon[], val = 0)
{
	if(!is_user_alive(id))
		return false;

	if(!equal(weapon, "weapon_",7)) return 0;

	new wEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, weapon));
	if(!pev_valid(wEnt)) return 0;

	set_pev(wEnt, pev_spawnflags, SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn, wEnt);

	if(!ExecuteHamB(Ham_AddPlayerItem, id, wEnt))
	{
		if(pev_valid(wEnt)) set_pev(wEnt, pev_flags, pev(wEnt, pev_flags) | FL_KILLME);
		return 0;
	}

	ExecuteHamB(Ham_Item_AttachToPlayer, wEnt, id);
	if(val && !is_user_bot(id))
		//ExecuteHamB(Ham_Item_Deploy, fm_find_ent_by_owner(-1, weapon, id));
		show_weapon(id, weapon);

	return wEnt;
}

stock show_weapon(id, weapon[])
{
	static msg;
	if(!msg)
		msg = get_user_msgid("CurWeapon");

	new weaponid = get_weaponid(weapon);
	if(user_has_weapon(id, weaponid))
		ExecuteHamB(Ham_Item_Deploy, fm_find_ent_by_owner(-1, weapon, id));

	engclient_cmd(id, weapon);

	emessage_begin(MSG_ONE_UNRELIABLE, msg, _, id);
	ewrite_byte(1);
	ewrite_byte(weaponid);
	ewrite_byte(-1);
	emessage_end();
}

stock fm_find_ent_by_owner(entity, const classname[], owner)
{
	while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) && pev(entity, pev_owner) != owner) { /* keep looping */ }
	return entity;
}

stock fm_find_ent_by_class(entity, const classname[])
	return engfunc(EngFunc_FindEntityByString, entity, "classname", classname);

stock fm_cs_get_current_weapon_ent(id)
{
	if(pev_valid(id) != 2)
		return -1;

	return get_pdata_cbase(id, 373);
}

stock remove_user_shield(id)
{
    if(get_pdata_bool(id, 2043))								//m_bHasShield
    {
        set_pdata_bool(id, 2043, false);						//m_bHasShield
        set_pdata_int(id, 116, 0);								// m_fHasPrimary
        set_pdata_bool(id, 2042, false);						// m_bUsesShield
        set_pev(id, pev_gamestate, 1);
        new iHideHUD = get_pdata_int(id, 361);					// m_iHideHUD
        if(iHideHUD & (1<<7))
            set_pdata_int(id, 361, iHideHUD & ~(1<<7));	// m_iHideHUD

        return 1;
    }

    return -id;
}