/**
 * Original files -
 *	playercommands.sp (now slayex.sp) - https://raw.githubusercontent.com/alliedmodders/sourcemod/master/plugins/playercommands.sp
 *	playercommands/slay.sp (now slayex/slap.sp) - https://raw.githubusercontent.com/alliedmodders/sourcemod/master/plugins/playercommands/slay.sp
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <adminmenu>

public Plugin myinfo = {
	name = "Player Commands (Slay-Ex)",
	author = "AlliedModders LLC, whocodes",
	description = "Misc. Player Commands (Extended)",
	version = "1.0",
	url = "https://github.com/whocodes/slayex"
};

TopMenu hTopMenu;

/* Used to get the SDK / Engine version. */
#include "slayex/slay.sp"
#include "playercommands/slap.sp"
#include "playercommands/rename.sp"

public void OnPluginStart(){
	LoadTranslations("common.phrases");
	LoadTranslations("playercommands.phrases");
	LoadTranslations("slayex.phrases");

	RegAdminCmd("sm_slap", Command_Slap, ADMFLAG_SLAY, "sm_slap <#userid|name> [damage]");
	RegAdminCmd("sm_slay", Command_Slay, ADMFLAG_SLAY, "sm_slay <#userid|name> [times]");
	RegAdminCmd("sm_setslays", Command_SetSlays, ADMFLAG_SLAY, "sm_setslays <#userid|name> <amount>");
	RegAdminCmd("sm_rename", Command_Rename, ADMFLAG_SLAY, "sm_rename <#userid|name>");
	
	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)){
		OnAdminMenuReady(topmenu);
	}
}

public void OnConfigsExecuted(){
	char filename[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filename, sizeof(filename), "plugins/playercommands.smx");
	if (FileExists(filename)){
		char newfilename[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, newfilename, sizeof(newfilename), "plugins/disabled/playercommands.smx");
		ServerCommand("sm plugins unload playercommands");
		if (FileExists(newfilename))
			DeleteFile(newfilename);
		
		RenameFile(newfilename, filename);
		LogMessage("[Slay-Ex] plugins/plyercommands.smx was unloaded and moved to plugins/disabled/playercommands.smx");
	}
}

public void OnAdminMenuReady(Handle aTopMenu){
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == hTopMenu){
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Find the "Player Commands" category */
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT){
		hTopMenu.AddItem("sm_slay", AdminMenu_Slay, player_commands, "sm_slay", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_slap", AdminMenu_Slap, player_commands, "sm_slap", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_rename", AdminMenu_Rename, player_commands, "sm_rename", ADMFLAG_SLAY);
	}
}