if SERVER then
	local MapVoteCVar = CreateConVar("badmin_enablemapvote",1,{FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED},"[BOOLEAN] Enable/disable the map voting system, in case a gamemode has one built in.",0,1)

	local maps = {}
	local mastermap = {}
	local votees = {}
	local VotedMaps = {}
	local FinalVoting = false
	local LockVote = false
	local LockTime = 0
	local WinningMap = ""

	-- Add specific names, without * to add specific maps
	local mapprefix = {"*"}

	-- Map gathering
	-- To add on, take "mastermap" and move up another int
	-- Then use a new path/filter
	for I = 1, #mapprefix, 1 do
		local Ind = (I-1) * 2
		local Prefix = mapprefix[I]
		mastermap[1 + Ind] = file.Find("maps/" .. Prefix .. ".bsp","WORKSHOP")
		mastermap[2 + Ind] = file.Find("maps/" .. Prefix .. ".bsp","GAME")
		mastermap[3 + Ind] = file.Find("maps/" .. Prefix .. ".bsp","MOD")
	end

	local PreMapsTable = {}
	for I = 1, #mastermap, 1 do
		local MapTable = mastermap[I]
		for O = 1,#MapTable,1 do
			local Key = string.Replace(mastermap[I][O],".bsp","")
			PreMapsTable[Key] = 0
		end
	end

	--print("MAPS: " .. table.Count(PreMapsTable))
	--PrintTable(PreMapsTable,1)

	local MapKeys = table.GetKeys(PreMapsTable)
	for I = 1,table.Count(PreMapsTable),1 do
		local Key = MapKeys[I]
		maps[I] = Key
	end
	table.sort(maps)

	-- Network stuff
	util.AddNetworkString("votemap_derma")
	util.AddNetworkString("cl_votemap")
	util.AddNetworkString("cl_remove_votemap")
	util.AddNetworkString("ply_msg")
	util.AddNetworkString("vote_count")
	util.AddNetworkString("admin_veto")
	util.AddNetworkString("admin_forcemap")
	util.AddNetworkString("admin_forcemap_instant")
	util.AddNetworkString("update")

	  -- Concommand
	concommand.Add("votemap",function(ply)
		if not MapVoteCVar:GetBool() then return end

		net.Start("votemap_derma")
			net.WriteTable(maps)
		net.Send(ply)
	end)

	net.Receive("admin_forcemap",function(_, ply)
		if not MapVoteCVar:GetBool() then return end

		local Map = net.ReadString()

		PlyMsg("An admin has forced a map change (" .. Map .. "), save up! (30 seconds)")

		timer.Create("changemap",30,1,function()
			game.ConsoleCommand("changelevel " .. Map .. "\n")
		end)

		FinalVoting = true
		LockTime = CurTime()
		LockVote = true
		net.Start("update")
			net.WriteBool(LockVote or false)
			net.WriteFloat(LockTime or 0)
		net.Broadcast()
	end)

	net.Receive("admin_forcemap_instant",function(_, ply)
		if not MapVoteCVar:GetBool() then return end

		local Map = net.ReadString()
		game.ConsoleCommand("changelevel " .. Map .. "\n")
		PlyMsg("Ready or not, here we go to (" .. Map .. ")!")
	end)

	function PlyMsg(msg)
		net.Start("ply_msg")
			net.WriteString(msg)
		net.Broadcast()
	end

	function Tie(Table)
		local High = table.GetWinningKey(Table)
		local TieCount = table.KeysFromValue(Table,High)

		if #TieCount > 1 then
			return TieCount[table.Random(table.GetKeys(TieCount))]
		else
			return High
		end
	end

	-- Receiving netcode
	net.Receive("admin_veto",function(_,ply)
		if FinalVoting then
			PlyMsg("An admin has canceled the votemap!")

			FinalVoting = false
			LockVote = false
			timer.Stop("changemap")
			timer.Stop("lockvote")
			votees = {}
			VotedMaps = {}

			net.Start("update")
				net.WriteBool(LockVote or false)
				net.WriteFloat(LockTime or 0)
			net.Broadcast()
		else
			net.Start("ply_msg")
				net.WriteString("No vote currently running.")
			net.Send(ply)
		end
	end)

	function PlayerDisconnected(ply)
		if votees[ply:SteamID()] != "" then
			table.remove(votees,ply:SteamID())
		end

		VotedMaps = {}
		for I = 1, table.Count(votees), 1 do
			local key = table.GetKeys(votees)[I]
			local LN = VotedMaps[votees[key]] or 0
			VotedMaps[votees[key]] = LN + 1
		end
		table.sort(VotedMaps)

		CountVotes()
	end

	net.Receive("cl_votemap",function(_,ply)
		if not MapVoteCVar:GetBool() then return end

		if LockVote == false then
		local voted_map = net.ReadString()
		votees[ply:SteamID()] = voted_map

		VotedMaps = {}
		for I = 1, table.Count(votees), 1 do
			local key = table.GetKeys(votees)[I]
			local LN = VotedMaps[votees[key]] or 0
			VotedMaps[votees[key]] = LN + 1
		end
		table.sort(VotedMaps)

		PlyMsg(ply:Nick() .. " voted for " .. voted_map .. ". (" .. math.Round((VotedMaps[voted_map] / table.Count(VotedMaps)) * 100) .. "%/100%)")

		CountVotes()
		else
			net.Start("ply_msg")
				net.WriteString("Voting is locked!")
			net.Send(ply)
		end
	end)

	function CountVotes()
		if not MapVoteCVar:GetBool() then return end

		if (table.Count(VotedMaps) >= math.ceil((2 / 3) * #player.GetAll())) and not FinalVoting then
			PlyMsg("Minimum votes reached! Lock in 30 seconds.")

			net.Start("vote_count")
			net.Broadcast()

			WinningMap = Tie(VotedMaps)
			timer.Create("lockvote",30,1,function()
				PlyMsg("Votes locked! Map: '" .. (WinningMap or "") .. "' in 30 seconds. Save up!")

				LockTime = CurTime()
				LockVote = true

				net.Start("update")
					net.WriteBool(LockVote or false)
					net.WriteFloat(LockTime or 0)
				net.Broadcast()
			end)
			timer.Start("lockvote")

			timer.Create("changemap",60,1,function()
				game.ConsoleCommand("changelevel " .. WinningMap .. "\n")
			end)
			timer.Start("changemap")

			FinalVoting = true
		end
	end
else
	local MapVoteCVar = CreateConVar("badmin_enablemapvote","1",{FCVAR_REPLICATED},"[BOOLEAN] Enable/disable the map voting system, in case a gamemode has one built in.",0,1)

	function Votemap(Maps) -- Ze magicks
		local SelectedMap = ""
		surface.PlaySound("garrysmod/ui_return.wav")
		local SW = ScrW()
		local U = SW / 12

		local p = vgui.Create("DFrame") -- Base panel
		p:SetSize(U * 2.45,U * 3)
		p:SetTitle("Votemap")
		p:SetVisible(true)
		p:Center()
		p:MakePopup()
		p:DoModal()
		p:SetDraggable(false)

		local mlist = vgui.Create("DListView",p) -- List of maps
		mlist:SetMultiSelect(false)
		mlist:AddColumn("Maps")
		mlist:SetSize(U * 1,U * 2.75)
		mlist:SetPos(U * 0.05,U * 0.2)

		local pic = vgui.Create("DImage",p) -- Map picture
		pic:SetPos(U * 1.1,U * 0.2)
		pic:SetSize(U * 1.25,U * 1.25)
		pic:SetImage("materials/gui/noicon.png")

		local map_n = vgui.Create("DLabel",pic) -- Map name label
		map_n:SetText("")
		map_n:SetPos(U * 0.05,U * 1.25 * 0.9)
		map_n:SetBright(true)
		map_n:SetWidth(U)

		local votebut = vgui.Create("DButton",p) -- Voting button
		votebut:SetPos(U * 1.1,U * 2.5)
		votebut:SetSize(U * 1.25,U / 3)
		votebut:SetText("Vote map!")
		votebut:SetDisabled(true)
		function votebut:DoClick()
			votebut:SetDisabled(true)

			net.Start("cl_votemap")
			net.WriteString(SelectedMap)
			net.SendToServer()
		end

		if LocalPlayer():IsAdmin() then
			local vetobut = vgui.Create("DButton",p) -- Vetoing button
			vetobut:SetPos(U * 1.1,U * 2.1)
			vetobut:SetSize(U * 1.25,U / 3)
			vetobut:SetText("Cancel votemap")

			function vetobut:DoClick()
				net.Start("admin_veto")
				net.SendToServer()
			end

			local forcebut = vgui.Create("DButton",p) -- Forcemap button
			forcebut:SetPos(U * 1.1,U * 1.7)
			forcebut:SetSize(U * 1.25,U / 3)
			forcebut:SetText("Force map (LSHIFT: INSTANT)")

			function forcebut:DoClick()
				if SelectedMap != "" then
					if not input.IsKeyDown(KEY_LSHIFT) then
						net.Start("admin_forcemap")
							net.WriteString(SelectedMap)
						net.SendToServer()
					else
						net.Start("admin_forcemap_instant")
							net.WriteString(SelectedMap)
						net.SendToServer()
					end
				else
					LocalPlayer():ChatPrint("Select a map!")
				end
			end
		end

		mlist.DoDoubleClick = function(Line,ID)
			MapS = mlist:GetSelected()[1]:GetColumnText(1)
			local path = file.Exists("maps/" .. MapS .. ".png","GAME")
			local path2 = file.Exists("maps/" .. MapS .. ".png","WORKSHOP")

			if path == true or path2 == true then
				pic:SetImage("maps/" .. MapS .. ".png")
			else
				pic:SetImage("materials/gui/noicon.png")
			end

			surface.PlaySound("garrysmod/ui_click.wav")

			SelectedMap = MapS
			map_n:SetText(MapS)
			if votebut:GetDisabled() == true then votebut:SetDisabled(false) end
		end

		for I = 1, #maps, 1 do
			local ind = maps[I]
			mlist:AddLine(ind)
		end
	end

	local LockVote = false
	local LockTime = 0

	local Panic = {}
	net.Receive("update",function()
		if not MapVoteCVar:GetBool() then return end

		LockVote = net.ReadBool()
		LockTime = net.ReadFloat()

		LocalPlayer():StopSound("ambient/alarms/siren.wav")
		if LockVote then LocalPlayer():EmitSound("ambient/alarms/siren.wav") end
		Panic = {}
	end)

	-- PanicWords[#PanicWords + 1] = ""
	local PanicWords = {}
	PanicWords[#PanicWords + 1] = "Hurry up!"
	PanicWords[#PanicWords + 1] = "You forgot a clip!"
	PanicWords[#PanicWords + 1] = "DUPE IT QUICKLY!"
	PanicWords[#PanicWords + 1] = "OH NO IT DIDN'T SAVE!"
	PanicWords[#PanicWords + 1] = "AAAAAAAAAAAAAAAAAAAA"
	PanicWords[#PanicWords + 1] = "The mesh isn't finished!"
	PanicWords[#PanicWords + 1] = "EEEEEEEEEEEE"
	PanicWords[#PanicWords + 1] = "OH THE HORROR"
	PanicWords[#PanicWords + 1] = "Bet you're gonna lose something..."
	PanicWords[#PanicWords + 1] = "ARE YOU AFK OR WHAT"
	PanicWords[#PanicWords + 1] = "COME ON MAN"
	PanicWords[#PanicWords + 1] = "GORDON FREEMAN"
	PanicWords[#PanicWords + 1] = "HOW COULD YOU LET THIS HAPPEN"
	PanicWords[#PanicWords + 1] = "YOU WERE SUPPOSED TO SAVE US"
	PanicWords[#PanicWords + 1] = "AAGGGHHHH"
	PanicWords[#PanicWords + 1] = "OH MY GOD OH MY GOD OH MY GOD"
	PanicWords[#PanicWords + 1] = "RDM RDM RDM RDM RDM"
	PanicWords[#PanicWords + 1] = "ADMIN2MEEEE"
	PanicWords[#PanicWords + 1] = "REEEEEEEEEE"
	PanicWords[#PanicWords + 1] = "KEEP YOUR MIND ON YOUR WORK"
	PanicWords[#PanicWords + 1] = "Well how about that"
	PanicWords[#PanicWords + 1] = "Try not to let it get to you"
	PanicWords[#PanicWords + 1] = "What am I supposed to do about it?"
	PanicWords[#PanicWords + 1] = "There's a first time for everything..."
	PanicWords[#PanicWords + 1] = "That's enough out of you!"
	PanicWords[#PanicWords + 1] = "You sure about that?"
	PanicWords[#PanicWords + 1] = "WE TRUSTED YOU"
	PanicWords[#PanicWords + 1] = "How could this happen?!"
	PanicWords[#PanicWords + 1] = "Oh no..."
	PanicWords[#PanicWords + 1] = "No.. NO.. NOOO!"
	PanicWords[#PanicWords + 1] = "ADMIN WHY IS THIS HAPPENING"
	PanicWords[#PanicWords + 1] = "WHAT ARE THESE NOISES"
	PanicWords[#PanicWords + 1] = "AAAAAAAAAAAAA"
	PanicWords[#PanicWords + 1] = "NOOOOOOO"
	PanicWords[#PanicWords + 1] = "Just a few more props...."

	-- PanicSounds[#PanicSounds + 1] = ""
	local PanicSounds = {}
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/finally.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/fantastic02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/gordead_ans01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/gordead_ans02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/gordead_ans04.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/gordead_ans06.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/gordead_ans10.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/gordead_ans14.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/female01/gordead_ans01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/female01/gordead_ans02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/female01/gordead_ans04.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/female01/gordead_ans06.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/female01/gordead_ans10.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/female01/gordead_ans14.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/barney/ba_hurryup.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/barney/ba_lookout.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/barney/ba_no02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/barney/ba_ohshit03.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/barney/ba_damnit.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/barney/ba_danger02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/hacks01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/headsup02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/help01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/heretohelp01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/heretohelp02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/letsgo01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/likethat.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/no02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/no01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/notthemanithought01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/ohno.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/question02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/question04.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/question05.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/question11.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/question16.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/question20.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/question22.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/runforyourlife01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/squad_affirm06.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/startle02.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/startle01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/stopitfm.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/thehacks01.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/uhoh.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/waitingsomebody.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/watchwhat.wav"
	PanicSounds[#PanicSounds + 1] = "vo/npc/male01/wetrustedyou01.wav"

	local function AddPanic()
		local Data = {}

		local id = tostring(math.random(1000)) .. "_" .. tostring(math.random(2000)) .. "_panictimer"

		Data["time"] = CurTime()
		Data["text"] = PanicWords[math.random(1,#PanicWords)]
		Data["x"] = math.Rand(0,1)
		Data["y"] = math.Rand(0,1)
		Data["wobble"] = math.random(0,10) > 4
		Data["wobblescale"] = math.Rand(0.8,1.8)
		Data["scalemod"] = math.Rand(0.8,1.6)

		timer.Simple(math.Rand(2,6),function()
			Panic[id] = nil
		end)

		Panic[id] = Data
	end

	local NextPanic = CurTime()
	local NextPanicSound = CurTime()
	local Red = Color(255,0,0)
	hook.Add("HUDPaint","SaveUpMan",function()
		if LockVote then
			local X,Y = ScrW(),ScrH()

			surface.SetDrawColor(ColorAlpha(Red,math.abs(math.sin(CurTime() * 0.5)) * 35))
			surface.DrawRect(0,0,X,Y)

			draw.RoundedBox(4,(X / 2) - ((X / 12) * 2 / 2),(Y * 0.3) - 6,(X / 12) * 2,28,Color(25,25,25,200))
			draw.DrawText("SAVE UP! Time till map change: " .. math.Round(((LockTime or 0) + 30) - CurTime(),1) .. "s","ChatFont",X / 2,Y * 0.3,Color(255,125,125,255),TEXT_ALIGN_CENTER)

			if CurTime() > NextPanic then
				NextPanic = CurTime() + math.Rand(0.4,2.5)
				AddPanic()
			end

			if CurTime() > NextPanicSound then
				NextPanicSound = CurTime() + math.Rand(1.5,4)
				LocalPlayer():EmitSound(PanicSounds[math.random(1,#PanicSounds)],_,120 + math.random(-20,10))
			end

			for k,v in pairs(Panic) do
				local S = math.abs(math.sin((CurTime() - v["time"]) * 1) * 1.7 * v["scalemod"]) + 0.75
				--local color = LerpVector(math.abs(math.sin((CurTime() - v["time"]) * 2)),Vector(255,0,0),Vector(255,255,255))

				local m = Matrix()
				local Pos = Vector(X * v["x"],Y * v["y"], 0)
				m:Translate(Pos)
				m:Scale(Vector(S,S,0))
				m:Rotate(Angle(0,v["wobble"] and (math.sin((CurTime() - v["time"]) * 2 * v["wobblescale"]) * 30) or 0,0))
				m:Translate(-Pos)

				cam.PushModelMatrix(m)
					draw.SimpleTextOutlined(v["text"],"ChatFont",Pos.x,Pos.y,Red,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(75,75,75))
				cam.PopModelMatrix()
			end
		end
	end)

	net.Receive("votemap_derma",function() -- Initial votemap loading
		if not MapVoteCVar:GetBool() then return end

		maps = net.ReadTable()
		--print("Received maps! Maps: "..#maps)
		Votemap(maps)
	end)

	net.Receive("ply_msg",function() -- Something to bounce messages with
		local msg = net.ReadString()
		LocalPlayer():ChatPrint(msg)
	end)

	net.Receive("vote_count",function()
		surface.PlaySound("buttons/button17.wav")
	end)
end
