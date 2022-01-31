if not BAdmin then BAdmin = {} end

local ranktable = {
    [0] = "user",
    [1] = "admin",
    [2] = "superadmin",
    [3] = "console"
}
local inverseRank = {
    ["user"] = 0,
    ["admin"] = 1,
    ["superadmin"] = 2,
    ["console"] = 3
}

if SERVER then
    MsgN("+----------START BADMIN----------+")

    BAdmin.Commands = {}
    BAdmin.Utilities = {}
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
        -- Utility functions
    ----------------------------------------------------------------------------------------------------------------

    local CanNoclip = GetConVar("sbox_noclip")
    local CanGodMode = CreateConVar("badmin_allowgodmode",1,FCVAR_ARCHIVE + FCVAR_NOTIFY,"[BOOLEAN] Whether to allow users use of !god",0,1)
    local AllowFamilySharing = CreateConVar("badmin_allowfamilyshare",1,FCVAR_ARCHIVE + FCVAR_NOTIFY,"[BOOLEAN] Whether to allow FamilyShare game licenses",0,1)
    local JailAutoBan = CreateConVar("badmin_jailautoban",15,FCVAR_ARCHIVE + FCVAR_NOTIFY,"[NUMBER] Ban the player if they leave before jailtime is up, for this amount of time in minutes",0)

    BAdmin.CVarList = {}
    local function addcvar(cvar)
        BAdmin.CVarList[#BAdmin.CVarList + 1] = cvar
    end
    addcvar("sbox_noclip")
    addcvar("badmin_allowgodmode")
    addcvar("badmin_allowfamilyshare")
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
    BAdmin.Utilities.cullBanList()

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

    --[[
        MinimumPrivilege        | 0-3, corresponds to privilege levels above
        CanTargetEqual          | Whether the player can target an equally ranked person
        IgnoreTargetPriv        | Ignores the above
        HasTarget               | The first argument is always a target, and will search for partial names
        Help                    | Text describing the command, for the autocomplete function
        RCONCanUse              | Whether or not RCon can safely use this command
    ]]

    MsgN("+ Adding commands...")
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

----------------------------------------------------------------------------------------------------------------
    -- Adding commands
----------------------------------------------------------------------------------------------------------------
    function callfunc(ply,args)
        if args[1] == ply then return false, "You can't use this on yourself, it's not safe!" end
        local rank = ""

        if tonumber(args[2]) != nil then rank = ranktable[math.floor(math.Clamp(tonumber(args[2]),0,2))] else rank = ranktable[inverseRank[args[2]]] or "user" end
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
        ["Help"] = " <target> - Sets the rank of the player (0-2) (user,admin,superadmin)",
        ["MinimumPrivilege"] = 2,
        ["HasTarget"] = true,
        ["CanTargetEqual"] = true,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("setrank",callfunc,cmdSettings)

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
        ["Help"] = " <target> - Gets the rank of the player.",
        ["MinimumPrivilege"] = 1,
        ["HasTarget"] = true,
        ["IgnoreTargetPriv"] = true,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("getrank",callfunc,cmdSettings)

    function callfunc(ply,args) -- votemap
        ply:ConCommand("votemap")
        return true
    end
    cmdSettings = {["Help"] = " - Opens the votemap menu"}
    BAdmin.Utilities.addCommand("votemap",callfunc,cmdSettings)

    function callfunc(ply,args) -- teleport
        if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end
        ply:SetNWVector("BAdmin.ReturnPos",ply:GetPos())
        ply:SetPos(ply:GetEyeTrace().HitPos)
        ply:SetLocalVelocity(Vector(0,0,0))
        return true
    end
    cmdSettings = {["Help"] = " - Teleports you to your aimpoint"}
    BAdmin.Utilities.addCommand("tp",callfunc,cmdSettings)

    function callfunc(ply,args) -- teleport
        if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end
        local LastLocation = ply:GetNWVector("BAdmin.ReturnPos",false)
        if LastLocation == false then return false, "You haven't teleported yet!" end
        ply:SetNWVector("BAdmin.ReturnPos",ply:GetPos())
        ply:SetPos(LastLocation)
        ply:SetLocalVelocity(Vector(0,0,0))
        return true
    end
    cmdSettings = {["Help"] = " - Returns you to your last location"}
    BAdmin.Utilities.addCommand("return",callfunc,cmdSettings)

    function callfunc(ply,args) -- goto
        if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end
        if args[1] == ply then return false,"You can't teleport to yourself!" end
        local dir = (args[1]:GetPos() - ply:GetPos()):GetNormalized()
        ply:SetNWVector("BAdmin.ReturnPos",ply:GetPos())
        ply:SetPos(args[1]:GetPos() - (dir * 64))
        ply:SetLocalVelocity(Vector(0,0,0))
        return true
    end
    cmdSettings = {
        ["Help"] = " <target> - Teleports to the player.",
        ["HasTarget"] = true,
        ["CanTargetEqual"] = true
    }
    BAdmin.Utilities.addCommand("goto",callfunc,cmdSettings)

    function callfunc(ply,args) -- bring
        if not CanNoclip:GetBool() and (BAdmin.Utilities.checkPriv(ply) == 0) then return false,"Teleporting is disabled! (Noclip disabled)" end
        if args[1] == ply then return false,"You can't teleport to yourself!" end
        local dir = (ply:GetPos() - args[1]:GetPos()):GetNormalized()
        args[1]:SetNWVector("BAdmin.ReturnPos",args[1]:GetPos())
        args[1]:SetPos(ply:GetPos() - (dir * 64))
        args[1]:SetLocalVelocity(Vector(0,0,0))
        return true
    end
    cmdSettings = {
        ["Help"] = " <target> - Brings the target to the player.",
        ["HasTarget"] = true,
        ["MinimumPrivilege"] = 1,
        ["CanTargetEqual"] = true
    }
    BAdmin.Utilities.addCommand("bring",callfunc,cmdSettings)

    function callfunc(ply,args) -- Help
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
        ["Help"] = " - Prints a list of all commands available to you",
        ["RCONCanUse"] = true}
    BAdmin.Utilities.addCommand("help",callfunc,cmdSettings)

    local slapSounds = {
        "physics/body/body_medium_impact_hard1.wav",
        "physics/body/body_medium_impact_hard2.wav",
        "physics/body/body_medium_impact_hard3.wav",
        "physics/body/body_medium_impact_hard5.wav",
        "physics/body/body_medium_impact_hard6.wav",
        "physics/body/body_medium_impact_soft5.wav",
        "physics/body/body_medium_impact_soft6.wav",
        "physics/body/body_medium_impact_soft7.wav",}

    function callfunc(ply,args) -- Slap
        if not args[1]:Alive() then return false, "The target is dead!" end

        args[1]:ExitVehicle()
        local num = math.Max(math.Round(tonumber(args[2] or 10)),1)
        local dmg = math.Max(math.Round(tonumber(args[2] or 0)),0)
        args[1]:ViewPunch(Angle(math.Min(-num / 5,25),0,0))

        if args[1]:GetMoveType() == MOVETYPE_NOCLIP then args[1]:SetMoveType(MOVETYPE_WALK) end

        args[1]:SetVelocity((Vector(0,0,30 * math.Rand(1,3)) + Vector(30 * math.Rand(-3,3),30 * math.Rand(-3,3),0)) * (num * 0.75))

        args[1]:EmitSound(slapSounds[math.random(#slapSounds)])

        timer.Simple(0.1,function() args[1]:SetHealth(args[1]:Health() - dmg) if args[1]:Health() < 1 then args[1]:Kill() end end)

        BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just slapped ",Color(255,127,127),args[1]:Nick(),Color(200,200,200),"!"})

        return true
    end
    cmdSettings = {
        ["Help"] = " <target> <health> - Slaps the taste out of someone.",
        ["HasTarget"] = true,
        ["CanTargetEqual"] = true,
        ["MinimumPrivilege"] = 1,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("slap",callfunc,cmdSettings)

    function callfunc(ply,args) -- Slay
        if not args[1]:Alive() then return false, "The target is already dead!" end

        args[1]:Kill()

        BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just slayed ",Color(255,127,127),args[1]:Nick(),Color(200,200,200),"!"})

        return true
    end
    cmdSettings = {
        ["Help"] = " <target> - Kills the target.",
        ["HasTarget"] = true,
        ["CanTargetEqual"] = true,
        ["MinimumPrivilege"] = 1,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("slay",callfunc,cmdSettings)

    function callfunc(ply,args) -- Kick
        local tgt = args[1]
        if IsValid(ply) and IsValid(tgt) and tgt == ply then return false, "You can't ban yourself!" end
        table.remove(args,1)
        local Reason = table.concat(args," ")
        tgt:Kick(Reason or "You were kicked.")

        BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just kicked ",Color(255,127,127),tgt:Nick(),Color(200,200,200),"!"})

        return true
    end
    cmdSettings = {
        ["Help"] = " <target> <reason> - Kicks the target.",
        ["HasTarget"] = true,
        ["CanTargetEqual"] = true,
        ["MinimumPrivilege"] = 1,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("kick",callfunc,cmdSettings)

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
        ["Help"] = " <target> <minutes (def. 1440)> - Bans the target. 0 for permanent",
        ["HasTarget"] = true,
        ["CanTargetEqual"] = false,
        ["MinimumPrivilege"] = 1,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("ban",callfunc,cmdSettings)

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
        ["Help"] = " <SteamID64> <minutes (def. 1440)> - Bans the SteamID. 0 for permanent",
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
        ["Help"] = " <SteamID64> - Unbans the SteamID.",
        ["MinimumPrivilege"] = 1,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("unban",callfunc,cmdSettings)

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
        ["Help"] = " <target (def. you)> <0-1 (def. toggles)> - Sets the player's godmode state.",
        ["HasTarget"] = true,
        ["CanTargetEqual"] = true,
        ["MinimumPrivilege"] = 0,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("god",callfunc,cmdSettings)

    function callfunc(ply,args) -- Observer cam

        if ply:GetObserverMode() != OBS_MODE_ROAMING then
            ply:Spectate(OBS_MODE_ROAMING)
            ply:StripWeapons()
        else
            ply:UnSpectate()
            ply:Spawn()
        end

        ply:SetNoTarget(ply:GetObserverMode() != OBS_MODE_NONE)
        return true
    end
    cmdSettings = {
        ["Help"] = " - Toggles state of observer cam.",
        ["MinimumPrivilege"] = 1,
    }
    BAdmin.Utilities.addCommand("obs",callfunc,cmdSettings)

    function callfunc(ply,args) -- Observer cam

        if args[1] == ply then
            if ply:GetObserverMode() != OBS_MODE_NONE then ply:SetObserverMode(OBS_MODE_NONE) ply:Spawn() return true else return false, "You can't spectate yourself!" end
        end

        if ply:GetObserverMode() == OBS_MODE_NONE then
            ply:Spectate((args[2] == "1" and OBS_MODE_CHASE) or OBS_MODE_IN_EYE)
            ply:SpectateEntity(args[1])
            ply:StripWeapons()
        elseif ply:GetObserverMode() != OBS_MODE_NONE then
            ply:Spectate((args[2] == "1" and OBS_MODE_CHASE) or OBS_MODE_IN_EYE)
            if ply:GetObserverTarget() != args[1] then ply:SpectateEntity(args[1]) end
        end

        ply:SetNoTarget(ply:GetObserverMode() != OBS_MODE_NONE)
        return true
    end
    cmdSettings = {
        ["Help"] = " <target> <(0-1) 1st/3rd person> - Spectates the target. Leave empty to reset.",
        ["HasTarget"] = true,
        ["IgnoreTargetPriv"] = true,
        ["CanTargetEqual"] = true,
        ["MinimumPrivilege"] = 1,
    }
    BAdmin.Utilities.addCommand("spec",callfunc,cmdSettings)

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
        ["Help"] = " - Freezes the entire map in props.",
        ["MinimumPrivilege"] = 2,
        ["RCONCanUse"] = true
    }
    BAdmin.Utilities.addCommand("freezemap",callfunc,cmdSettings)

    function callfunc(ply,args) -- Jail position
        BAdmin.Jail.JailPos = ply:GetPos()

        BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," set the jail position."})

        return true
    end
    cmdSettings = {
        ["Help"] = " - Sets the jail position.",
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

    function callfunc(ply,args) -- Jailing
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

----------------------------------------------------------------------------------------------------------------
    -- autocomplete networking
----------------------------------------------------------------------------------------------------------------
    MsgN("+ Finished adding commands!")

    util.AddNetworkString("BAdmin.commandList")
    util.AddNetworkString("BAdmin.requestCommands")
    local CMDList = table.GetKeys(BAdmin.Commands)
    local CMDData = {}
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

        CMDData[k] = Data
    end

    net.Receive("BAdmin.requestCommands",function(_,ply) -- also the first breathing moment the player can do anything
        BAdmin.Utilities.initialRank(ply)

        local FinalRank = (ply:IsListenServerHost() and "host") or BAdmin.UserList["id" .. ply:SteamID64()]
        BAdmin.Utilities.chatPrint(ply,{Color(200,200,200),"You have the rank of ",Color(255,127,127),FinalRank,Color(200,200,200)," here!"})
        net.Start("BAdmin.commandList")
            net.WriteTable(CMDList)
            net.WriteTable(CMDData)
        net.Send(ply)
    end)

    timer.Simple(0.5,function()
        net.Start("BAdmin.commandList")
            net.WriteTable(CMDList)
            net.WriteTable(CMDData)
        net.Broadcast()
    end)

    -- console command
    concommand.Add("bm",function(ply,_,arg)
        if not arg[1] then return end
        cmd = arg[1]
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

    hook.Add("StartChat","BAdmin.ChatAutocomplete",function() PlayerPriv = (inverseRank[LocalPlayer():GetNWString("UserGroup")] or 0) ChatOpen = true end)
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
                surface.SetTextColor(Color(255,255,127))
                surface.SetTextPos(LinePosX,LinePosY)
                local TextSizeX,_ = surface.GetTextSize("!" .. v)
                surface.DrawText("!" .. v)

                if CMDData[v]["help"] then
                    surface.SetTextPos(LinePosX + TextSizeX,LinePosY)
                    surface.SetTextColor(Color(200,200,200))
                    surface.DrawText(CMDData[v]["help"])
                end
            end
        else
            surface.SetTextPos(ChatX,ChatY - 24)
            surface.SetTextColor(Color(255,127,0))
            surface.DrawText("!help - Because it looks like you need it")
        end
    end)
end
