-- Commands for managing players
local BAdmin = BAdmin

local JailAutoBan = GetConVar("badmin_jailautoban")

--======== Set rank of a player

function callfunc(ply,args)
	if args[1] == ply then return false, "You can't use this on yourself, it's not safe!" end
	local rank = ""

	if tonumber(args[2]) != nil then rank = BAdmin.RankTable[math.floor(math.Clamp(tonumber(args[2]),0,2))] else rank = BAdmin.RankTable[BAdmin.InvRankTable[args[2]]] or "user" end
	BAdmin.Utilities.updateRank(args[1]:SteamID64(),rank,args[1])

	BAdmin.Utilities.broadcastPrint({
		Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just set the rank of ",
		Color(255,127,127),args[1]:Nick(),
		Color(200,200,200)," to ",
		Color(255,127,127),BAdmin.UserList["id" .. args[1]:SteamID64()] or "user",
		Color(200,200,200),"!"
	})

	return true
end
cmdSettings = { -- Superadmin+ only command
	["Help"] = "<target> - Sets the rank of the player (0-2) (user,admin,superadmin)",
	["MinimumPrivilege"] = 2,
	["HasTarget"] = true,
	["CanTargetEqual"] = true,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("setrank",callfunc,cmdSettings)

--======== Get rank of a player

function callfunc(ply,args)
	BAdmin.Utilities.chatPrint(ply,{
		Color(255,127,127),args[1]:Nick(),
		Color(200,200,200)," has the rank ",
		Color(255,127,127),BAdmin.UserList["id" .. args[1]:SteamID64()] or "user",
		Color(200,200,200),"."
	})

	return true
end
cmdSettings = { -- Admin+ only command
	["Help"] = "<target> - Gets the rank of the player.",
	["MinimumPrivilege"] = 1,
	["HasTarget"] = true,
	["IgnoreTargetPriv"] = true,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("getrank",callfunc,cmdSettings)

--======== Kick by name

function callfunc(ply,args) -- Kick
	local tgt = args[1]
	if IsValid(ply) and IsValid(tgt) and tgt == ply then return false, "You can't kick yourself!" end
	table.remove(args,1)
	local Reason = table.concat(args," ")
	tgt:Kick(Reason or "You were kicked.")

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just kicked ",Color(255,127,127),tgt:Nick(),Color(200,200,200),"!"})

	return true
end
cmdSettings = {
	["Help"] = "<target> <reason> - Kicks the target.",
	["HasTarget"] = true,
	["CanTargetEqual"] = true,
	["MinimumPrivilege"] = 1,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("kick",callfunc,cmdSettings)

--======== Ban by name

function callfunc(ply,args) -- Ban
	local tgt = args[1]
	table.remove(args,1)
	local pretime = args[1]

	if IsValid(ply) and IsValid(tgt) and tgt == ply then return false, "You can't ban yourself!" end

	local ID = tgt:OwnerSteamID64()
	local time = 1440 -- 1 day in minutes
	if pretime and tonumber(pretime) != nil then
		table.remove(args,1)
		time = tonumber(pretime)
	end

	local Reason = table.concat(args," ")

	BAdmin.Utilities.addBan(ID,time,string.Explode(":",tgt:IPAddress())[1])

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just banned ",Color(255,127,127),tgt:Nick(),Color(200,200,200)," for " .. string.NiceTime(time * 60) .. "!"})

	tgt:Kick("You have been banned for " .. string.NiceTime(time * 60) .. " for: " .. (Reason or "No reason specified."))

	return true
end
cmdSettings = {
	["Help"] = "<target> <minutes (def. 1440)> - Bans the target. 0 for permanent",
	["HasTarget"] = true,
	["CanTargetEqual"] = false,
	["MinimumPrivilege"] = 1,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("ban",callfunc,cmdSettings)

--======== Ban by SteamID

function callfunc(ply,args) -- BanID
	if not args[1] then return false,"Missing a SteamID to ban!" end
	local ID = BAdmin.Utilities.safeID(args[1])
	if ID == "INVALID" then return false,"Invalid ID!" end
	table.remove(args,1)
	local pretime = args[1]

	local time = 1440 -- 1 day in minutes
	if pretime and tonumber(pretime) != nil then
		table.remove(args,1)
		time = tonumber(pretime)
	end

	if IsValid(ply) and ID == ply:SteamID64() then return false, "You can't ban yourself!" end

	local Reason = table.concat(args," ")

	BAdmin.Utilities.addBan(ID,time,_,Reason)

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just banned ",Color(255,127,127),ID,Color(200,200,200)," for " .. string.NiceTime(time * 60) .. "!"})

	return true
end
cmdSettings = {
	["Help"] = "<SteamID64> <minutes (def. 1440)> - Bans the SteamID. 0 for permanent",
	["MinimumPrivilege"] = 1,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("banid",callfunc,cmdSettings)

function callfunc(ply,args) -- Unban
	if not args[1] then return false,"Missing a SteamID to ban!" end
	local SafeID = BAdmin.Utilities.safeID(args[1])
	local Pass,Reason = BAdmin.Utilities.removeBan(SafeID)

	if Pass == false then return false, Reason end

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just unbanned ",Color(255,127,127),SafeID,Color(200,200,200),"!"})

	return true
end
cmdSettings = {
	["Help"] = "<SteamID64> - Unbans the SteamID.",
	["MinimumPrivilege"] = 1,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("unban",callfunc,cmdSettings)

-- Freeze map

function callfunc(ply,args) -- Freezing the whole map
	for k,v in pairs(ents.GetAll()) do
		local Phys = v:GetPhysicsObject()
		if IsValid(Phys) then
			Phys:EnableMotion(false)
		end
	end

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just froze the entire map!"})

	return true
end
cmdSettings = {
	["Help"] = "Freezes all of the props across the map.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("freezemap",callfunc,cmdSettings)

-- Toggle physics

function callfunc(ply,args) -- Freezing the whole map

	physenv.SetPhysicsPaused(not physenv.GetPhysicsPaused())

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just toggled the physics simulation!"})

	return true
end
cmdSettings = {
	["Help"] = "Toggles physics sim for the whole server.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("togglephysics",callfunc,cmdSettings)

--======== Set Jail Position

function callfunc(ply,args) -- Jail position
	BAdmin.Jail.JailPos = ply:GetPos()

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," set the jail position."})

	return true
end
cmdSettings = {
	["Help"] = "Sets the jail position.",
	["MinimumPrivilege"] = 1
}
BAdmin.Utilities.addCommand("setjail",callfunc,cmdSettings)

local function jail(ply,time,opt_id)
	local SafeID = opt_id or ply:SteamID64()
	PrintTable(BAdmin.Jail.Players)
	if time == 0 then -- unjailing
		local Data = BAdmin.Jail.Players[SafeID] or false
		if Data == false then return false, "Player isn't jailed!" end

		timer.Remove(Data["timerid"])

		BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," has ended their jail sentence!"})

		if IsValid(ply) then
			ply:SetNWBool("BAdmin.IsJailed",false)
			ply:Spawn()
		end

		BAdmin.Jail.Players[SafeID] = nil
		PrintTable(BAdmin.Jail.Players)

		return true,"unjailed"
	else
		local Data = {}

		local timerid = "badmin.jailtimer_" .. SafeID

		Data["timerid"] = timerid
		Data["ply"] = ply

		timer.Create(timerid,math.ceil(time * 1),0,function() jail(ply,0,SafeID) end)
		timer.Start(timerid)

		ply:SetNWBool("BAdmin.IsJailed",true)
		ply:Spawn()
		ply:StripWeapons()

		BAdmin.Jail.Players[SafeID] = Data
		PrintTable(BAdmin.Jail.Players)
		return true,"jailed"
	end
end

hook.Add("PlayerDisconnected","BAdmin.JailAutoBan",function()
	if JailAutoBan:GetInt() == 0 then return end
	for k,v in pairs(BAdmin.Jail.Players) do
		if not IsValid(v["ply"]) then
			RunConsoleCommand("bm","banid",k,JailAutoBan:GetInt(),"\"Leaving before jail sentence is over\"")
			timer.Remove(v["timerid"])
			BAdmin.Jail.Players[k] = nil
		end
	end
end)

--======== Jail

function callfunc(ply,args)
	if ply == args[1] then return false,"You can't jail yourself!" end
	local time = (tonumber(args[2]) or 5) * 60
	local Pass,Reason = jail(args[1],time)

	if Pass then
		BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just " .. Reason .. " ",Color(255,127,127),args[1]:Nick(),Color(200,200,200),time > 0 and (" for " .. string.NiceTime(math.ceil(time))) or "","!"})
	else return false, Reason end

	return true
end
cmdSettings = {
	["Help"] = " <target> <time (def. 5 minutes)> - Jails the target.",
	["HasTarget"] = true,
	["MinimumPrivilege"] = 1
}
BAdmin.Utilities.addCommand("jail",callfunc,cmdSettings)

hook.Add("PlayerSpawn","BAdmin.PlayerSpawn",function(ply,_) -- helper hook for jailing
	ply:SetNoTarget(ply:GetObserverMode() != OBS_MODE_NONE) -- catchall for spectators
	if ply:GetNWBool("BAdmin.IsJailed",false) == false then return end
	timer.Simple(0,function() ply:StripWeapons() end) -- must be delayed by a single tick otherwise it won't work
	if BAdmin.Jail.JailPos != false then
		ply:SetPos(BAdmin.Jail.JailPos)
		ply:SetLocalVelocity(Vector(0,0,0))
	end
end)

hook.Add("PlayerNoClip","BAdmin.JailNoclip",function(ply,state)
	if ply:GetNWBool("BAdmin.IsJailed",false) == false then return end
	if state == false then return true else return false end
end)

hook.Add("Initialize","BAdmin.CPPICheck",function()
	local CPPIExists = CPPI
	if CPPIExists != nil then
		MsgN("[BADMIN] + CPPI compliant prop protection found!")
	else
		MsgN("[BADMIN] - No CPPI compliant prop protection found, install for special commands!")
	end

	if CPPIExists then -- Put anything that relies on prop protection here
		MsgN("+ Enabling CPPI compliant commands...")
		function callfunc(ply,args) -- Freezing the player's props
			for k,v in pairs(ents.GetAll()) do
				if v:CPPIGetOwner() != args[1] then continue end
				local Phys = v:GetPhysicsObject()
				if IsValid(Phys) then
					Phys:EnableMotion(false)
				end
			end

			BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just froze all of ",Color(255,127,127),args[1]:Nick(),Color(200,200,200),"'s props!"})

			return true
		end
		cmdSettings = {
			["Help"] = " <target> - Freeze the target's props.",
			["HasTarget"] = true,
			["CanTargetEqual"] = true,
			["MinimumPrivilege"] = 1,
			["RCONCanUse"] = true
		}
		BAdmin.Utilities.addCommand("freezeprops",callfunc,cmdSettings)
	end

	hook.Remove("Initialize","BAdmin.CPPICheck")
end)