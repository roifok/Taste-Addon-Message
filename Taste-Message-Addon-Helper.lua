-- Addon by Tastemylock
-- Update: 30-07-2019

TasteMsgAddonHelper = LibStub("AceAddon-3.0"):NewAddon("TasteMsgAddonHelper", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0", "AceSerializer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("TasteMsgAddonHelper", true)
local LibC = LibStub:GetLibrary("LibCompress")
local LibCE = LibC:GetAddonEncodeTable()
local debug = false
local playername = ''
local default_whisper = "Sorry but no Silas up yet :("

local player_class = UnitClass("player")

function isReady()
    return true
end

function SilasBuffIsUp()	
	if UnitBuff("player", SilasId) then 
	    return true
	end
	return false
end

function SilasBuffDuration()
    --Silas' Potion of Prosperity buff id
    local SilasId = 293946
    local _, _, _, _, _, duration, expirationTime = UnitBuff("player", SilasId)
    
	return expirationTime or 0
end

local timed_whisper = "Remaining time on Silas buff :" .. expirationTime .. " seconds"

-- get option value
local function GetGlobalOptionLocal(info)
	return TasteMsgAddonHelper.db.global[info[#info]]
end

-- set option value
local function SetGlobalOptionLocal(info, value)
	if debug and TasteMsgAddonHelper.db.global[info[#info]] ~= value then
		TasteMsgAddonHelper:Printf("DEBUG: global option %s changed from '%s' to '%s'", info[#info], tostring(GuildRecr.db.global[info[#info]]), tostring(value))
	end
	TasteMsgAddonHelper.db.global[info[#info]] = value
	LibStub("AceConfigRegistry-3.0"):NotifyChange("TasteMsgAddonHelper")
end

-- declare defaults to be used in the DB
local defaults = {
	global = {
		enabled = isReady(),
		whisper = default_whisper,
        auto_party = false,
        display_whisper_overlay = false
	}
}

function TasteMsgAddonHelper:ContainsSilasMessages(msg)
  return (msg:lower():match('Silas') or 
    msg:lower():match('Alchy') or 
    msg:lower():match('Alchi') or 
    msg:lower():match('!silas'))
end

-- a filter to hide all yelled messaged containing certain text
function NoWhisperWindow(self,event,msg)
  return TasteMsgAddonHelper:ContainsSilasMessages(msg)
end

function InitTextFrame()
    MOD_TextFrame = CreateFrame("Frame");
    MOD_TextFrame:ClearAllPoints();
    MOD_TextFrame:SetHeight(300);
    MOD_TextFrame:SetWidth(300);
    MOD_TextFrame:SetScript("OnUpdate", MOD_TextFrame_OnUpdate);
    MOD_TextFrame:Hide();
    MOD_TextFrame.text = MOD_TextFrame:CreateFontString(nil, "BACKGROUND", "PVPInfoTextFont");
    MOD_TextFrame.text:SetAllPoints();
    MOD_TextFrame:SetPoint("CENTER", 0, 200);
    MOD_TextFrameTime = 0;
end

function MOD_TextFrame_OnUpdate()
  if (MOD_TextFrameTime < GetTime() - 3) then
    local alpha = MOD_TextFrame:GetAlpha();
    if (alpha ~= 0) then MOD_TextFrame:SetAlpha(alpha - .05); end
    if (alpha == 0) then MOD_TextFrame:Hide(); end
  end
end

function MOD_TextMessage(message)
      MOD_TextFrame.text:SetText(message);
      MOD_TextFrame:SetAlpha(1);
      MOD_TextFrame:Show();
      MOD_TextFrameTime = GetTime();
end

-- Option menu (Interface-->Settings)
local options = {
    name = "TasteMsgAddonHelper",
	type = "group",
	childGroups = "tab",
	args = {
		general_tab = {
			name = "General",
			type = "group",
			order = 10,
			args = {
				enabled = {
					type = "toggle",
					order = 2,
					name = "Enable Addon",
					desc = "Enable or disable addon functionality.",
					width = "full",
					get =	GetGlobalOptionLocal,
					set =	function (info, value)
								SetGlobalOptionLocal(info, value)
							end
				},
                display_whisper_overlay = 
                {
                   type = "toggle",
					order = 3,
					name = "Enable whisper from player in overlay",
					desc = "Enable or disable whisper in overlay.",
					width = "full",
					get =	GetGlobalOptionLocal,
					set =	function (info, value)
								SetGlobalOptionLocal(info, value)
							end   
                },
                auto_party = 
                {
                   type = "toggle",
					order = 4,
					name = "Enable auto accept party invites.",
					desc = "Enable or disable auto accept party invites.",
					width = "full",
					get =	GetGlobalOptionLocal,
					set =	function (info, value)
								SetGlobalOptionLocal(info, value)
							end   
                },
				whisper = 
				{
					type = "input",
					order = 5,
					name = "Whisp Answer",
					multiline = true,
					desc = "Custom whisp answer message",
					width = "full",
					get = GetGlobalOptionLocal,
					set = function (info, value)
							  SetGlobalOptionLocal(info, value)
						  end
				}
			}
		}
	}	
}

-- get server time in unix timestamp format
local function GetServerTime()
	local weekday, month, day, year = CalendarGetDate()
	local hours, minutes = GetGameTime()
	
	local timeset = { year = year, month = month, day = day, hour = hours, min = minutes }
	
	return time(timeset)
end

local function isempty(s)
  return s == nil or s == ''
end

function TasteMsgAddonHelper:AcceptInvite()
   if TasteMsgAddonHelper.db.global.auto_party then
        AcceptGroup()
        for i = 1, STATICPOPUP_NUMDIALOGS do
            local dialog = _G["StaticPopup" .. i]
            if dialog.which == "PARTY_INVITE" then
                dialog.inviteAccepted = 1
                break
            end
        end
        StaticPopup_Hide("PARTY_INVITE")
        f:UnregisterEvent("PARTY_MEMBERS_CHANGED")
    end
end

function TasteMsgAddonHelper:AutoAccept()
    if TasteMsgAddonHelper.db.global.auto_party then
        f = CreateFrame("Frame")
        f:RegisterEvent("PARTY_INVITE_REQUEST")
        f:SetScript("OnEvent", function(self, event, msg, sender)
              TasteMsgAddonHelper:AcceptInvite()
          end)
    else
        f:UnregisterEvent("PARTY_INVITE_REQUEST")
    end
end

-- The whisperback functon..
function TasteMsgAddonHelper:WhisperBack()
	
	local dist, target
    dist, target = "WHISPER", dest

    -- Current Playername.. ( Yourself )
    playername = GetUnitName("player", true)
    f = CreateFrame("frame")
    
    -- Hook whisper event.
    f:RegisterEvent("CHAT_MSG_WHISPER")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("CHAT MSG RAID")
    f:RegisterEvent("CHAT MSG PARTY")
	
    -- Listen to OnEvent... from CHAT_MSG_WHISPER
    f:SetScript("OnEvent", function(self, event, msg, sender)
        
        -- Only do something when the addon is enabled.
		if TasteMsgAddonHelper.db.global.enabled then
            
            if not isempty(TasteMsgAddonHelper.db.global.whisper) and SilasBuffIsUp() then
                wmessage = TasteMsgAddonHelper.db.global.timed_whisper
			else
			    wmessage = TasteMsgAddonHelper.db.global.whisper
            end
						
            -- Only do something when one of the incoming whispers contains Silas etc..
            if TasteMsgAddonHelper:ContainsSilasMessages(msg) then

                if not isempty(wmessage) then

                    if not debug then

                        -- if the player NOT matches yourself then..
                        if not sender:match(playername) then
                            if TasteMsgAddonHelper.db.global.display_whisper_overlay then
                                InitTextFrame()
                                MOD_TextFrame:Hide();
                                MOD_TextMessage("|cffffff00"..sender.."|r: "..msg)
                            end
                            -- Send a whisper to the player
                            SendChatMessage(wmessage, "WHISPER", nil, sender);
                        else
                            TasteMsgAddonHelper:Printf("|cff40c040Why are you whispering yourself for Silas? hic....|r")
                        end

                    else
                        -- if the player matches yourself then (DEBUGMODE)..
                        if sender:match(playername) then
                            if TasteMsgAddonHelper.db.global.display_whisper_overlay then
                                -- Get the whisper of the player in an overlay and dissapear in 3 seconds.
                                MOD_TextMessage(msg)
                            end
                            -- Send a whisper to the yourself youre the sender in this case...
                            SendChatMessage(string.gsub(wmessage, "silas", ""), "WHISPER", nil, sender);
                        end
                    end

                    else
                        -- No whisper given..
                        TasteMsgAddonHelper:Printf('|cff40c040Please define a Whisper text in /tmah or interface --> TasteMsgAddonHelper |r')
                    end

            end
		
		end
            
        -- Break out of the function.
		do return end			
			
	end)
	
end

-- Called when the addon is disabled
function TasteMsgAddonHelper:OnDisable()
	
	-- unregister events
	self:UnregisterAllEvents()
	
	-- unregister comm events
	self:UnregisterAllComm()
	self:UnregisterChatCommand("tmah")
	
end

-- Called when the addon is enabled
function TasteMsgAddonHelper:OnEnable()
    
    -- If this is a Mage than we can go further.
    if isReady() then
        TasteMsgAddonHelper:WhisperBack()
        TasteMsgAddonHelper:AutoAccept()
    else
        TasteMsgAddonHelper:Printf("|cff0070ddthis addon can only be used on a Mage character|r")
    end
    
end

-- Process the slash command ("input" contains whatever follows the slash command)
function TasteMsgAddonHelper:ConsoleCommand(input)
	-- show configuration window if no params given
	if not input or input:trim() == "" then
		InterfaceOptionsFrame_OpenToCategory(self.configFrame)
	end
	
	if input == "debug" then
		self:Print("DEBUG: enabled")
		debug = true
	end

	if input == "nodebug" then
		self:Print("DEBUG: disabled")
		debug = false
	end
    
end

-- Code that you want to run when the addon is first loaded goes here.
function TasteMsgAddonHelper:OnInitialize()

    -- Only Init when the class is a mage.... !
    if isReady() then
        
        -- initialize saved variables
        self.db = LibStub("AceDB-3.0"):New("TasteMsgAddonHelperDB", defaults, true)

        -- initialize configuration options
        LibStub("AceConfig-3.0"):RegisterOptionsTable("TasteMsgAddonHelperDB", options)
        self.configFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TasteMsgAddonHelperDB", "Mage Portal Whisper");

        -- create LibDataBroker
        self.ldb = LibStub("LibDataBroker-1.1"):NewDataObject("TasteMsgAddonHelper", {
            type = "data source",
            text = "",
            label = "",
            icon = "Interface\\Icons\\trade_alchemy_potione1"
        })

        -- Only onetime init
        -- TextOverlay.
        InitTextFrame()
        
        -- Block the crappy portals in channels.
        -- Unlikly behaviour so commented for now
        -- I want to UnRegisterMessageEventFilter but its not working properly.
        -- ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", NoWhisperWindow)
        -- ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", NoWhisperWindow)
        -- ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", NoWhisperWindow)
        -- ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", NoWhisperWindow)
    
        -- Register /tmah to get the settings window.
        self:RegisterChatCommand("tmah", "ConsoleCommand")
        
	end
    
end
