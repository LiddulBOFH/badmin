local BAdmin = BAdmin

MsgN("+ Loading ban system...")

-- Framework for ban system

local AllowFamilySharing = GetConVar("badmin_allowfamilyshare")

----------------------------------------------------------------------------------------------------------------
	-- Setup ban list
----------------------------------------------------------------------------------------------------------------

if file.Exists("badmin/bans","DATA") then
	MsgN("+ Ban directory found!")
	local Bans = file.Find("badmin/bans/*.txt","DATA")
	MsgN("- " .. #Bans .. " ban(s) currently saved!")
else
	MsgN("| No ban directory, starting fresh...")
	file.CreateDir("badmin/bans")
	MsgN("+ Ban directory created!")
end

----------------------------------------------------------------------------------------------------------------
	-- Ban functions
----------------------------------------------------------------------------------------------------------------

function BAdmin.Utilities.addBan(id,time,ip_optional,reason)
	local Data = {}

	local FinalID = BAdmin.Utilities.safeID(id)
	if FinalID == "INVALID" then return end
	local Ply = player.GetBySteamID64(FinalID)
	if Ply != false then Ply:Kick("You just got banned for " .. string.NiceTime(math.ceil(time) * 60) .. "!\nReason: " .. (reason or "No reason specified.")) end

	if time == 0 then Data["perm"] = true else Data["time"] = os.time() + (math.ceil(time) * 60) end
	if ip_optional != nil then Data["ip"] = ip_optional RunConsoleCommand("addip",ip_optional) end
	if reason then Data["reason"] = reason end

	BAdmin.Utilities.updateRank(FinalID,"")

	file.Write("badmin/bans/" .. FinalID .. ".txt",util.TableToJSON(Data))
end

function BAdmin.Utilities.removeBan(id)
	local SafeID = BAdmin.Utilities.safeID(id)
	if SafeID == "INVALID" then return false,"Invalid ID!" end

	if not file.Exists("badmin/bans/" .. SafeID .. ".txt","DATA") then return false,SafeID .. " is not banned!"
	else
		local File = "badmin/bans/" .. SafeID .. ".txt"
		local Data = util.JSONToTable(file.Read(File))
		if Data["ip"] then RunConsoleCommand("removeip",Data["ip"]) end
		file.Delete(File)
		return true,id .. " has been unbanned"
	end
end

function BAdmin.Utilities.updateBan(id,ip)
	local SafeID = BAdmin.Utilities.safeID(id)
	local Data = util.JSONToTable(file.Read("badmin/bans/" .. SafeID .. ".txt","DATA"))
	local Change = false
	--local TimeLeft = (Data["time"] - os.time()) / 60

	if not Data["ip"] then
		RunConsoleCommand("addip",ip)
		Data["ip"] = ip
		Change = true
	else
		if Data["ip"] == ip then return
		else
			RunConsoleCommand("removeip",Data["ip"])
			RunConsoleCommand("addip",ip)
			Data["ip"] = ip
			Change = true
		end
	end

	if Change then file.Write("badmin/bans/" .. SafeID .. ".txt",util.TableToJSON(Data)) end
end

function BAdmin.Utilities.checkBan(id)
	local SafeID = BAdmin.Utilities.safeID(id)
	if not file.Exists("badmin/bans/" .. SafeID .. ".txt","DATA") then return false,"Player is not banned"
	else
		local Data = util.JSONToTable(file.Read("badmin/bans/" .. SafeID .. ".txt","DATA"))
		if Data["perm"] == true or false then return true,"Banned!\nTime left: Permanent!\nReason: " .. (Data["reason"] or "No reason specified.") end

		if Data["time"] > os.time() then return true,"Banned!\nTime left: " .. string.NiceTime(Data["time"] - os.time()) .. "\nReason: " .. (Data["reason"] or "No reason specified.") else
			if Data["ip"] then RunConsoleCommand("removeip",Data["ip"]) end
			file.Delete("badmin/bans/" .. SafeID .. ".txt")
			return false,"Player is not banned"
		end
	end
end

function BAdmin.Utilities.cullBanList()
	local BanList = file.Find("badmin/bans/*.txt","DATA")

	for i = 1,#BanList,1 do
		local File = BanList[i]
		local Data = util.JSONToTable(file.Read("badmin/bans/" .. File,"DATA"))

		if Data["perm"] == true then continue end
		if Data["time"] < os.time() then
			MsgN("Culled " .. File .. " from ban list...")
			if Data["ip"] then RunConsoleCommand("removeip",Data["ip"]) end
			file.Delete("badmin/bans/" .. File)
		end
	end
end

-- Using #GameUI strings helps keep the messages multilingual (uses the localization file for the client)
function BAdmin.Utilities.CheckConnection(id,ip,svpass,clpass,name)
	if (svpass and svpass != "") and (clpass != svpass) then return false,"#GameUI_ServerRejectBadPassword" end

	local IsBanned,Reason = BAdmin.Utilities.checkBan(id)
	if IsBanned then return false,Reason end
end

hook.Add("PlayerAuthed","BAdmin.PlayerAuth",function(ply,id,id64)
	if AllowFamilySharing:GetBool() == false then
		local LicenseHolder = ply:OwnerSteamID64()
		if LicenseHolder != util.SteamIDTo64(id) then ply:Kick("This server is not allowing FamilyShared copies of the game!") return end
	end

	local IsBanned,Reason = BAdmin.Utilities.checkBan(ply:OwnerSteamID64())
	if IsBanned then ply:Kick(Reason) return end
end)