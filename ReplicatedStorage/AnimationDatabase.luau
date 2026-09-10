--------------------------------------------------------------
-- AnimationDatabase.lua  (ModuleScript — ReplicatedStorage)
--
-- ?? ระบบ 3 ชั้น (Layer):
--   1. Locomotion   — ขา/การเคลื่อนที่  (ไม่ขึ้นกับอาวุธ)
--   2. WeaponPose   — แขนถือปืน (ท่อนบน) เล่นทับ locomotion
--   3. Action       — ยิง/reload/equip  เล่นทับอีกที
--
-- ? เพิ่มท่า = เติม ID ในตารางนี้ที่เดียว
-- ? เว้นว่าง "" ได้ ระบบ fallback ให้เอง
--------------------------------------------------------------

local AnimationDatabase = {}

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  LAYER 1 — LOCOMOTION (ท่าเดิน ไม่ขึ้นกับอาวุธ)
-- อออออออออออออออออออออออออออออออออออออออออออออออ
AnimationDatabase.Locomotion = {
	Stand = {
		Idle = "rbxassetid://180435571",   -- Classic R6 idle
		Walk = "rbxassetid://180426354",   -- Classic R6 walk
		Run  = "rbxassetid://180426354",   -- Classic R6 run
	},
	Crouch = {
		Idle = "",   -- ?? ต้องหาเพิ่ม
		Walk = "",   -- ?? ต้องหาเพิ่ม
		Run  = "",   -- ว่าง = ใช้ Walk
	},
	Prone = {
		Idle = "",   -- ?? ต้องหาเพิ่ม
		Walk = "",   -- ?? ต้องหาเพิ่ม
		Run  = "",
	},
	Jump = "rbxassetid://125750702",   -- Classic R6 jump
	Fall = "rbxassetid://180436148",   -- Classic R6 fall
}

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  LAYER 2 + 3 — WEAPON SETS
--  ? ได้จาก Laser Tag template แล้ว
-- อออออออออออออออออออออออออออออออออออออออออออออออ
AnimationDatabase.Weapons = {

	-- ปืนยาว (rifle + shotgun)
	rifle = {
		Pose   = "rbxassetid://17747384020",  -- AutoBlaster Idle  ท่าถือปืนยาว
		Shoot  = "rbxassetid://17747381445",
		Reload = "rbxassetid://17747385966",
		Equip  = "",
		Aim    = "",   -- ว่าง = ใช้ Pose แทน
	},

	-- ปืนสั้น
	pistol = {
		Pose   = "rbxassetid://17747125537",  -- Blaster Idle  ท่าถือปืนสั้น
		Shoot  = "rbxassetid://17747128593",
		Reload = "rbxassetid://17747123905",
		Equip  = "",
		Aim    = "",
	},

	-- มีด
	knife = {
		Pose   = "",   -- ?? ต้องหาเพิ่ม (ใช้ pistol pose ไปก่อนได้)
		Shoot  = "",   -- ท่าฟัน
		Reload = "",
		Equip  = "",
		Aim    = "",
	},
}

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  VIEWMODEL (โหมด First Person — ทำทีหลัง)
-- อออออออออออออออออออออออออออออออออออออออออออออออ
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

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  itemId  weapon set key
-- อออออออออออออออออออออออออออออออออออออออออออออออ
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

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  RESOLVERS
-- อออออออออออออออออออออออออออออออออออออออออออออออ

-- ท่าเดิน (มี fallback)
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

-- ท่าอาวุธ (Pose / Shoot / Reload / Equip / Aim)
function AnimationDatabase.GetWeaponAnim(setKey, name)
	if not setKey then return nil end
	local set = AnimationDatabase.Weapons[setKey]
	if not set then return nil end

	local id = set[name]
	if id and id ~= "" then return id end

	-- Aim ไม่มี  ใช้ Pose
	if name == "Aim" and set.Pose and set.Pose ~= "" then
		return set.Pose
	end

	-- knife ไม่มี pose  ยืมของ pistol
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

-- รวม ID ทั้งหมดสำหรับ preload
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

return AnimationDatabase