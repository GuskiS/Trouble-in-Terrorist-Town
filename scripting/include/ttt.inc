#if defined _ttt_included
	#endinput
#endif
#define _ttt_included

#include <ttt_const> 

#if AMXX_VERSION_NUM >= 175
    #pragma reqlib ttt
    #if !defined AMXMODX_NOAUTOLOAD
        #pragma loadlib ttt
    #endif
#else
    #pragma library ttt
#endif

/**
 * Gets/sets players state.
 *
 * @param id				Player index.
 * @param Special			New state, enum Special.
 * @return					Special state.
 */
native ttt_get_special_state(id);
native ttt_set_special_state(id, Special);

/**
 * Gets/sets special count.
 *
 * @param Special			Special state.
 * @param num				1(++), -1(--), 0(nulled)
 * @return					Number of specials.
 */
native ttt_get_special_count(Special);
native ttt_set_special_count(Special, num); // num = 1(++), -1(--) or 0(nulled)

/**
 * Returns roundtime.
 *
 * @return					Roundtime.
 */
native Float:get_roundtime();

/**
 * Gets/sets players data.
 *
 * @param id				Player index.
 * @param PlayerData		Enum PlayerData.
 * @param newdata			New data.
 * @return					Data.
 */
native ttt_get_playerdata(id, PlayerData);
native ttt_set_playerdata(id, PlayerData, newdata);

/**
 * Too hard to explain, don't use it.
 *
 * @param killer			Player index.
 * @param victim			Player index.
 * @param modifier			For example, KARMATEMP.
 * @param type				1 killed, 0 damage.
 * @param when				Victim alive or dead.
 */
native ttt_set_karma_modifier(killer, victim, modifier, type, when);

/**
 * Gets/sets game state.
 *
 * @param which				Sets new game state.
 * @return					Game state.
 */
native ttt_get_game_state();
native ttt_set_game_state(which);

/**
 * Gets/sets game winner. Also, ends round if still active.
 *
 * @param team				INNOCENT or TRAITOR.
 * @return					Game winner.
 */
native ttt_get_winner();
native ttt_set_winner(team);

/**
 * Returns if player's name is visible.
 *
 * @param id				Player index.
 * @return					True or false.
 */
native ttt_get_hide_name(id);

/**
 * Adds item to Buymenu and returns id.
 *
 * @param name[]			Items name.
 * @param price				Items price.
 * @param team				Items team, INNOCENT = INNO + DET, SPECIAL = TRA + DET.
 * @return					Item id.
 */
native ttt_buymenu_add(const name[], const price, const team);

/**
 * Adds item to Buymenu and returns id.
 *
 * @param item_id			Item id.
 * @param name[]			Items name.
 * @param charsmax			Items name size-1.
 * @return					name.
 */
native ttt_get_item_name(item_id, name[], charsmax);

/**
 * Adds item to Backpack and returns id.
 *
 * @param owner				Players id.
 * @param name[]			Items name.
 * @return					Item id.
 */
native ttt_backpack_add(owner, name[]);

/**
 * Remove item from Backpack.
 *
 * @param owner				Players id.
 * @param itemid[]			Item id.
 * @return					something.
 */
native ttt_backpack_remove(owner, itemid);

/**
 * Opens backpack for player.
 *
 * @param owner				Players id.
 */
native ttt_backpack_show(owner);

/**
 * Returns player's state when he was/is alive.
 *
 * @param id				Players id.
 * @return					state
 */
native ttt_get_special_alive(id);

/**
 * Gets/sets/clears players dead body data.
 *
 * @param id				Players id.
 * @param BodyData			Enum BodyData.
 * @param newdata			New data.
 * @return					Data.
 */
native ttt_get_bodydata(id, BodyData);
native ttt_set_bodydata(id, BodyData, newdata);
native ttt_clear_bodydata(id);

/**
 * Setups item from backpack that will have DNA sample left on it, for example, Death Station and returns setupid.
 *
 * @param id				Items or players (dont know) id.
 * @param ent				Entity id.
 * @param time				Time before DNA decays.
 * @param owner				DNA Sample owner.
 * @param tracer			Detective who can see DNA.
 * @param active			Is DNA seeable.
 * @param name[]			Items name.
 * @return					Setupid.
 */
native ttt_item_setup_add(id, ent, time, owner, tracer, active, name[]);

/**
 * Removes setuped item - DNA stop existing, I think.
 *
 * @param setupid			Setups id.
 */
native ttt_item_setup_remove(setupid);

/**
 * Updates/gets info about setup.
 *
 * @param setupid			Setups id.
 * @param array[]			For example, static data[SetupData].
 */
native ttt_item_setup_update(setupid, array[]);
native ttt_item_setup_get(setupid, array[]);

/**
 * Checks if selected entity is setuped for DNA tracking.
 *
 * @param ent				Entity id.
 * @return					True or false.
 */
native ttt_is_item_setup(ent);

/**
 * Returns if player has knife with condition.
 *
 * @param id				Players id.
 * @param temp				0 just checks if has been bought, 1 if is active.
 * @return 					True or false.
 */
native ttt_knife_holding(id, temp);

/**
 * Returns if DNA scanner is active - player holds it.
 *
 * @param id				Players id.
 * @return 					True or false.
 */
native ttt_is_dnas_active(id);

/**
 * Logs your message to files.
 *
 * @param type				Enum LogMessages.
 * @param msg[]				Your message.
 */
native ttt_log_to_file(type, msg[]);

/**
 * Sets/gets player stats.
 *
 * @param id				Players id.
 * @param stat				Enum Stats.
 * @param num				New value.
 * @return					Stats.
 */
native ttt_set_player_stat(id, stat, num);
native ttt_get_player_stat(id, stat);

/**
 * Register cvar to file.
 *
 * @param name[]				Cvar name.
 * @param string[]				Cvar value.
 * @return						true/false.
 */
native ttt_register_cvar(name[], string[]);

/**
 * Called when player bought item.
 *
 * @param id				Players id.
 * @param item				Item id.
 * @param name[]			Item name.
 * @param price				Item price.
 */
forward ttt_item_selected(id, item, name[], price);

/**
 * Called when player uses item from Backpack.
 *
 * @param id				Players id.
 * @param item				Item id.
 * @param name[]			Item name.
 */
forward ttt_item_backpack(id, item, name[]);

/**
 * Called when game state changes.
 *
 * @param mode				Gamestate.
 */
forward ttt_gamemode(mode);

/**
 * Called when winner is set.
 *
 * @param winner			Winner.
 */
forward ttt_winner(winner);

/**
 * Called when dead body is created.
 *
 * @param owner				Player id.
 * @param ent				Entity id.
 */
forward ttt_spawnbody(owner, ent);

#include <ttt_stocks>