#if defined _cswa_stocks_included
  #endinput
#endif
#define _cswa_stocks_included

#if !defined _cswa_included
	#include <cs_weapons_api>
#endif

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
	if(is_user_bot(id))
		return;

	if(user_has_weapon(id, get_weaponid(weapon)))
		ExecuteHamB(Ham_Item_Deploy, fm_find_ent_by_owner(-1, weapon, id));

	engclient_cmd(id, weapon);
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

stock no_ammo_weapon(weapon_id)
{
	if(weapon_id == CSW_KNIFE || weapon_id == CSW_HEGRENADE || weapon_id == CSW_SMOKEGRENADE || weapon_id == CSW_FLASHBANG
	|| weapon_id == CSW_C4)
		return 1;

	return 0;
}

stock get_weapon_owner(ent)
	return get_pdata_cbase(ent, 41, 4);

stock slot_filled(id, slot)
	return get_pdata_cbase(id, 367+slot) > 0;

stock check_player_slot(id, weapon_ent)
{
	new slot = ExecuteHam(Ham_Item_ItemSlot, weapon_ent);
	if(slot_filled(id, slot) && !user_has_weapon(id, cs_get_weapon_id(weapon_ent)))
		return 1;

	return 0;
}