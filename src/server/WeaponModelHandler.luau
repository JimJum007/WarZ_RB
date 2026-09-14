--------------------------------------------------------------
-- WeaponModelHandler.luau  (Script — ServerScriptService)
-- ติดโมเดลอาวุธเข้ามือขวา (R15) ด้วย GripAttachment + HAND_OFFSET ร่วมกัน
-- Server เป็น source of truth — client ไม่ตั้ง Motor6D
--
-- ═══ Convention แกน GripAttachment / LeftGripAttachment (บน Handle) ═══
-- ตั้ง CFrame ครบทั้งตำแหน่งและการหมุน — Motor6D.C1 ใช้ค่านี้ตรงๆ
--   แกน -Z  → ชี้ไปทางปากกระบอก (ทิศยิง)
--   แกน +Y  → ชี้ด้านบนปืน (เฝ้า / สโคป)
--   แกน +X  → ด้านขวาของปืน (มองจากผู้ยิง)
-- โมเดล Toolbox: Handle มักจัดให้ปลายกระบอกอยู่ทาง -Z ของ Handle อยู่แล้ว
--   → rotation ของ Grip ควรเป็น identity (ไม่ใส่ Angles 90/180 ซ้ำซ้อน)
-- เพิ่มปืนใหม่: ใส่แค่ตำแหน่งจับใน gripCFrame / leftGripCFrame ผ่าน gripAt()
--
-- DEBUG_SHOW_AXES = true → แสดง Part สีแดง/เขียว/น้ำเงิน แกน X/Y/Z ที่ Grip
--------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
task.wait(1)

-- เปิดชั่วคราวเพื่อดูแกน GripAttachment ในโลก (แดง=X เขียว=Y น้ำเงิน=Z)
local DEBUG_SHOW_AXES = false
local DEBUG_AXIS_LENGTH = 0.45
local DEBUG_AXIS_THICK = 0.04

-- ═══════════════════════════════════════════════
--  HAND_OFFSET — ชดเชยท่าอนิเมชัน R15 (คูณหลัง RightGripAttachment)
--  Motor6D: C0 = RightGripAttachment.CFrame * offset, C1 = GripAttachment.CFrame
--  ค่าเริ่มต้น + override รายอาวุธ: ItemDatabase.GetHandOffset(itemId)
-- ═══════════════════════════════════════════════

-- สร้าง CFrame จับมือตาม convention (ตำแหน่ง local บน Handle + rotation identity)
local function gripAt(position: Vector3): CFrame
	return CFrame.new(position)
end

local function clearDebugAxes(handle: BasePart)
	local folder = handle:FindFirstChild("DebugGripAxes")
	if folder then folder:Destroy() end
end

local function showDebugAxes(handle: BasePart, grip: Attachment)
	clearDebugAxes(handle)
	if not DEBUG_SHOW_AXES then return end

	local folder = Instance.new("Folder")
	folder.Name = "DebugGripAxes"
	folder.Parent = handle

	local axisDefs = {
		{ name = "X", color = Color3.fromRGB(255, 70, 70), dir = Vector3.new(1, 0, 0) },
		{ name = "Y", color = Color3.fromRGB(70, 255, 90), dir = Vector3.new(0, 1, 0) },
		{ name = "Z", color = Color3.fromRGB(80, 140, 255), dir = Vector3.new(0, 0, 1) },
	}

	for _, def in ipairs(axisDefs) do
		local half = DEBUG_AXIS_LENGTH * 0.5
		local p = Instance.new("Part")
		p.Name = "Axis_" .. def.name
		p.Size = Vector3.new(DEBUG_AXIS_THICK, DEBUG_AXIS_THICK, DEBUG_AXIS_LENGTH)
		p.Color = def.color
		p.Material = Enum.Material.Neon
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = false
		p.CFrame = grip.CFrame * CFrame.lookAt(Vector3.zero, def.dir) * CFrame.new(0, 0, -half)
		p.Parent = folder

		local w = Instance.new("Weld")
		w.Part0 = handle
		w.Part1 = p
		w.C0 = grip.CFrame * CFrame.lookAt(Vector3.zero, def.dir) * CFrame.new(0, 0, -half)
		w.C1 = CFrame.new()
		w.Parent = p
	end
end

local function getHandMotorC0(hand: BasePart, itemId: string): CFrame
	local offset = ItemDatabase.GetHandOffset(itemId)
	local rightGrip = hand:FindFirstChild("RightGripAttachment")
	if rightGrip and rightGrip:IsA("Attachment") then
		return rightGrip.CFrame * offset
	end
	-- R15 fallback ถ้าไม่มี Attachment บนมือ
	return CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0) * offset
end

-- ═══════════════════════════════════════════════
--  MODEL FOLDER
-- ═══════════════════════════════════════════════
local modelsFolder = ReplicatedStorage:FindFirstChild("WeaponModels")
if not modelsFolder then
	modelsFolder = Instance.new("Folder")
	modelsFolder.Name   = "WeaponModels"
	modelsFolder.Parent = ReplicatedStorage
end

-- itemId ที่ไม่มี blueprint แยก → ใช้ชุดนี้ (placeholder)
local BLUEPRINT_ALIAS: { [string]: string } = {
	ak = "ak",
}

-- gripCFrame / leftGripCFrame: ใช้ gripAt() — rotation identity, -Z ปากกระบอก | muzzlePos: ปลายกระบอก
local BLUEPRINTS = {
	rifle = {
		color = Color3.fromRGB(45, 45, 48),
		gripCFrame = gripAt(Vector3.new(0, 0.02, 0.28)),
		leftGripCFrame = gripAt(Vector3.new(0, 0.12, -1.15)),
		muzzlePos = Vector3.new(0, 0.39, -2.44),
		parts = {
			{ name = "Handle", size = Vector3.new(0.35, 0.5, 1.6),  offset = Vector3.new(0, 0, 0) },
			{ name = "Barrel", size = Vector3.new(0.22, 0.22, 2.2), offset = Vector3.new(0, 0.12, -1.7) },
			{ name = "Stock",  size = Vector3.new(0.3, 0.45, 1.0),  offset = Vector3.new(0, 0.05, 1.2) },
			{ name = "Mag",    size = Vector3.new(0.2, 0.7, 0.35),  offset = Vector3.new(0, -0.55, -0.3) },
			{ name = "Sight",  size = Vector3.new(0.12, 0.25, 0.3), offset = Vector3.new(0, 0.4, -0.4) },
		},
	},
	shotgun = {
		color = Color3.fromRGB(70, 48, 32),
		gripCFrame = gripAt(Vector3.new(0, 0.02, 0.35)),
		leftGripCFrame = gripAt(Vector3.new(0, 0.08, -1.45)),
		muzzlePos = Vector3.new(0, 0.14, -3.2),
		parts = {
			{ name = "Handle", size = Vector3.new(0.38, 0.55, 1.8), offset = Vector3.new(0, 0, 0) },
			{ name = "Barrel", size = Vector3.new(0.3, 0.3, 2.6),   offset = Vector3.new(0, 0.14, -2.0) },
			{ name = "Pump",   size = Vector3.new(0.34, 0.34, 0.8), offset = Vector3.new(0, -0.05, -1.3) },
			{ name = "Stock",  size = Vector3.new(0.32, 0.5, 1.2),  offset = Vector3.new(0, 0.05, 1.4) },
		},
	},
	pistol = {
		color = Color3.fromRGB(55, 55, 58),
		gripCFrame = gripAt(Vector3.new(0, -0.02, 0.08)),
		leftGripCFrame = gripAt(Vector3.new(0, 0.05, -0.35)),
		muzzlePos = Vector3.new(0, 0.25, -0.67),
		parts = {
			{ name = "Handle", size = Vector3.new(0.25, 0.55, 0.35), offset = Vector3.new(0, -0.2, 0.15) },
			{ name = "Slide",  size = Vector3.new(0.28, 0.32, 1.15), offset = Vector3.new(0, 0.22, -0.3) },
		},
	},
	knife = {
		color = Color3.fromRGB(180, 185, 195),
		gripCFrame = gripAt(Vector3.new(0, 0, -0.05)),
		leftGripCFrame = gripAt(Vector3.new(0, 0, -0.05)),
		muzzlePos = Vector3.new(0, 0.02, -1.15),
		parts = {
			{ name = "Handle", size = Vector3.new(0.16, 0.16, 0.5), offset = Vector3.new(0, 0, 0) },
			{ name = "Blade",  size = Vector3.new(0.05, 0.22, 1.0), offset = Vector3.new(0, 0.02, -0.7) },
		},
	},
	ak = {
		color = Color3.fromRGB(50, 42, 38),
		gripCFrame = gripAt(Vector3.new(0, 0.02, 0.28)),
		leftGripCFrame = gripAt(Vector3.new(0, 0.1, -0.95)),
		muzzlePos = Vector3.new(0, 0.25, -2.44),
		parts = {
			{ name = "Handle", size = Vector3.new(0.36, 0.48, 1.5), offset = Vector3.new(0, 0, 0) },
			{ name = "Barrel", size = Vector3.new(0.24, 0.24, 2.0), offset = Vector3.new(0, 0.1, -1.55) },
			{ name = "Stock", size = Vector3.new(0.32, 0.42, 0.95), offset = Vector3.new(0, 0.04, 1.15) },
			{ name = "Mag", size = Vector3.new(0.22, 0.65, 0.38), offset = Vector3.new(0, -0.52, -0.25) },
		},
	},
	smg = {
		color = Color3.fromRGB(42, 42, 46),
		gripCFrame = gripAt(Vector3.new(0, 0.02, 0.18)),
		leftGripCFrame = gripAt(Vector3.new(0, 0.12, -0.82)),
		muzzlePos = Vector3.new(0, 0.36, -1.39),
		parts = {
			{ name = "Handle", size = Vector3.new(0.3, 0.42, 1.1), offset = Vector3.new(0, 0, 0) },
			{ name = "Barrel", size = Vector3.new(0.2, 0.2, 1.35), offset = Vector3.new(0, 0.08, -1.05) },
			{ name = "Mag", size = Vector3.new(0.18, 0.55, 0.32), offset = Vector3.new(0, -0.45, -0.15) },
		},
	},
	sniper = {
		color = Color3.fromRGB(38, 40, 36),
		gripCFrame = gripAt(Vector3.new(0, 0.02, 0.32)),
		leftGripCFrame = gripAt(Vector3.new(0, 0.14, -1.55)),
		muzzlePos = Vector3.new(0, 0.38, -5.6),
		parts = {
			{ name = "Handle", size = Vector3.new(0.34, 0.46, 1.7), offset = Vector3.new(0, 0, 0) },
			{ name = "Barrel", size = Vector3.new(0.2, 0.2, 2.8), offset = Vector3.new(0, 0.12, -2.1) },
			{ name = "Scope", size = Vector3.new(0.14, 0.14, 0.55), offset = Vector3.new(0, 0.38, -0.5) },
			{ name = "Stock", size = Vector3.new(0.3, 0.4, 1.1), offset = Vector3.new(0, 0.05, 1.25) },
		},
	},
	lmg = {
		color = Color3.fromRGB(48, 50, 44),
		gripCFrame = gripAt(Vector3.new(0, 0.02, 0.3)),
		leftGripCFrame = gripAt(Vector3.new(0, 0.05, -1.65)),
		muzzlePos = Vector3.new(0, 0.37, -3.48),
		parts = {
			{ name = "Handle", size = Vector3.new(0.38, 0.5, 1.75), offset = Vector3.new(0, 0, 0) },
			{ name = "Barrel", size = Vector3.new(0.24, 0.24, 2.4), offset = Vector3.new(0, 0.1, -1.85) },
			{ name = "Bipod", size = Vector3.new(0.28, 0.12, 0.5), offset = Vector3.new(0, -0.2, -1.2) },
			{ name = "Mag", size = Vector3.new(0.24, 0.75, 0.4), offset = Vector3.new(0, -0.58, -0.35) },
		},
	},
}

local function getBlueprint(itemId: string)
	local key = BLUEPRINT_ALIAS[itemId] or itemId
	return BLUEPRINTS[key]
end

local function addWeaponAttachments(handle: BasePart, bp)
	local grip = handle:FindFirstChild("GripAttachment")
	if not (grip and grip:IsA("Attachment")) then
		grip = Instance.new("Attachment")
		grip.Name = "GripAttachment"
		grip.Parent = handle
	end
	-- บังคับ CFrame ทั้ง position + rotation จาก blueprint ทุกครั้ง (ไม่ตั้งแค่ Position)
	grip.CFrame = bp.gripCFrame

	local leftGrip = handle:FindFirstChild("LeftGripAttachment")
	if not (leftGrip and leftGrip:IsA("Attachment")) then
		leftGrip = Instance.new("Attachment")
		leftGrip.Name = "LeftGripAttachment"
		leftGrip.Parent = handle
	end
	if bp.leftGripCFrame then
		leftGrip.CFrame = bp.leftGripCFrame
	end

	local muzzle = handle:FindFirstChild("MuzzleAttachment")
	if not muzzle or not muzzle:IsA("Attachment") then
		local legacy = handle:FindFirstChild("Muzzle")
		if legacy and legacy:IsA("Attachment") then
			muzzle = legacy
		else
			muzzle = Instance.new("Attachment")
			muzzle.Name = "MuzzleAttachment"
			muzzle.Parent = handle
		end
	end
	-- ปลายกระบอก: ตำแหน่งจาก blueprint, rotation identity (แกน -Z ชี้กลับเข้าตัวปืน)
	if bp.muzzlePos and muzzle:IsA("Attachment") then
		muzzle.CFrame = gripAt(bp.muzzlePos)
	end

	showDebugAxes(handle, grip)
end

local function ensureHandleAttachments(handle: BasePart, itemId: string)
	local bp = getBlueprint(itemId)
	if not bp then return end
	addWeaponAttachments(handle, bp)
end

local function buildPlaceholder(itemId)
	local bp = getBlueprint(itemId)
	if not bp then return nil end

	local model = Instance.new("Model")
	model.Name = itemId

	local handle
	for _, def in ipairs(bp.parts) do
		local p = Instance.new("Part")
		p.Name         = def.name
		p.Size         = def.size
		p.Color        = (def.name == "Blade") and Color3.fromRGB(220, 225, 235) or bp.color
		p.Material     = (def.name == "Blade") and Enum.Material.Metal or Enum.Material.SmoothPlastic
		p.CanCollide   = false
		p.CanQuery     = false
		p.CanTouch     = false
		p.Massless     = true
		p.CFrame       = CFrame.new(def.offset)
		p.TopSurface   = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent       = model

		if def.name == "Handle" then handle = p end
	end

	if not handle then return nil end

	model.PrimaryPart = handle
	addWeaponAttachments(handle, bp)

	model.Parent = modelsFolder
	return model
end

-- หา Handle: PrimaryPart → ชื่อ Handle → BasePart แรก (รองรับ Model + Tool)
local function findHandle(root: Instance): BasePart?
	if root:IsA("Tool") then
		local h = root:FindFirstChild("Handle")
		if h and h:IsA("BasePart") then return h end
	end
	if root:IsA("Model") or root:IsA("Tool") then
		if root:IsA("Model") and root.PrimaryPart and root.PrimaryPart:IsA("BasePart") then
			return root.PrimaryPart
		end
		local named = root:FindFirstChild("Handle", true)
		if named and named:IsA("BasePart") then return named end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
	end
	return nil
end

local function getModelTemplate(itemId)
	local existing = modelsFolder:FindFirstChild(itemId)
	if existing then
		local h = findHandle(existing)
		if h then
			ensureHandleAttachments(h, itemId)
		end
		return existing
	end
	return buildPlaceholder(itemId)
end

local function resolveGripAttachment(handle: BasePart, itemId: string, templateHadGrip: boolean): Attachment
	local grip = handle:FindFirstChild("GripAttachment")
	if grip and grip:IsA("Attachment") then
		return grip
	end

	if templateHadGrip then
		warn("[WeaponModel] GripAttachment หายหลัง clone:", itemId)
	else
		warn("[WeaponModel] โมเดล", itemId, "ไม่มี GripAttachment — ใช้ CFrame.new() (ควรจูนบน Handle)")
	end

	grip = Instance.new("Attachment")
	grip.Name = "GripAttachment"
	grip.CFrame = CFrame.new()
	grip.Parent = handle
	return grip
end

local function prepareModelParts(model: Instance, handle: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
			d:Destroy()
		end
	end

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
		end
	end

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= handle then
			local w = Instance.new("Weld")
			w.Name   = "PartWeld"
			w.Part0  = handle
			w.Part1  = p
			w.C0     = handle.CFrame:Inverse() * p.CFrame
			w.Parent = handle
		end
	end
	handle.Anchored = false
end

-- ═══════════════════════════════════════════════
--  ATTACH / DETACH
-- ═══════════════════════════════════════════════
local function clearWeapon(character)
	local old = character:FindFirstChild("EquippedWeapon")
	if old then old:Destroy() end
	character:SetAttribute("HasMuzzle", nil)
end

local function attachWeapon(player, itemId)
	local character = player.Character
	if not character then return end

	clearWeapon(character)
	if not itemId then return end

	local template = getModelTemplate(itemId)
	if not template then
		warn("[WeaponModel] ไม่มีโมเดลสำหรับ:", itemId)
		return
	end

	local templateHandle = findHandle(template)
	local templateHadGrip = templateHandle
		and templateHandle:FindFirstChild("GripAttachment") ~= nil

	local hand = character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
	if not hand then return end

	local model = template:Clone()
	model.Name = "EquippedWeapon"

	local handle = findHandle(model)
	if not handle then
		warn("[WeaponModel] ไม่มี Handle:", itemId)
		model:Destroy()
		return
	end

	prepareModelParts(model, handle)

	ensureHandleAttachments(handle, itemId)
	local gripAtt = resolveGripAttachment(handle, itemId, templateHadGrip)

	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name   = "WeaponGrip"
	motor.Part0  = hand
	motor.Part1  = handle
	motor.C0     = getHandMotorC0(hand, itemId)
	motor.C1     = gripAtt.CFrame
	motor.Parent = hand

	if handle:FindFirstChild("MuzzleAttachment") or handle:FindFirstChild("Muzzle") then
		character:SetAttribute("HasMuzzle", true)
	end

	print("[WeaponModel] attached:", itemId, "→", player.Name)
end

-- ═══════════════════════════════════════════════
--  HOOKS — event-driven
-- ═══════════════════════════════════════════════
local activeWeapon = {}

local WeaponChanged = ReplicatedStorage:WaitForChild("WeaponChanged")

local function safeAttach(player, itemId)
	if activeWeapon[player] == itemId then return end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		task.delay(0.5, function()
			if player.Parent and player.Character then
				activeWeapon[player] = itemId
				attachWeapon(player, itemId)
			end
		end)
		return
	end
	activeWeapon[player] = itemId
	attachWeapon(player, itemId)
end

WeaponChanged.Event:Connect(safeAttach)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.3)
		activeWeapon[player] = nil
		if _G.InventoryManager then
			local itemId = _G.InventoryManager.GetActiveWeapon(player)
			safeAttach(player, itemId)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	activeWeapon[player] = nil
end)

print("[WeaponModelHandler] Ready — Grip CFrame convention + RightGrip C0")