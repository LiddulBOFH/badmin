if not BAdmin then BAdmin = {} end

BAdmin.RankTable = {
	[0] = "user",
	[1] = "admin",
	[2] = "superadmin",
	[3] = "console"
}
BAdmin.InvRankTable = {
	["user"] = 0,
	["admin"] = 1,
	["superadmin"] = 2,
	["console"] = 3
}

if SERVER then
	MsgN("+----------START BADMIN----------+")

	BAdmin.Commands = {}
	BAdmin.Utilities = {}
	BAdmin.Autocomplete = {}
	BAdmin.UserList = {}
	BAdmin.Jail = {}
	BAdmin.Jail.JailPos = false
	BAdmin.Jail.Players = {}

	----------------------------------------------------------------------------------------------------------------
		-- Setup user list
	----------------------------------------------------------------------------------------------------------------

	if file.Exists("badmin/users.txt","DATA") then
		MsgN("+ User file found!")
		BAdmin.UserList = util.JSONToTable(file.Read("badmin/users.txt")) or {}
		MsgN("- " .. table.Count(BAdmin.UserList) .. " player(s) hold a rank here.")
	else
		MsgN("| No user file, starting fresh...")
		file.Write("badmin/users.txt","")
		MsgN("+ User file created!")
	end

	----------------------------------------------------------------------------------------------------------------
		-- Utility functions
	----------------------------------------------------------------------------------------------------------------

	CreateConVar("badmin_allowfamilyshare",1,{FCVAR_ARCHIVE, FCVAR_NOTIFY},"[BOOLEAN] Whether to allow FamilyShare game licenses.",0,1)
	CreateConVar("badmin_allowgodmode",1,{FCVAR_ARCHIVE, FCVAR_NOTIFY},"[BOOLEAN] Whether to allow users use of !god.",0,1)
	CreateConVar("badmin_jailautoban",15,{FCVAR_ARCHIVE, FCVAR_NOTIFY},"[NUMBER] Ban the player if they leave before jailtime is up, for this amount of time in minutes.",0)

	BAdmin.CVarList = {}
	local function addcvar(cvar)
		BAdmin.CVarList[#BAdmin.CVarList + 1] = cvar
	end
	addcvar("sbox_noclip")
	addcvar("badmin_allowfamilyshare")
	addcvar("badmin_allowgodmode")
	addcvar("badmin_enablemapvote")
	addcvar("badmin_jailautoban")

	util.AddNetworkString("BAdmin.chatPrint")
	function BAdmin.Utilities.chatPrint(ply,msgtable)
		if not IsValid(ply) then -- prints to console instead
			local str = ""
			for k,v in ipairs(msgtable) do
				if type(v) == "string" then str = str .. v end
			end
			print(str)
		else
			net.Start("BAdmin.chatPrint")
				net.WriteTable(msgtable)
			net.Send(ply)
		end
	end

	function BAdmin.Utilities.broadcastPrint(msgtable)
		-- for RCON
		local str = ""
		for k,v in ipairs(msgtable) do
			if type(v) == "string" then str = str .. v end
		end
		print(str)

		net.Start("BAdmin.chatPrint")
			net.WriteTable(msgtable)
		net.Broadcast()
	end

	function BAdmin.Utilities.checkPriv(ply)
		if not IsValid(ply) then return 3 -- RCon!
		elseif ply:IsListenServerHost() then return 3 -- for listenservers, host is all powerful
		elseif BAdmin.UserList["id" .. ply:SteamID64()] == "superadmin" then return 2 -- superadmin
		elseif BAdmin.UserList["id" .. ply:SteamID64()] == "admin" then return 1 -- admin
		else return 0 end -- regular user
	end

	function BAdmin.Utilities.initialRank(ply) -- assign the rank they have
		if BAdmin.UserList["id" .. ply:SteamID64()] then
			ply:SetUserGroup(BAdmin.UserList["id" .. ply:SteamID64()] or "user")
			ply:SetNWString("UserGroup",BAdmin.UserList["id" .. ply:SteamID64()] or "user")
		elseif ply:IsListenServerHost() then
			ply:SetUserGroup("superadmin")
			ply:SetNWString("UserGroup","superadmin")
		end

		MsgN("Set " .. BAdmin.Utilities.checkName(ply) .. " to rank " .. ply:GetNWString("UserGroup"))
	end

	function BAdmin.Utilities.updateRank(id,rank,opt_ply)
		local FinalID = BAdmin.Utilities.safeID(id)

		if (rank == "user") or (rank == "") then -- remove the player's entry to save space
			BAdmin.UserList["id" .. FinalID] = nil
		else
			BAdmin.UserList["id" .. FinalID] = rank
		end

		if opt_ply then opt_ply:SetUserGroup(BAdmin.UserList["id" .. FinalID] or "user") opt_ply:SetNWString("UserGroup",BAdmin.UserList["id" .. FinalID] or "user") end

		file.Write("badmin/users.txt",util.TableToJSON(BAdmin.UserList))
	end

	function BAdmin.Utilities.checkName(ply)
		if IsValid(ply) then return ply:Nick() else return "[CONSOLE]" end
	end

	function BAdmin.Utilities.safeID(id)
		local FinalID = id
		if string.find(id or "","STEAM_") then FinalID = util.SteamIDTo64(id) end
		if FinalID == "0" then return "INVALID" end
		return FinalID
	end

	----------------------------------------------------------------------------------------------------------------
		-- Loader (Core commands and then external commands)
	----------------------------------------------------------------------------------------------------------------

	BAdmin.Utilities.fileTrack = {}
	function BAdmin.Utilities.loadFile(path)
		local files,dirs = file.Find(path .. "/*", "LUA")

		for _,File in pairs(files) do
			if not BAdmin.Utilities.fileTrack[path] then BAdmin.Utilities.fileTrack[string.StripExtension(File)] = (path .. "/" .. File) end

			local fileStrip = string.lower(string.Left(File, 3))
			if fileStrip == "cl_" then
				MsgN("+ Loading [CL] " .. File)

				AddCSLuaFile(path .. "/" .. File)
			elseif fileStrip == "sh_" then
				MsgN("+ Loading [SH] " .. File)

				AddCSLuaFile(path .. "/" .. File)
				include(path .. "/" .. File)
			else
				MsgN("+ Loading " .. File)

				include(path .. "/" .. File)
			end
		end

		for _,dir in pairs(dirs) do
			MsgN("+-- Folder found:" .. File)
			BAdmin.Utilities.loadFile(path .. "/" .. dir)
		end
	end
	local Load = BAdmin.Utilities.loadFile

	----------------------------------------------------------------------------------------------------------------
		-- autocomplete networking
	----------------------------------------------------------------------------------------------------------------

	util.AddNetworkString("BAdmin.commandList")
	util.AddNetworkString("BAdmin.requestCommands")

	-- Builds/rebuilds the autocomplete data to prepare it for distribution to players
	function BAdmin.Autocomplete.build()
		BAdmin.Autocomplete.CMDList = table.GetKeys(BAdmin.Commands)
		BAdmin.Autocomplete.CMDData = {}

		for k,v in pairs(BAdmin.Commands) do
			local Data = {}
			if v["Help"] then
				Data["help"] = v["Help"]
			end

			if v["MinimumPrivilege"] then
				Data["priv"] = v["MinimumPrivilege"]
			else
				Data["priv"] = 0
			end

			BAdmin.Autocomplete.CMDData[k] = Data
		end
	end

	BAdmin.Autocomplete.build()

	timer.Simple(0.5,function()
		BAdmin.Autocomplete.broadcast()
	end)

	-- Broadcasts autocomplete data to all of the players
	function BAdmin.Autocomplete.broadcast()
		net.Start("BAdmin.commandList")
			net.WriteTable(BAdmin.Autocomplete.CMDList)
			net.WriteTable(BAdmin.Autocomplete.CMDData)
		net.Broadcast()
	end

	-- Same as above, but for one player
	function BAdmin.Autocomplete.send(ply)
		net.Start("BAdmin.commandList")
			net.WriteTable(BAdmin.Autocomplete.CMDList)
			net.WriteTable(BAdmin.Autocomplete.CMDData)
		net.Send(ply)
	end

	net.Receive("BAdmin.requestCommands",function(_,ply) -- also the first breathing moment the player can do anything
		BAdmin.Utilities.initialRank(ply)

		local FinalRank = (ply:IsListenServerHost() and "host") or BAdmin.UserList["id" .. ply:SteamID64()]
		BAdmin.Utilities.chatPrint(ply,{Color(200,200,200),"You have the rank of ",Color(255,127,127),FinalRank,Color(200,200,200)," here!"})

		BAdmin.Autocomplete.send(ply)
	end)

	-- console command, so RCON can use select commands, as well as players can have them bound
	concommand.Add("bm",function(ply,_,arg)
		if not arg[1] then return end
		local cmd = arg[1]
		table.remove(arg,1)
		if cmd == "" then return end -- dummy player entered no command
		if not BAdmin.Commands[cmd] then return end

		local didpass, reason = BAdmin.Utilities.runCommand(ply,cmd,arg)
		if not didpass then BAdmin.Utilities.chatPrint(ply,{Color(255,0,0),reason or "No reason was added!"}) end
	end)

	-- hooks!

	hook.Add("PlayerSay","BAdmin.SayHook",function(ply,msg)
		if msg[1] != "!" then return end

		local cmd,args = BAdmin.Utilities.filterCommand(msg)
		if cmd == "" then return end -- dummy player entered no command
		if not BAdmin.Commands[cmd] then return end

		local didpass, reason = BAdmin.Utilities.runCommand(ply,cmd,args)
		if not didpass then BAdmin.Utilities.chatPrint(ply,{Color(255,0,0),reason or "No reason was added!"}) end
		return ""
	end)

	hook.Add("PlayerInitialSpawn","BAdmin.InitialSpawn",function(ply)
		BAdmin.Utilities.initialRank(ply)
	end)

	-- Core folder will always load first, afterwards anything in "lua/badmin/addon" will be loaded, order depending on operating system

	local function LoadBM()
		MsgN("+ Loading core files...")
		Load("badmin/core")

		BAdmin.Utilities.cullBanList()

		-- Load our own commands first
		MsgN("+ Adding core commands...")
		Load("badmin/corecommands")

		-- Load any command files that the current gamemode might have, if they opt to write any
		MsgN("+ Adding gamemode commands...")
		Load(engine.ActiveGamemode() .. "/badmin/addon")

		-- Load any command files that another addon might have
		MsgN("+ Adding addon commands...")
		Load("badmin/addon")

		MsgN("+ Finished adding commands!")

		BAdmin.Autocomplete.build()

		timer.Simple(0.5,function()
			BAdmin.Autocomplete.broadcast()
		end)
	end

	hook.Add("PostGamemodeLoaded", "BAdmin.PostGamemodeLoad", function()
		LoadBM()

		BAdmin.Initialized	= true

		hook.Remove("PostGamemodeLoaded", "BAdmin.PostGamemodeLoad")
	end)

	if BAdmin.Initialized then
		LoadBM()
	end

	MsgN("Finished loading BAdmin!")
	MsgN("+-----------END BADMIN-----------+")
elseif CLIENT then --------------------------------------------------------
	local CommandList = {}
	local CMDData = {}
	local ChatOpen,IsCommand,ExactMatch,Suggestions = false,false,false,{}
	local PlayerPriv = 0

	hook.Add("InitPostEntity","BAdmin.initRequestCommands",function()
		net.Start("BAdmin.requestCommands")
		net.SendToServer()
	end)

	net.Receive("BAdmin.chatPrint",function()
		chat.AddText(unpack(net.ReadTable()))
	end)

	net.Receive("BAdmin.commandList",function()
		CommandList = net.ReadTable()
		CMDData = net.ReadTable()
	end)

	-- Evolve-like autocomplete

	hook.Add("StartChat","BAdmin.ChatAutocomplete",function() PlayerPriv = (BAdmin.InvRankTable[LocalPlayer():GetNWString("UserGroup")] or 0) ChatOpen = true end)
	hook.Add("FinishChat","BAdmin.ChatAutocomplete",function() ChatOpen = false end)

	hook.Add("ChatTextChanged","BAdmin.ChatAutocomplete",function(text)
		Suggestions = {}
		ExactMatch = false
		IsCommand = false
		if text[1] != "!" then return end
		local cmd = string.sub(text,2)
		cmd = string.lower(string.Explode(" ",cmd)[1])
		if cmd == "" then return end
		IsCommand = true

		for k,v in ipairs(CommandList) do
			if #Suggestions == 5 then break end
			if string.find(v,cmd) and (PlayerPriv >= CMDData[v]["priv"]) then
				table.insert(Suggestions,v)
				if cmd == v then
					ExactMatch = true
					break
				end
			end
		end
	end)

	hook.Add("OnChatTab","BAdmin.ChatAutocomplete",function()
		if #Suggestions == 0 then return end
		if ExactMatch then return end
		return "!" .. Suggestions[1]
	end)

	hook.Add("HUDPaint","BAdmin.ChatAutocomplete",function()
		if (not ChatOpen) or (not IsCommand) then return end
		local ChatX,ChatY = chat.GetChatBoxPos()
		ChatX = ChatX + 24

		surface.SetFont("ChatFont")

		if #Suggestions > 0 then
			for k,v in ipairs(Suggestions) do
				local LinePosX,LinePosY = ChatX,ChatY - 24 - (20 * (k - 1))
				if k == 1 then surface.SetTextColor(Color(127,255,0)) else surface.SetTextColor(Color(255,255,127)) end
				surface.SetTextPos(LinePosX,LinePosY)
				local TextSizeX,_ = surface.GetTextSize("!" .. v)
				surface.DrawText("!" .. v)

				if CMDData[v]["help"] then
					surface.SetTextPos(LinePosX + TextSizeX,LinePosY)
					surface.SetTextColor(Color(200,200,200))
					surface.DrawText(" - " .. CMDData[v]["help"])
				end
			end
		else
			surface.SetTextPos(ChatX,ChatY - 24)
			surface.SetTextColor(Color(255,127,0))
			surface.DrawText("!help - Because it looks like you need it")
		end
	end)
end
