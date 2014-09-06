#include <amxmodx>
#include <ttt_const>

public plugin_init()
{
	register_plugin("[TTT] Disable Minmodels", TTT_VERSION, TTT_AUTHOR);
}

public client_disconnect(id)
{
	if(task_exists(id))
		remove_task(id);
}

public client_putinserver(id)
{
	if(!is_user_bot(id) && !is_user_hltv(id))
		set_task(5.0, "query_him", id);
}

public query_him(id)
	if(is_user_connected(id))
		query_client_cvar(id, "cl_minmodels", "Query_Results");

public Query_Results(id, const cvar[], const val[])
{
	if(floatstr(val) == 1.0)
		server_cmd( "kick #%i %s", get_user_userid(id), "Stop using cl_minmodels 1!");
	if(!task_exists(id))
		set_task(2.0, "query_him", id, _, _, "b");
}