#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <ttt>

new g_iSpecialTalking[33][Special], g_Msg_TeamInfo;

public plugin_init()
{
	register_plugin("[TTT] Voice", TTT_VERSION, TTT_AUTHOR);

	RegisterHam(Ham_Killed, "player", "Ham_Killed_post", 1, true);
	register_forward(FM_Voice_SetClientListening, "Forward_SetClientListening_pre", 0);

	register_clcmd("+specialvoice", "cmd_voiceon");
	register_clcmd("-specialvoice", "cmd_voiceoff");

	g_Msg_TeamInfo = get_user_msgid("TeamInfo");
}

public ttt_gamemode(gamemode)
{
	if(gamemode == PREPARING || gamemode == RESTARTING)
	{
		new num, id;
		static players[32];
		get_players(players, num);
		for(--num; num >= 0; num--)
		{
			id = players[num];
			g_iSpecialTalking[id][TRAITOR] = false;
			g_iSpecialTalking[id][DETECTIVE] = false;
		}
	}
}


public Ham_Killed_post(victim, killer, shouldgib)
{
	if(ttt_return_check(victim))
		return HAM_IGNORED;

	g_iSpecialTalking[victim][TRAITOR] = false;
	g_iSpecialTalking[victim][DETECTIVE] = false;
	
	return HAM_HANDLED;
}

public Forward_SetClientListening_pre(receiver, sender, bool:listen)
{
	if(!is_user_connected(receiver) || !is_user_connected(sender) || sender == receiver)
		return FMRES_SUPERCEDE;

	if(get_speak(sender) == SPEAK_MUTED)
	{
		engfunc(EngFunc_SetClientListening, receiver, sender, false);
		return FMRES_SUPERCEDE;
	}

	new restate = ttt_get_special_state(receiver), sestate = ttt_get_special_state(sender);
	switch(is_user_alive(sender))
	{
		case 1: // ALIVE
		{
			if(is_user_alive(receiver))
			{
				if(g_iSpecialTalking[sender][sestate])
				{
					if(sestate == restate)
						listen = true;
					else listen = false;
				}
				else listen = true;
			}
			else listen = true;
		}
		case 0: // NOT ALIVE
		{
			if(is_user_alive(receiver))
				listen = false;
			else listen = true;
		}
	}
	
	engfunc(EngFunc_SetClientListening, receiver, sender, listen);
	return FMRES_SUPERCEDE;
}

public cmd_voiceon(id)
{
	new getstate = ttt_get_special_state(id);
	if(getstate == TRAITOR || getstate == DETECTIVE)
	{
		client_cmd(id, "+voicerecord");
		g_iSpecialTalking[id][getstate] = true;
		voice_check(id, 0, getstate);
	}

	return PLUGIN_HANDLED;
}

public cmd_voiceoff(id)
{
	new getstate = ttt_get_special_state(id);
	if(getstate == TRAITOR || getstate == DETECTIVE)
	{
		client_cmd(id, "-voicerecord");
		g_iSpecialTalking[id][getstate] = false;
		voice_check(id, 1, getstate);
	}

	return PLUGIN_HANDLED;
}

stock voice_check(id, type, getstate)
{
	new num, i;
	static players[32];
	get_players(players, num);
	for(--num; num >= 0; num--)
	{
		i = players[num];
		//if(id == i) continue;
		if(getstate == ttt_get_special_state(i))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_Msg_TeamInfo, _, i);
			write_byte(id);
			if(!type)
				write_string("SPECTATOR");
			else write_string("CT");
			message_end();
		}
	}
}