-- Miscellaneous commands that prove useful
local BAdmin = BAdmin

--======== Observer camera (untargetted, free camera)

function callfunc(ply,args)
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
	["Help"] = "Toggles state of observer cam.",
	["MinimumPrivilege"] = 1,
}
BAdmin.Utilities.addCommand("obs",callfunc,cmdSettings)

--======== Player spectate (targetted)

function callfunc(ply,args)
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
	["Help"] = "<target> <(0-1) 1st/3rd person> - Spectates the target. Leave empty to reset.",
	["HasTarget"] = true,
	["IgnoreTargetPriv"] = true,
	["CanTargetEqual"] = true,
	["MinimumPrivilege"] = 1,
}
BAdmin.Utilities.addCommand("spec",callfunc,cmdSettings)