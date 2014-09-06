#include <amxmodx>
#include <ttt>

new g_iRules[33];
new Array:g_aFilePath, Array:g_aFileName;
public plugin_init()
{
	register_plugin("[TTT] Rules", TTT_VERSION, TTT_AUTHOR);
	register_clcmd("say /rules", "ttt_rules_show");
	register_clcmd("say_team /rules", "ttt_rules_show");
	register_clcmd("say /help", "ttt_rules_show");
	register_clcmd("say_team /help", "ttt_rules_show");
	g_aFilePath = ArrayCreate(64, 3);
	g_aFileName = ArrayCreate(20, 3);

	static directory[40];
	get_localinfo("amxx_configsdir", directory, charsmax(directory));
	formatex(directory, charsmax(directory), "%s/rules_ttt", directory);

	static filename[32];
	new handle = open_dir(directory, filename, charsmax(filename));
	if(!handle)
		return;

	static line[96], len, left[48], right[48];
	do
	{
		if(strlen(filename) > 3)
		{
			formatex(line, charsmax(line), "%s/%s", directory, filename);
			ArrayPushString(g_aFilePath, line);
			read_file(line, 0, line, charsmax(line), len);
			
			strtok(line, left, charsmax(left), right, charsmax(right), ''');
			strtok(right, left, charsmax(left), right, charsmax(right), ''');
			ArrayPushString(g_aFileName, left);
		}
	}   
	while(next_file(handle, filename, charsmax(filename)));
	close_dir(handle);
}

public client_putinserver(id)
{
	static out[2];
	get_user_info(id, "_ttt_rules", out, charsmax(out));
	g_iRules[id] = str_to_num(out);

	if(!g_iRules[id])
		set_task(10.0, "ttt_rules_show", id);
}

public ttt_rules_show(id)
{
	new menu = menu_create("\rRules", "ttt_rules_handler");

	static data[5], option[20];
	for(new i = 0; i < ArraySize(g_aFileName); i++)
	{
		ArrayGetString(g_aFileName, i, option, charsmax(option));
		num_to_str(i, data, charsmax(data));
		menu_additem(menu, option, data, 0);
	}

	menu_addblank(menu, 0);

	if(g_iRules[id])
		menu_additem(menu, "RULES [HIDE]", "1000", 0);
	else menu_additem(menu, "RULES [SHOW]", "1000", 0);

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_NOCOLORS, 1);

	menu_display(id, menu, 0);

	return PLUGIN_HANDLED;
}

public ttt_rules_handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	static command[6], name[64], access, callback;
	menu_item_getinfo(menu, item, access, command, charsmax(command), name, charsmax(name), callback);
	menu_destroy(menu);

	new num = str_to_num(command);
	static option[20], path[64];
	if(num < 1000)
	{
		ArrayGetString(g_aFileName, num, option, charsmax(option));
		ArrayGetString(g_aFilePath, num, path, charsmax(path));
		show_motd(id, path, option);
	}
	else
	{
		g_iRules[id] = !g_iRules[id];
		client_cmd(id, "setinfo _ttt_rules %d", g_iRules[id]);
		ttt_rules_show(id);
	}

	return PLUGIN_HANDLED;
}