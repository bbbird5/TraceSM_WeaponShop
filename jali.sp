#include <sourcemod>
#include <sdktools>
#include <sdktools_sound>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>

#pragma semicolon 1

new bool:g_Fly[MAXPLAYERS+1] = {false, ...};
new bool:g_Godmode[MAXPLAYERS+1] = {false, ...};
new bool:g_AmmoInfi[MAXPLAYERS+1] = {false, ...};


#define VERSION "1.2 public version"

new g_iCredits[MAXPLAYERS+1];


new Handle:cvarCreditsMax = INVALID_HANDLE;
new Handle:cvarCreditsKill = INVALID_HANDLE;
new Handle:cvarCreditsSave = INVALID_HANDLE;

new activeOffset = -1;
new clip1Offset = -1;
new clip2Offset = -1;
new secAmmoTypeOffset = -1;
new priAmmoTypeOffset = -1;

new Handle:cvarInterval;
new Handle:AmmoTimer;


new Handle:c_GameCredits = INVALID_HANDLE;


public Plugin:myinfo =
{
    name = "SM Franug Jail Awards",
    author = "Franc1sco steam: franug",
    description = "For buy awards in jail",
    version = VERSION,
    url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{

    LoadTranslations("common.phrases");

    c_GameCredits = RegClientCookie("Credits", "Credits", CookieAccess_Private);
    
    // ======================================================================
    
    HookEvent("player_spawn", PlayerSpawn);
    HookEvent("player_death", PlayerDeath);
    //HookEvent("player_hurt", Event_hurt);
    //HookEvent("player_jump", PlayerJump);
    
    // ======================================================================
    
    RegConsoleCmd("sm_shop", DOMenu);
    RegConsoleCmd("sm_credits", VerCreditos);
    RegConsoleCmd("sm_revive", Resucitar);
    RegConsoleCmd("sm_medic", Curarse);

    RegAdminCmd("sm_setcredits", FijarCreditos, ADMFLAG_ROOT);
    
    // ======================================================================
    
    // ======================================================================
    
    cvarCreditsMax = CreateConVar("awards_credits_max", "100", "max of credits allowed (0: No limit)");
    cvarCreditsKill = CreateConVar("awards_credits_kill", "1", "credits for kill");
    cvarCreditsSave = CreateConVar("awards_credits_save", "1", "enable or disable that credits can be saved");
    

    // unlimited ammo by http://forums.alliedmods.net/showthread.php?t=107900
    cvarInterval = CreateConVar("ammo_interval", "5", "How often to reset ammo (in seconds).", _, true, 1.0);

    activeOffset = FindSendPropOffs("CAI_BaseNPC", "m_hActiveWeapon");
    CreateConVar("sm_jailawards_version", VERSION, "plugin info", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
    clip1Offset = FindSendPropOffs("CBaseCombatWeapon", "m_iClip1");
    clip2Offset = FindSendPropOffs("CBaseCombatWeapon", "m_iClip2");
	
    priAmmoTypeOffset = FindSendPropOffs("CBaseCombatWeapon", "m_iPrimaryAmmoCount");
    secAmmoTypeOffset = FindSendPropOffs("CBaseCombatWeapon", "m_iSecondaryAmmoCount");
	

    if(GetConVarBool(cvarCreditsSave))
    	for(new client = 1; client <= MaxClients; client++)
    	{
		if(IsClientInGame(client))
		{
			if(AreClientCookiesCached(client))
			{
				OnClientCookiesCached(client);
			}
		}
   	}
}

public OnPluginEnd()
{
	if(!GetConVarBool(cvarCreditsSave))
		return;

	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientDisconnect(client);
		}
	}
}

public OnClientCookiesCached(client)
{
	if(!GetConVarBool(cvarCreditsSave))
		return;

	new String:CreditsString[12];
	GetClientCookie(client, c_GameCredits, CreditsString, sizeof(CreditsString));
	g_iCredits[client]  = StringToInt(CreditsString);
}

public OnClientDisconnect(client)
{
	if(!GetConVarBool(cvarCreditsSave))
	{
		g_iCredits[client] = 0;
		return;
	}

	if(AreClientCookiesCached(client))
	{
		new String:CreditsString[12];
		Format(CreditsString, sizeof(CreditsString), "%i", g_iCredits[client]);
		SetClientCookie(client, c_GameCredits, CreditsString);
	}
}

public OnConfigsExecuted()
{


	PrecacheModel("models/props/de_train/barrel.mdl");

	PrecacheModel("models/pigeon.mdl");

	PrecacheModel("models/crow.mdl");


	if (AmmoTimer != INVALID_HANDLE) {
		KillTimer(AmmoTimer);
	}
	new Float:interval = GetConVarFloat(cvarInterval);
	AmmoTimer = CreateTimer(interval, ResetAmmo, _, TIMER_REPEAT);
}


public Action:MensajesSpawn(Handle:timer, any:client)
{
 if (IsClientInGame(client))
 {
   PrintToChat(client, "\x04[武器商店] \x05击杀僵尸获得点数");
   PrintToChat(client, "\x04[武器商店] \x05输入 \x03!shop \x05来召唤武器商店");
 }
}

public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    CreateTimer(2.0, MensajesMuerte, client);
    
    if (!attacker)
        return;

    if (attacker == client)
        return;
    
    g_iCredits[attacker] += GetConVarInt(cvarCreditsKill);
    
    if (g_iCredits[attacker] < GetConVarInt(cvarCreditsMax))
    {
        PrintToChat(attacker, "\x04[武器商店] \x05你的点数为: %i (+%i)", g_iCredits[attacker],GetConVarInt(cvarCreditsKill));
    }
    else
    {
        g_iCredits[attacker] = GetConVarInt(cvarCreditsMax);
        PrintToChat(attacker, "\x04[武器商店] \x05你的点数为: %i (Maximum allowed)", g_iCredits[attacker]);
    }
}

public Action:MensajesMuerte(Handle:timer, any:client)
{
 if (IsClientInGame(client))
 {
   PrintToChat(client, "\x04[武器商店] \x05你死了, 你现在可以使用 \x03!revive \x05 来复活 (4 credits required)");
 }
}

public Action:VerCreditos(client, args)
{
	if(client == 0)
	{
		PrintToServer("%t","Command is in-game only");
		return;
	}
        PrintToChat(client, "\x04[武器商店] \x05你现在的点数为: %i", g_iCredits[client]);
}

public Action:DOMenu(client,args)
{
	if(client == 0)
	{
		PrintToServer("%t","Command is in-game only");
		return;
	}
    	DID(client);
   	PrintToChat(client, "\x04[武器商店] \x05你的点数为: %i", g_iCredits[client]);
}

public Action:Resucitar(client,args)
{
	if(client == 0)
	{
		PrintToServer("%t","Command is in-game only");
		return;
	}

	if (!IsPlayerAlive(client))
        {
              if (g_iCredits[client] >= 4)
              {

                      CS_RespawnPlayer(client);

                      g_iCredits[client] -= 4;

                      decl String:nombre[32];
                      GetClientName(client, nombre, sizeof(nombre));

                      PrintToChatAll("\x04[SM_JailAwards] \x05The player\x03 %s \x05has revived!", nombre);
                      PrintCenterTextAll("The player %s has revived!", nombre);

              }
              else
              {
                 PrintToChat(client, "\x04[SM_JailAwards] \x05Your credits: %i (Not have enough credit to revive! Need 4)", g_iCredits[client]);
              }
        }
        else
        {
            PrintToChat(client, "\x04[SM_JailAwards] \x05Must be dead to use!");
        }
}

public Action:Curarse(client,args)
{
	if(client == 0)
	{
		PrintToServer("%t","Command is in-game only");
		return;
	}

	if (IsPlayerAlive(client))
        {
              if (g_iCredits[client] >= 1)
              {

                      SetEntityHealth(client, 100);

                      g_iCredits[client] -= 1;

                      //EmitSoundToAll("medicsound/medic.wav");


                      decl String:nombre[32];
                      GetClientName(client, nombre, sizeof(nombre));

                      PrintToChatAll("\x04[SM_JailAwards] \x05The player\x03 %s \x05has healed!", nombre);

                      PrintToChat(client, "\x04[SM_JailAwards] \x05You are cured. Your credits: %i (-1)", g_iCredits[client]);

              }
              else
              {
                 PrintToChat(client, "\x04[SM_JailAwards] \x05Your credits: %i (Not have enough credit to revive! Need 1)", g_iCredits[client]);
              }
        }
        else
        {
            PrintToChat(client, "\x04[SM_JailAwards] \x05But if you're dead...!!");
        }
}

public Action:DID(clientId) 
{
    new Handle:menu = CreateMenu(DIDMenuHandler);
    SetMenuTitle(menu, "武器商店. 你的点数为: %i", g_iCredits[clientId]);
    AddMenuItem(menu, "option1", "武器商店说明");
    AddMenuItem(menu, "option5", "Buy M4A1 - 60 点");
    AddMenuItem(menu, "option6", "Buy AWP - 125  点");
    AddMenuItem(menu, "option7", "Buy P90  - 15 点");
    AddMenuItem(menu, "option8", "Buy AK47 - 60 点");
    AddMenuItem(menu, "option9", "Buy Deagle - 10  点");
    AddMenuItem(menu, "option10", "Buy famas - 40 点");
    AddMenuItem(menu, "option11", "Buy Galil - 40 点");
    AddMenuItem(menu, "option12", "Buy M249  - 120点");
    AddMenuItem(menu, "option13", "Buy mac10 - 8  点");
    AddMenuItem(menu, "option14", "Buy UMP45 - 12  点");
    AddMenuItem(menu, "option15", "Buy MP5 - 10  点");
    AddMenuItem(menu, "option16", "Buy XM1014 - 80 点");
	AddMenuItem(menu, "option18", "Buy 匪连狙 - 90  点");
	AddMenuItem(menu, "option19", "Buy Elite - 5  点");
	AddMenuItem(menu, "option20", "Buy M3 Super - 75  点");
	AddMenuItem(menu, "option21", "Buy Glock - 1  点");
	AddMenuItem(menu, "option22", "Buy P228 - 2  点");
	AddMenuItem(menu, "option23", "Buy FN57 - 2  点");
	AddMenuItem(menu, "option24", "Buy TMP - 8  点");
	AddMenuItem(menu, "option25", "Buy 鸟狙 - 50  点");
	AddMenuItem(menu, "option26", "Buy 手雷 - 25  点");
	AddMenuItem(menu, "option27", "Buy 警连狙 - 90  点");
	AddMenuItem(menu, "option28", "Buy USP - 1  点");
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, clientId, MENU_TIME_FOREVER);
    
    
    return Plugin_Handled;
}

public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
    if ( action == MenuAction_Select ) 
    {
        new String:info[32];
        
        GetMenuItem(menu, itemNum, info, sizeof(info));

        if ( strcmp(info,"option1") == 0 ) 
        {
            {
              DID(client);
              PrintToChat(client,"\x04[武器商店] \x05击杀僵尸获得点数");
              //PrintToChat(client, "\x04[SM_JailAwards] \x05Version:\x03 %s \x05created for SourceMod.", VERSION);
            }
            
        }


        
        else if ( strcmp(info,"option5") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 60)
              {
                  if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_m4a1");

                      g_iCredits[client] -= 60;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了M4A1 如果你手中有主武器，M4A1会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option6") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 125)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_awp");

                      g_iCredits[client] -= 125;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了AWP 如果你手中有主武器，AWP会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option7") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 15)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_p90");

                      g_iCredits[client] -= 15;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了P90 如果你手中有主武器，P90会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option8") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 60)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_ak47");

                      g_iCredits[client] -= 60;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了AK47 如果你手中有主武器，AK47会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option9") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 10)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_deagle");

                      g_iCredits[client] -= 10;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了沙鹰 如果你手中有副武器，沙鹰会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option10") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 40)
              {
                    if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_famas");

                      g_iCredits[client] -= 40;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了法玛斯 如果你手中有主武器，法玛斯会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option11") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 5)
              {
                    if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_galil");

                      g_iCredits[client] -= 9;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了加利尔 如果你手中有主武器，加利尔会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }


        else if ( strcmp(info,"option12") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 120)
              {
                    if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_m249");

                      g_iCredits[client] -= 120;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了M249 如果你手中有主武器，M249会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }


        else if ( strcmp(info,"option13") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 8)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_mac10");

                      g_iCredits[client] -= 8;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了MAC10 如果你手中有主武器，MAC10会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option14") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 12)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_ump45");

                      g_iCredits[client] -= 12;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了UMP45 如果你手中有主武器，UMP45会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option15") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 10)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_mp5navy");

                      g_iCredits[client] -= 10;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了MP5 如果你手中有主武器，MP5会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option16") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 80)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_xm1014");

                      g_iCredits[client] -= 80;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了XM1014 如果你手中有主武器，XM1014会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
            
        }

        else if ( strcmp(info,"option17") == 0 ) 
        {
            {
              DID(client);
              PrintToChat(client, "\x04[SM_JailAwards] \x05Your current credits are: %i", g_iCredits[client]);
            }
            
        }
		
		
		else if ( strcmp(info,"option18") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 90)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_g3sg1");

                      g_iCredits[client] -= 90;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了连狙 如果你手中有主武器，连狙会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }
			
			
			
            
            
        }
		
		
		else if ( strcmp(info,"option19") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 5)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_elite");

                      g_iCredits[client] -= 5;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了Elite 如果你手中有副武器，Elite会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
		
		
		
		else if ( strcmp(info,"option20") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 75)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_m3");

                      g_iCredits[client] -= 75;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了M3 如果你手中有主武器，M3会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
		
		
		else if ( strcmp(info,"option21") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 1)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_glock");

                      g_iCredits[client] -= 9;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了克洛克 如果你手中有副武器，克洛克会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
		
		
		
		else if ( strcmp(info,"option22") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 2)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_p228");

                      g_iCredits[client] -= 2;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了p228 如果你手中有副武器，P228会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
		
		
		
		else if ( strcmp(info,"option23") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 2)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_fiveseven");

                      g_iCredits[client] -= 2;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了FN57 如果你手中有副武器，FN57会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
		
		else if ( strcmp(info,"option24") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 2)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_tmp");

                      g_iCredits[client] -= 2;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了TMP 如果你手中有主武器，TMP会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
		
		else if ( strcmp(info,"option25") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 50)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_scout");

                      g_iCredits[client] -= 50;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了鸟狙 如果你手中有主武器，鸟狙会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
		
		else if ( strcmp(info,"option26") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 25)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_hegrenade");

                      g_iCredits[client] -= 25;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了手雷 如果你手中有手雷，那么手雷会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
       
	   else if ( strcmp(info,"option27") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 100)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_sg550");

                      g_iCredits[client] -= 100;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了SG550 如果你手中有主武器，那么SG550会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
	   
	   else if ( strcmp(info,"option27") == 0 ) 
        {
            {
              DID(client);
              if (g_iCredits[client] >= 1)
              {
                   if (IsPlayerAlive(client))
                   {

                      GivePlayerItem(client, "weapon_usp");

                      g_iCredits[client] -= 1;

                      PrintToChat(client, "\x04[武器商店] \x05你购买了USP 如果你手中有副武器，那么USP会掉在地上", g_iCredits[client]);
                   }
                   else
                   {
                      PrintToChat(client, "\x04[武器商店] \x05你必须活着才能买东西");
                   }
              }
              else
              {
                 PrintToChat(client, "\x04[武器商店] \x05你没有足够的点数来买东西", g_iCredits[client]);
              }
            }

        }
	   
	   
    }
}

public Action:FijarCreditos(client, args)
{
    if(client == 0)
    {
		PrintToServer("%t","Command is in-game only");
		return Plugin_Handled;
    }

    if(args < 2) // Not enough parameters
    {
        ReplyToCommand(client, "[SM] Use: sm_setcredits <#userid|name> [amount]");
        return Plugin_Handled;
    }

    decl String:arg2[10];
    //GetCmdArg(1, arg, sizeof(arg));
    GetCmdArg(2, arg2, sizeof(arg2));

    new amount = StringToInt(arg2);
    //new target;

    //decl String:patt[MAX_NAME]

    //if(args == 1) 
    //{ 
    decl String:strTarget[32]; GetCmdArg(1, strTarget, sizeof(strTarget)); 

    // Process the targets 
    decl String:strTargetName[MAX_TARGET_LENGTH]; 
    decl TargetList[MAXPLAYERS], TargetCount; 
    decl bool:TargetTranslate; 

    if ((TargetCount = ProcessTargetString(strTarget, client, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
                                           strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
    { 
          ReplyToTargetError(client, TargetCount); 
          return Plugin_Handled; 
    } 

    // Apply to all targets 
    for (new i = 0; i < TargetCount; i++) 
    { 
        new iClient = TargetList[i]; 
        if (IsClientInGame(iClient)) 
        { 
              g_iCredits[iClient] = amount;
              PrintToChat(client, "\x04[SM_JailAwards] \x05Set %i credits in the player %N", amount, iClient);
        } 
    } 
    //}  



//    SetEntProp(target, Prop_Data, "m_iDeaths", amount);


    return Plugin_Continue;
}


public Action:ResetAmmo(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && !IsFakeClient(client) && IsClientInGame(client) && IsPlayerAlive(client) && (g_AmmoInfi[client]))
		{
			Client_ResetAmmo(client);
		}
	}
}

public Client_ResetAmmo(client)
{
	new zomg = GetEntDataEnt2(client, activeOffset);
	if (clip1Offset != -1 && zomg != -1)
		SetEntData(zomg, clip1Offset, 200, 4, true);
	if (clip2Offset != -1 && zomg != -1)
		SetEntData(zomg, clip2Offset, 200, 4, true);
	if (priAmmoTypeOffset != -1 && zomg != -1)
		SetEntData(zomg, priAmmoTypeOffset, 200, 4, true);
	if (secAmmoTypeOffset != -1 && zomg != -1)
		SetEntData(zomg, secAmmoTypeOffset, 200, 4, true);
}


public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
      if (g_Godmode[victim])
      {
               damage = 0.0;
               return Plugin_Changed;
      }
      return Plugin_Continue;
}

public Action:OnWeaponCanUse(client, weapon)
{
  if (g_Fly[client])
  {
      decl String:sClassname[32];
      GetEdictClassname(weapon, sClassname, sizeof(sClassname));
      if (!StrEqual(sClassname, "weapon_knife"))
          return Plugin_Handled;
  }
  return Plugin_Continue;
}

public OnClientPutInServer(client)
{
   SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
   SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public OnClientPostAdminCheck(client)
{
    g_Godmode[client] = false;
    g_Fly[client] = false;
    g_AmmoInfi[client] = false;
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
  new client = GetClientOfUserId(GetEventInt(event, "userid"));

  if (GetClientTeam(client) == 1 && !IsPlayerAlive(client))
  {
         return;
  }

  CreateTimer(1.0, MensajesSpawn, client);




  if (g_Fly[client])
  {
    g_Fly[client] = false;
    SetEntityMoveType(client, MOVETYPE_WALK);
  }
  if (g_Godmode[client])
  {
    g_Godmode[client] = false;
  }
  if (g_AmmoInfi[client])
  {
    g_AmmoInfi[client] = false;
  }
}


public Action:OpcionNumero16b(Handle:timer, any:client)
{
 if ( (IsClientInGame(client)) && (IsPlayerAlive(client)) )
 {
   PrintToChat(client, "\x04[SM_JailAwards] \x05You have 10 seconds of invulnerability!");
   CreateTimer(10.0, OpcionNumero16c, client);
 }
}

public Action:OpcionNumero16c(Handle:timer, any:client)
{
 if ( (IsClientInGame(client)) && (IsPlayerAlive(client)) )
 {
   PrintToChat(client, "\x04[SM_JailAwards] \x05Now you are a mortal!");
   g_Godmode[client] = false;
   SetEntityRenderColor(client, 255, 255, 255, 255);
 }
}
