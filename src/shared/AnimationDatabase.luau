-- AnimationDatabase.luau  (ModuleScript — ReplicatedStorage)
--
-- 🎬 ระบบ 3 ชั้น (Layer):
--   1. Locomotion   — ขา/การเคลื่อนที่  (Priority.Movement)
--   2. WeaponPose   — แขนถือปืน (ท่อนบน)   (Priority.Action, blend ทับ Movement)
--   3. Action       — ยิง/reload/equip     (Priority.Action2/3)
--
-- ✅ เพิ่มท่า = เติม ID ในตารางนี้ที่เดียว
-- ✅ เว้นว่าง "" ได้ ระบบ fallback ให้เอง
-------------------------------------------------------------

local AnimationDatabase = {}

-- ═══════════════════════════════════════════════
--  LAYER CONFIG — priority / blend weights
--  Movement < Action: locomotion คุมขา, weapon pose ทับท่อนบน
-- ═══════════════════════════════════════════════
AnimationDatabase.Layers = {
	Locomotion = {
		Priority = Enum.AnimationPriority.Movement,
		Looped   = true,
		Weight   = 1,
		FadeTime = 0.18,
	},
	WeaponPose = {
		Priority = Enum.AnimationPriority.Action,
		Looped   = true,
		Weight   = 0.85, -- partial blend — ขาจาก Movement ยังขยับได้
		FadeTime = 0.22,
		Enabled  = true,
	},
	Action = {
		Priority = Enum.AnimationPriority.Action2,
		Looped   = false,
		Weight   = 1,
		FadeTime = 0.08,
	},
	ActionHigh = {
		Priority = Enum.AnimationPriority.Action3,
		Looped   = false,
		Weight   = 1,
		FadeTime = 0.08,
	},
}

-- ═══════════════════════════════════════════════
--  LAYER 1 — LOCOMOTION (R15 default — verified Animate IDs)
-- ═══════════════════════════════════════════════
AnimationDatabase.Locomotion = {
	Stand = {
		Idle = "rbxassetid://507766666",   -- R15 idle
		Walk = "rbxassetid://507777826",   -- R15 walk (blendable)
		Run  = "rbxassetid://507767714",   -- R15 run
	},
	-- Placeholder: ใช้ท่า Stand จนกว่าจะมี crouch/prone anim จริง
	Crouch = {
		Idle = "rbxassetid://507766666",
		Walk = "rbxassetid://507777826",
		Run  = "rbxassetid://507777826",   -- crouch ไม่วิ่ง — fallback walk
	},
	Prone = {
		Idle = "rbxassetid://507766666",
		Walk = "rbxassetid://507777826",   -- crawl placeholder
		Run  = "rbxassetid://507777826",
	},
	Jump  = "rbxassetid://507765000",
	Fall  = "rbxassetid://507767968",
	Climb = "rbxassetid://507765644",
}

AnimationDatabase.BlendableLocomotion = {
	["rbxassetid://507766666"] = true,
	["rbxassetid://507777826"] = true,
	["rbxassetid://507767714"] = true,
	["rbxassetid://507765000"] = true,
	["rbxassetid://507767968"] = true,
	["rbxassetid://507765644"] = true,
}

-- ═══════════════════════════════════════════════
--  LAYER 2 + 3 — WEAPON SETS
-- ═══════════════════════════════════════════════
AnimationDatabase.Weapons = {
	rifle = {
		Pose   = "rbxassetid://17747384020",
		Shoot  = "rbxassetid://17747381445",
		Reload = "rbxassetid://17747385966",
		Equip  = "",
		Aim    = "",
	},
	pistol = {
		Pose   = "rbxassetid://17747125537",
		Shoot  = "rbxassetid://17747128593",
		Reload = "rbxassetid://17747123905",
		Equip  = "",
		Aim    = "",
	},
	knife = {
		Pose   = "",
		Shoot  = "",
		Reload = "",
		Equip  = "",
		Aim    = "",
	},
}

AnimationDatabase.ViewModels = {
	rifle = {
		Idle   = "rbxassetid://17649922695",
		Shoot  = "rbxassetid://17649937140",
		Reload = "rbxassetid://17649942928",
		Equip  = "rbxassetid://17649933851",
	},
	pistol = {
		Idle   = "rbxassetid://17650466245",
		Shoot  = "rbxassetid://17650473461",
		Reload = "rbxassetid://17650688812",
		Equip  = "rbxassetid://17650548633",
	},
}

AnimationDatabase.SetMap = {
	rifle   = "rifle",
	shotgun = "rifle",
	pistol  = "pistol",
	knife   = "knife",
	ak      = "rifle",
	smg     = "rifle",
	sniper  = "rifle",
	lmg     = "rifle",
}

function AnimationDatabase.GetSetKey(itemId)
	if not itemId then return nil end
	return AnimationDatabase.SetMap[itemId]
end

function AnimationDatabase.GetLayer(name)
	return AnimationDatabase.Layers[name]
end

function AnimationDatabase.GetLayerPriority(name)
	local layer = AnimationDatabase.Layers[name]
	return layer and layer.Priority or Enum.AnimationPriority.Movement
end

function AnimationDatabase.GetLayerWeight(name)
	local layer = AnimationDatabase.Layers[name]
	return layer and layer.Weight or 1
end

function AnimationDatabase.GetLayerFadeTime(name)
	local layer = AnimationDatabase.Layers[name]
	return layer and layer.FadeTime or 0.18
end

function AnimationDatabase.IsLayerEnabled(name)
	local layer = AnimationDatabase.Layers[name]
	if not layer then return false end
	if layer.Enabled == false then return false end
	return true
end

function AnimationDatabase.IsBlendableLocomotion(animId)
	return animId and AnimationDatabase.BlendableLocomotion[animId] == true
end

function AnimationDatabase.GetLocomotion(stance, motion)
	local L = AnimationDatabase.Locomotion

	local function pick(st, mo)
		local t = L[st]
		if type(t) ~= "table" then return nil end
		local id = t[mo]
		if id and id ~= "" then return id end
		return nil
	end

	return pick(stance, motion)
		or (motion == "Run" and pick(stance, "Walk"))
		or pick(stance, "Idle")
		or pick("Stand", motion)
		or (motion == "Run" and pick("Stand", "Walk"))
		or pick("Stand", "Idle")
end

function AnimationDatabase.GetWeaponAnim(setKey, name)
	if not setKey then return nil end
	local set = AnimationDatabase.Weapons[setKey]
	if not set then return nil end

	local id = set[name]
	if id and id ~= "" then return id end

	if name == "Aim" and set.Pose and set.Pose ~= "" then
		return set.Pose
	end

	if setKey == "knife" then
		local p = AnimationDatabase.Weapons.pistol[name]
		if p and p ~= "" then return p end
	end

	return nil
end

function AnimationDatabase.GetViewModel(setKey, name)
	local set = setKey and AnimationDatabase.ViewModels[setKey]
	if not set then return nil end
	local id = set[name]
	return (id and id ~= "") and id or nil
end

function AnimationDatabase.GetAllIds()
	local ids, seen = {}, {}
	local function add(v)
		if type(v) == "string" and v ~= "" and not seen[v] then
			seen[v] = true
			table.insert(ids, v)
		end
	end
	local function walk(t)
		for _, v in pairs(t) do
			if type(v) == "table" then walk(v) else add(v) end
		end
	end
	walk(AnimationDatabase.Locomotion)
	walk(AnimationDatabase.Weapons)
	walk(AnimationDatabase.ViewModels)
	return ids
end

AnimationDatabase.AimOffset = {
	WaistRatio = 0.45,
	NeckRatio  = 0.35,
	MaxAngle   = math.rad(35),
	Smooth     = 12,
}

return AnimationDatabase