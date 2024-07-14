-- Commands to aid players in general play
local BAdmin = BAdmin

local CanNoclip = GetConVar("sbox_noclip") -- Controls teleport commands
local CanGodMode = GetConVar("badmin_allowgodmode")

--======== Help command (gets all added commands)
--TODO: hide disabled commands?

function callfunc(ply,args)
	local plyPriv = BAdmin.Utilities.checkPriv(ply)
	local availableCommands = {}
	local IsRCON = not IsValid(ply)

	for k,v in pairs(BAdmin.Commands) do
		if (not IsRCON and ((not v["MinimumPrivilege"]) or (v["MinimumPrivilege"] <= plyPriv))) or (IsRCON and (v["RCONCanUse"] == true or false)) then
			if #availableCommands == 0 then table.insert(availableCommands,k) else table.insert(availableCommands,", " .. k) end
		end
	end

	if not IsRCON then
		local FinalRank = (ply:IsListenServerHost() and "host") or BAdmin.UserList["id" .. ply:SteamID64()]
		BAdmin.Utilities.chatPrint(ply,{Color(200,200,200),"You have the rank ",Color(255,127,127),FinalRank,Color(200,200,200),". Your permission level is ",Color(255,127,127),tostring(plyPriv),Color(200,200,200),"."})
	else
		MsgN("RCON has access to all commands that don't rely on a player.")
	end
	BAdmin.Utilities.chatPrint(ply,{Color(200,200,200),"You can use these commands:\n",Color(255,255,127),unpack(availableCommands)})
	if plyPriv >= 2 then
		local allCVars = {}
		for k,v in pairs(BAdmin.CVarList) do
			if #allCVars == 0 then table.insert(allCVars,v) else table.insert(allCVars,", " .. v) end
		end
		BAdmin.Utilities.chatPrint(ply,{Color(200,200,200),"Additionally, these CVars are available to change:\n",Color(255,127,0),unpack(allCVars)})
	end

	return true, ""
end
cmdSettings = {
	["Help"] = "Prints a list of all commands available to you",
	["RCONCanUse"] = true}
BAdmin.Utilities.addCommand("help",callfunc,cmdSettings)

--======== Opens votemap (addon)

function callfunc(ply,args)
	if not GetConVar("badmin_enablemapvote"):GetBool() then
		return false, "Votemap is disabled on this server!"
	end

	ply:ConCommand("votemap")
	return true
end
cmdSettings = {["Help"] = "Opens the votemap menu"}
BAdmin.Utilities.addCommand("votemap",callfunc,cmdSettings)

--======== Godmode

function callfunc(ply,args) -- Godmode
	local AllowGodMode = CanGodMode:GetBool()
	if AllowGodMode == false then
		local priv = BAdmin.Utilities.checkPriv(ply)
		if priv == 0 then return false, "Godmode is disabled on this server!" end
	end
	if not args[1]:Alive() then return false, "The target is dead!" end

	local A2 = args[2] or "t"

	if args[1] == ply then
		if A2 == "t" then
			if ply:HasGodMode() then ply:GodDisable() else ply:GodEnable() end
		else
			if A2 == "true" or A2 == "1" then args[1]:GodEnable() elseif A2 == "false" or A2 == "0" then args[1]:GodDisable() end
		end
		BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just turned their godmode " .. (ply:HasGodMode() and "on" or "off") .. "!"})
	else
		if A2 == "t" then
			if args[1]:HasGodMode() then args[1]:GodDisable() else args[1]:GodEnable() end
		else
			if A2 == "true" or A2 == "1" then args[1]:GodEnable() elseif A2 == "false" or A2 == "0" then args[1]:GodDisable() end
		end
		BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just " .. (args[1]:HasGodMode() and "enabled" or "disabled") .. " godmode for ",Color(255,127,127),args[1]:Nick(),Color(200,200,200),"!"})
	end

	return true
end
cmdSettings = {
	["Help"] = "<target (def. you)> <0-1 (def. toggles)> - Sets the player's godmode state.",
	["HasTarget"] = true,
	["CanTargetEqual"] = true,
	["MinimumPrivilege"] = 0,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("god",callfunc,cmdSettings)

--======== Ye olde teleport

function callfunc(ply,args)
	if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end

	ply:SetNWVector("BAdmin.ReturnPos",ply:GetPos())
	ply:SetPos(ply:GetEyeTrace().HitPos)
	ply:SetLocalVelocity(Vector(0,0,0))

	return true
end
cmdSettings = {["Help"] = "Teleports you to your aimpoint"}
BAdmin.Utilities.addCommand("tp",callfunc,cmdSettings)

--======== Return to last position (from any teleport)

function callfunc(ply,args)
	if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end
	local LastLocation = ply:GetNWVector("BAdmin.ReturnPos",false)

	if LastLocation == false then return false, "You haven't teleported yet!" end

	ply:SetNWVector("BAdmin.ReturnPos",ply:GetPos())
	ply:SetPos(LastLocation)
	ply:SetLocalVelocity(Vector(0,0,0))

	return true
end
cmdSettings = {["Help"] = "Returns you to your last location"}
BAdmin.Utilities.addCommand("return",callfunc,cmdSettings)

--======== Teleport to a specific player

function callfunc(ply,args)
	if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end
	if args[1] == ply then return false,"You can't teleport to yourself!" end

	local dir = (args[1]:GetPos() - ply:GetPos()):GetNormalized()

	ply:SetNWVector("BAdmin.ReturnPos",ply:GetPos())
	ply:SetPos(args[1]:GetPos() - (dir * 64))
	ply:SetLocalVelocity(Vector(0,0,0))

	return true
end
cmdSettings = {
	["Help"] = "<target> - Teleports to the player.",
	["HasTarget"] = true,
	["CanTargetEqual"] = true
}
BAdmin.Utilities.addCommand("goto",callfunc,cmdSettings)

--======== Bring a specific player (admin +)

function callfunc(ply,args)
	if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end
	if args[1] == ply then return false,"You can't teleport to yourself!" end

	local dir = (ply:GetPos() - args[1]:GetPos()):GetNormalized()

	args[1]:SetNWVector("BAdmin.ReturnPos",args[1]:GetPos())
	args[1]:SetPos(ply:GetPos() - (dir * 64))
	args[1]:SetLocalVelocity(Vector(0,0,0))

	return true
end
cmdSettings = {
	["Help"] = "<target> - Brings the target to the player.",
	["HasTarget"] = true,
	["MinimumPrivilege"] = 1,
	["CanTargetEqual"] = true
}
BAdmin.Utilities.addCommand("bring",callfunc,cmdSettings)