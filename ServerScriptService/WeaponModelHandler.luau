--------------------------------------------------------------
-- WeaponModelHandler.lua  (Script — ServerScriptService)
-- ติดโมเดลอาวุธเข้ามือตัวละครตาม active weapon
-- ถ้าไม่มีโมเดลใน ReplicatedStorage.WeaponModels  สร้าง placeholder ให้
--------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
task.wait(1)

local EquipUpdateEvent = ReplicatedStorage:WaitForChild("EquipUpdate")

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  MODEL FOLDER
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local modelsFolder = ReplicatedStorage:FindFirstChild("WeaponModels")
if not modelsFolder then
	modelsFolder = Instance.new("Folder")
	modelsFolder.Name   = "WeaponModels"
	modelsFolder.Parent = ReplicatedStorage
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  PLACEHOLDER BUILDER
--  ทำโมเดลกล่องๆ ไว้เทสก่อน — เปลี่ยนเป็นโมเดลจริงทีหลัง
--  แค่เอาโมเดลจริงใส่ใน WeaponModels ชื่อตรงกับ itemId
--  (ต้องมี Part ชื่อ "Handle" เป็น PrimaryPart)
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local BLUEPRINTS = {
	rifle = {
		color = Color3.fromRGB(45, 45, 48),
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
		parts = {
			{ name = "Handle", size = Vector3.new(0.38, 0.55, 1.8), offset = Vector3.new(0, 0, 0) },
			{ name = "Barrel", size = Vector3.new(0.3, 0.3, 2.6),   offset = Vector3.new(0, 0.14, -2.0) },
			{ name = "Pump",   size = Vector3.new(0.34, 0.34, 0.8), offset = Vector3.new(0, -0.05, -1.3) },
			{ name = "Stock",  size = Vector3.new(0.32, 0.5, 1.2),  offset = Vector3.new(0, 0.05, 1.4) },
		},
	},
	pistol = {
		color = Color3.fromRGB(55, 55, 58),
		parts = {
			{ name = "Handle", size = Vector3.new(0.25, 0.55, 0.35), offset = Vector3.new(0, -0.2, 0.15) },
			{ name = "Slide",  size = Vector3.new(0.28, 0.32, 1.15), offset = Vector3.new(0, 0.22, -0.3) },
		},
	},
	knife = {
		color = Color3.fromRGB(180, 185, 195),
		parts = {
			{ name = "Handle", size = Vector3.new(0.16, 0.16, 0.5), offset = Vector3.new(0, 0, 0) },
			{ name = "Blade",  size = Vector3.new(0.05, 0.22, 1.0), offset = Vector3.new(0, 0.02, -0.7) },
		},
	},
}

local function buildPlaceholder(itemId)
	local bp = BLUEPRINTS[itemId]
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

	model.PrimaryPart = handle

	-- จุดปากกระบอก (ไว้ทำ muzzle flash)
	local muzzle = Instance.new("Attachment")
	muzzle.Name     = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.12, -2.8)
	muzzle.Parent   = handle

	model.Parent = modelsFolder
	return model
end

local function getModelTemplate(itemId)
	local existing = modelsFolder:FindFirstChild(itemId)
	if existing then return existing end
	return buildPlaceholder(itemId)
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  GRIP OFFSET — ปรับตำแหน่งปืนในมือตรงนี้
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local GRIP_C0 = {
	rifle   = CFrame.new(0, -0.9, -0.6) * CFrame.Angles(math.rad(-90), 0, 0),
	shotgun = CFrame.new(0, -0.9, -0.7) * CFrame.Angles(math.rad(-90), 0, 0),
	pistol  = CFrame.new(0, -0.4, -0.3) * CFrame.Angles(math.rad(-90), 0, 0),
	knife   = CFrame.new(0, -0.6, -0.2) * CFrame.Angles(math.rad(-90), 0, 0),
}

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  ATTACH / DETACH
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function clearWeapon(character)
	local old = character:FindFirstChild("EquippedWeapon")
	if old then old:Destroy() end
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

	local hand = character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
	if not hand then return end

	local model = template:Clone()
	model.Name  = "EquippedWeapon"

	local handle = model.PrimaryPart or model:FindFirstChild("Handle", true)
	if not handle then
		warn("[WeaponModel] ไม่มี Handle:", itemId)
		model:Destroy()
		return
	end

	-- ?? ล้าง weld เก่าที่อาจติดมา (ACS models มักมี)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
			d:Destroy()
		end
	end

	-- weld ทุกชิ้นเข้า Handle (ก่อน parent — CFrame สัมพัทธ์ยังถูก)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= handle then
			p.Anchored = false
			local w = Instance.new("Weld")
			w.Name   = "PartWeld"
			w.Part0  = handle
			w.Part1  = p
			w.C0     = handle.CFrame:Inverse() * p.CFrame
			w.Parent = handle
		end
	end
	handle.Anchored = false

	local gripC0 = GRIP_C0[itemId]
		or CFrame.new(0, -0.8, -0.5) * CFrame.Angles(math.rad(-90), 0, 0)

	model:PivotTo(hand.CFrame * gripC0)
	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name   = "WeaponGrip"
	motor.Part0  = hand
	motor.Part1  = handle
	motor.C0     = gripC0
	motor.C1     = CFrame.new()
	motor.Parent = hand

	-- บอก client ว่ามี Muzzle ที่ไหน (ไว้ทำ flash)
	local muzzle = handle:FindFirstChild("Muzzle")
	if muzzle then
		character:SetAttribute("HasMuzzle", true)
	end

	print("[WeaponModel] attached:", itemId, "", player.Name)
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  HOOKS
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local activeWeapon = {}  -- [player] = itemId

-- Server อ่าน event ที่ตัวเองยิงไม่ได้  ใช้ polling เบาๆ แทน
task.spawn(function()
	while true do
		task.wait(0.2)
		if _G.InventoryManager then
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				local ok, itemId = pcall(function()
					return _G.InventoryManager.GetActiveWeapon(player)
				end)
				if not ok then itemId = nil end

				-- ตัวละครยังไม่พร้อม  ข้าม
				if char and char:FindFirstChild("HumanoidRootPart") then
					if activeWeapon[player] ~= itemId then
						activeWeapon[player] = itemId
						attachWeapon(player, itemId)
					end
				end
			end
		end
	end
end)

local function hookRespawn(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.3)
		activeWeapon[player] = nil  -- บังคับ re-attach หลังเกิดใหม่
	end)
end

Players.PlayerAdded:Connect(hookRespawn)
for _, p in ipairs(Players:GetPlayers()) do
	hookRespawn(p)
end

Players.PlayerRemoving:Connect(function(player)
	activeWeapon[player] = nil
end)

print("[WeaponModelHandler] Ready")