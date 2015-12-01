int g_iSelectedTarget[MAXPLAYERS+1];
int g_iPendingSlays[MAXPLAYERS+1];
bool g_bDBLoaded[MAXPLAYERS+1];

Handle SQLiteDB;
bool useDB = true;

char sQueryBuff[1024];
char sInsertQuery[] = "INSERT INTO slays (auth) VALUES (%d);";
char sUpdateQuery[] = "UPDATE slays SET amount=%d WHERE auth=%d";
char sSelectQuery[] = "SELECT amount FROM slays WHERE auth=%d;";

#include <ttt>

public void OnClientPostAdminCheck(int client){
	g_iPendingSlays[client] = 0;
	
	if(useDB && (SQLiteDB != INVALID_HANDLE)){
		g_bDBLoaded[client] = false;
		Format(sQueryBuff, sizeof(sQueryBuff), "%s", sSelectQuery, GetSteamAccountID(client));
		SQL_TQuery(SQLiteDB, GetSlays_CB, sQueryBuff, GetClientUserId(client));
	}
}

public void OnClientDisconnect(int client){
	g_iPendingSlays[client] = 0;
}

public GetSlays_CB(Handle owner, Handle hndl, const char[] error, any userid){
	int client = GetClientOfUserId(userid);
	if(TTT_IsClientValid(client)){
		if (hndl == INVALID_HANDLE || strlen(error) > 0){
			LogMessage("Failed to retrieve slayex slays from database, error: %s", error);
			return;
		}
		
		if(SQL_FetchRow(hndl)){
			g_bDBLoaded[client] = true;
			g_iPendingSlays[client] = SQL_FetchInt(hndl, 0);
			CheckSlays(client);
		}else{
			Format(sQueryBuff, sizeof(sQueryBuff), "%s", sInsertQuery, GetSteamAccountID(client));
			SQL_TQuery(SQLiteDB, InsertUser_CB, sQueryBuff, GetClientUserId(client));
		}
	}
}

public InsertUser_CB(Handle owner, Handle hndl, const char[] error, any userid){
	int client = GetClientOfUserId(userid);
	if(TTT_IsClientValid(client)){
		if (hndl == INVALID_HANDLE || strlen(error) > 0){
			LogMessage("Failed to insert slayex user into database, error: %s", error);
			return;
		}
		
		g_bDBLoaded[client] = true;
	}
}

public UpdateUser_CB(Handle owner, Handle hndl, const char[] error, any userid){
	int client = GetClientOfUserId(userid);
	if(TTT_IsClientValid(client)){
		if (hndl == INVALID_HANDLE || strlen(error) > 0){
			LogMessage("Failed to update slayex user in database, error: %s", error);
			return;
		}
	}
}

void SetupSlayExDB(){
	CreateConVar("slayex_version", SLAYEX_VERSION, "Version of Slay-Extended on server", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	char error[255];
	SQLiteDB = SQLite_UseDatabase("slayex", error, sizeof(error));
	
	if (SQLiteDB == INVALID_HANDLE)
		useDB = false;
	else{
		SQL_LockDatabase(SQLiteDB);
		SQL_FastQuery(SQLiteDB, "CREATE TABLE IF NOT EXISTS slays (auth INT PRIMARY KEY NOT NULL, amount INTEGER DEFAULT 0);");
		SQL_UnlockDatabase(SQLiteDB);
	}
}

public Action TTT_OnRoundStart_Pre(){
	for(int i=1;i<=MaxClients;i++){
		if(TTT_IsClientValid(i)){
			CheckSlays(i);
		}
	}
	
	return Plugin_Continue;
}

void CheckSlays(int client){
	if(TTT_IsClientValid(client) && g_iPendingSlays[client] > 0 && IsPlayerAlive(client)){
		g_iPendingSlays[client] -= 1;
		
		if(useDB && g_bDBLoaded[client] == true){
			Format(sQueryBuff, sizeof(sQueryBuff), "%s", sUpdateQuery, g_iPendingSlays[client], GetSteamAccountID(client));
			SQL_TQuery(SQLiteDB, UpdateUser_CB, sQueryBuff, GetClientUserId(client));
		}
		
		ForcePlayerSuicide(client);
		
		ShowActivity2(0, "[SM] ", "%t", "Pending slays left", "__n", client, g_iPendingSlays[client]);
	}
}

void PerformSlay(int client, int target, int times=1){
	g_iSelectedTarget[client] = 0;
	g_iPendingSlays[target] += times;
	
	LogAction(client, target, "[SM] ", "%t", "Marked to slay by", "__n", target, times, "__n", client);

	CheckSlays(target);
}

void DisplaySlayMenu(int client){
	g_iSelectedTarget[client] = 0;
	Menu menu = CreateMenu(MenuHandler_Slay);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Slay player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, true);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public AdminMenu_Slay(Handle topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "Slay player", param);
	else if (action == TopMenuAction_SelectOption)
		DisplaySlayMenu(param);
}

public MenuHandler_Slay(Menu menu, MenuAction action, int param1, int param2){
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != null)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			g_iSelectedTarget[param1] = userid;
			Menu menu2 = CreateMenu(MenuHandler_Slay2);
			
			menu2.SetTitle("# of times");
			menu2.ExitBackButton = true;
			
			menu2.AddItem("1", "1");
			menu2.AddItem("2", "2");
			menu2.AddItem("3", "3");
			menu2.AddItem("4", "4");
			menu2.AddItem("5", "5");
			
			menu2.Display(param1, MENU_TIME_FOREVER);
		}
	}
}

public int MenuHandler_Slay2(Menu menu, MenuAction action, int param1, int param2){
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != null)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid = g_iSelectedTarget[param1]; int target;
		int times;

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			menu.GetItem(param2, info, sizeof(info));
			times = StringToInt(info);
			
			if(times > 10)
				times = 10;
			
			PerformSlay(param1, target, times);
			ShowActivity2(param1, "[SM] ", "%t", "Marked to slay", "__n", target, times);
		}
		
		DisplaySlayMenu(param1);
	}
}

public Action Command_Slay(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_slay <#userid|name> [times]");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS]; int target_count; bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	int times = 0;
	if (args > 1){
		char arg2[20];
		GetCmdArg(2, arg2, sizeof(arg2));
		if (StringToIntEx(arg2, times) == 0 || times < 0){
			times = 1;
		}
	}else{
		times = 1;
	}
	

	for (int i = 0; i < target_count; i++){
		PerformSlay(client, target_list[i], times);
	}
	
	if (tn_is_ml)
	{
		ShowActivity2(client, "[SM] ", "%t", "Marked to slay", target_name, times);
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Marked to slay", "_s", target_name, times);
	}

	return Plugin_Handled;
}

public Action Command_SetSlays(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setslays <#userid|name> <amount>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS]; int target_count; bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	int times = 0;
	
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));
	if (StringToIntEx(arg2, times) == 0 || times < 0){
		times = 0;
	}
	

	for (int i = 0; i < target_count; i++){
		g_iPendingSlays[target_list[i]] = times;
	}
	
	if (tn_is_ml)
	{
		ShowActivity2(client, "[SM] ", "%t", "Set slays to", target_name, times);
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Set slays to", "_s", target_name, times);
	}

	return Plugin_Handled;
}