local BAdmin = BAdmin
-- Framework for command system

MsgN("+ Loading command system...")

--[[ Variables for the commands
	MinimumPrivilege        | 0 - User (anyone, also is default if this is left out), 1 - Admin, 2 - Superadmin, 3 - RCON or Host of localhost server
	CanTargetEqual          | Whether the player can target an equally ranked person
	IgnoreTargetPriv        | Ignores the above
	HasTarget               | The first argument is always a target, and will search for partial names
	Help                    | Text describing the command, for the autocomplete function
	RCONCanUse              | Whether or not RCon can safely use this command, must be present and true to allow
]]

--[[ Example command, taken from plymgmt.lua

	-- This is the function that will run, providing the calling player, and any arguments passed to it
	function callfunc(ply,args) -- Kick
		local tgt = args[1]
		if IsValid(ply) and IsValid(tgt) and tgt == ply then return false, "You can't kick yourself!" end
		table.remove(args,1)
		local Reason = table.concat(args," ")
		tgt:Kick(Reason or "You were kicked.")

		BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just kicked ",Color(255,127,127),tgt:Nick(),Color(200,200,200),"!"})

		return true
	end

	-- These are the settings attached to the command, using the table above as a reference
	cmdSettings = {
		["Help"] = " <target> <reason> - Kicks the target.",
		["HasTarget"] = true,
		["CanTargetEqual"] = true,
		["MinimumPrivilege"] = 1,
		["RCONCanUse"] = true
	}

	-- This calls the built-in function to create the command, where it can be seen with autocomplete and usable by the approriate players
	BAdmin.Utilities.addCommand("kick",callfunc,cmdSettings)

]]

function BAdmin.Utilities.addCommand(cmdString,func,settings)
	local CMDData = {}

	table.Merge(CMDData,settings)
	CMDData["func"] = func

	MsgN("| Added " .. cmdString)
	BAdmin.Commands[cmdString] = CMDData
end

function BAdmin.Utilities.runCommand(ply,cmd,args)
	local CMDData = BAdmin.Commands[cmd]
	local IsRCON = not IsValid(ply)

	if not CMDData["RCONCanUse"] and IsRCON then
		return false, "RCON can't use this command!"
	end

	if CMDData["MinimumPrivilege"] and not IsRCON then -- stop them at the gate! Checks if the user can even use this permission, skipped if its RCON
		local plyPriv = BAdmin.Utilities.checkPriv(ply)
		if plyPriv < CMDData["MinimumPrivilege"] then return false, "Insufficient privileges! (You: " .. plyPriv .. ", requires: " .. CMDData["MinimumPrivilege"] .. " )" end
	end

	if CMDData["HasTarget"] then -- Finds a target for a targetted command, and if none is given, substitute with the calling player
		if (not args[1]) or (args[1] == "^") then
			if not IsRCON then args[1] = ply else return false,"RCON can't target itself!" end
		else
			local target = nil
			for k,v in ipairs(player.GetAll()) do
				if string.find(string.lower(v:Nick()),string.lower(args[1])) then -- find the first occurence of the name
					target = v break
				elseif string.find(v:SteamID64(),args[1]) then -- matching steam IDs too
					target = v break
				end
			end

			if IsValid(target) then args[1] = target else return false,"No target named \"" .. args[1] .. "\" found!" end

			local plyPriv = (IsRCON and 3) or BAdmin.Utilities.checkPriv(ply)
			local targPrivLevel = BAdmin.Utilities.checkPriv(args[1])

			if ply != args[1] then -- if you are still trying to target yourself, why stop you now
				if CMDData["CanTargetEqual"] == true then -- if the command can be used on equal ranks
					if (plyPriv < targPrivLevel) and not (CMDData["IgnoreTargetPriv"] or false) then return false, args[1]:Nick() .. " (" .. targPrivLevel .. ") is immune to this command from you (" .. plyPriv .. ")!" end
				else -- otherwise it can NOT be used on equal ranks
					if (plyPriv <= targPrivLevel) and not (CMDData["IgnoreTargetPriv"] or false) then return false, args[1]:Nick() .. " (" .. targPrivLevel .. ") is immune to this command from you (" .. plyPriv .. ")!\n(Can't target equal ranks with this command)" end
				end
			end
		end
	end

	return CMDData.func(ply,args)
end

function BAdmin.Utilities.filterCommand(msg)
	local text = string.Trim(msg)
	text = string.sub(text,2)
	local argList = string.Explode(" ",text)
	local cmd = string.lower(argList[1])
	table.remove(argList,1)

	return cmd, argList
end

-- Important command
-- Yes, a command that is made before any of the other commands

function callfunc(ply,args) -- Reload ALL commands command
	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just reloaded all of the commands!"})

	MsgN("+ BAdmin file reload commencing")

	include("autorun/badmin_init.lua")

	MsgN("+ File reload complete!")

	return true
end

-- These are the settings attached to the command, using the table above as a reference
cmdSettings = {
	["Help"] = "Reload ALL of BAdmin.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}

-- This calls the built-in function to create the command, where it can be seen with autocomplete and usable by the approriate players
BAdmin.Utilities.addCommand("@@ba_reload",callfunc,cmdSettings)


--- Individual reload list
function callfunc(ply,args) -- Prints all of the files able to be reloaded
	local filelist = ""

	for k,v in pairs(BAdmin.Utilities.fileTrack) do
		filelist = filelist .. k .. ", "
	end

	BAdmin.Utilities.chatPrint(ply,{Color(200,200,200),"Files able to be reloaded: ",Color(255,255,127),filelist})

	return true
end
cmdSettings = {
	["Help"] = "Lists all of the files able to be reloaded.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("@@ba_indreloadlist",callfunc,cmdSettings)


--- Individual reload command
function callfunc(ply,args) -- Reload one command file

	if not BAdmin.Utilities.fileTrack[args[1]] then
		return false, args[1] .. " is not a valid file!"
	else
		BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just reloaded " .. args[1] .. ".lua!"})
		include(BAdmin.Utilities.fileTrack[args[1]])

		BAdmin.Autocomplete.build()
		BAdmin.Autocomplete.broadcast()
	end

	return true
end
cmdSettings = {
	["Help"] = "Reload one file of BAdmin.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("@@ba_indreload",callfunc,cmdSettings)