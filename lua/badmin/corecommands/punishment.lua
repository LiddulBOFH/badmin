-- Commands to aid in player abuse
local BAdmin = BAdmin

--======== Slap

local slapSounds = {
	"physics/body/body_medium_impact_hard1.wav",
	"physics/body/body_medium_impact_hard2.wav",
	"physics/body/body_medium_impact_hard3.wav",
	"physics/body/body_medium_impact_hard5.wav",
	"physics/body/body_medium_impact_hard6.wav",
	"physics/body/body_medium_impact_soft5.wav",
	"physics/body/body_medium_impact_soft6.wav",
	"physics/body/body_medium_impact_soft7.wav",
}

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
	["Help"] = "<target> <health> - Slaps the taste out of someone.",
	["HasTarget"] = true,
	["CanTargetEqual"] = true,
	["MinimumPrivilege"] = 1,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("slap",callfunc,cmdSettings)

--======== Slay

function callfunc(ply,args)
	if not args[1]:Alive() then return false, "The target is already dead!" end

	args[1]:Kill()

	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," just slayed ",Color(255,127,127),args[1]:Nick(),Color(200,200,200),"!"})

	return true
end
cmdSettings = {
	["Help"] = "<target> - Kills the target.",
	["HasTarget"] = true,
	["CanTargetEqual"] = true,
	["MinimumPrivilege"] = 1,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("slay",callfunc,cmdSettings)