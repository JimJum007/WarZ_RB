--------------------------------------------------------------
-- ItemSpawner.lua  (Script)
-- วางใน: ServerScriptService
--
-- วางไอเทมกลางแมพ ให้ผู้เล่นเดินเก็บ
-- ใช้ Folder "ItemSpawns" ใน Workspace
-- Part ตั้งชื่อ: ItemSpawn_{itemId}  (เช่น ItemSpawn_pistol)
--------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- ═══════════════════════════════════════════════
--  โหลด Dependencies
-- ═══════════════════════════════════════════════
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

-- รอให้ InventoryManager โหลดก่อน
task.wait(1)

-- ═══════════════════════════════════════════════
--  REMOTE EVENTS / BINDABLE EVENTS
-- ═══════════════════════════════════════════════
local PickupItemEvent = ReplicatedStorage:WaitForChild("PickupItem")

-- สร้าง BindableEvent สำหรับรับ dropped items
local SpawnDroppedItem = ReplicatedStorage:FindFirstChild("SpawnDroppedItem")
if not SpawnDroppedItem then
	SpawnDroppedItem = Instance.new("BindableEvent")
	SpawnDroppedItem.Name = "SpawnDroppedItem"
	SpawnDroppedItem.Parent = ReplicatedStorage
end

-- ═══════════════════════════════════════════════
--  CONSTANTS
-- ═══════════════════════════════════════════════
local PICKUP_DISTANCE  = 15     -- ระยะเก็บสูงสุด (studs)
local RESPAWN_TIME     = 30     -- วินาทีก่อน respawn
local HOVER_HEIGHT     = 1.5    -- ลอยเหนือพื้น
local ROTATION_SPEED   = 1      -- ความเร็วหมุน (radian/s)

-- ═══════════════════════════════════════════════
--  ITEM SPAWNS FOLDER
-- ═══════════════════════════════════════════════
local itemSpawnsFolder = workspace:FindFirstChild("ItemSpawns")
if not itemSpawnsFolder then
	itemSpawnsFolder = Instance.new("Folder")
	itemSpawnsFolder.Name = "ItemSpawns"
	itemSpawnsFolder.Parent = workspace
end

-- ═══════════════════════════════════════════════
--  ตกแต่ง Part ให้เป็น Pickup
-- ═══════════════════════════════════════════════
local function setupPickupVisual(part, itemData)
	local rarityColor = ItemDatabase.GetRarityColor(itemData.Rarity or "Common")
	part.Color = rarityColor
	part.Material = Enum.Material.Neon
	part.Transparency = 0.3
	part.CanCollide = false
	part.Anchored = true
	part.Size = Vector3.new(1.5, 1.5, 1.5)

	-- PointLight (เรืองแสง)
	if not part:FindFirstChildOfClass("PointLight") then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Brightness = 1.5
		light.Range = 10
		light.Parent = part
	end

	-- BillboardGui (ชื่อไอเทมลอยเหนือ Part)
	local existingGui = part:FindFirstChild("ItemBillboard")
	if existingGui then existingGui:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ItemBillboard"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.Name
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = billboard
end

-- ═══════════════════════════════════════════════
--  INITIALIZE ทุก Part ใน ItemSpawns
-- ═══════════════════════════════════════════════
local spawnPoints = {}

local function initializeSpawn(part)
	local itemId = string.match(part.Name, "ItemSpawn_(.+)")
	if not itemId then return end

	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData then
		warn("[ItemSpawner] ไม่พบ itemId:", itemId)
		return
	end

	spawnPoints[part] = part.Position
	setupPickupVisual(part, itemData)
	print("[ItemSpawner] Initialized:", itemData.Name)
end

for _, part in ipairs(itemSpawnsFolder:GetChildren()) do
	if part:IsA("BasePart") then
		initializeSpawn(part)
	end
end

itemSpawnsFolder.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") then
		task.wait(0.1)
		initializeSpawn(child)
	end
end)

-- ═══════════════════════════════════════════════
--  ROTATION (หมุนช้าๆ)
-- ═══════════════════════════════════════════════
RunService.Heartbeat:Connect(function(dt)
	for _, part in ipairs(itemSpawnsFolder:GetChildren()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			part.CFrame = part.CFrame * CFrame.Angles(0, ROTATION_SPEED * dt, 0)
		end
	end
end)

-- ═══════════════════════════════════════════════
--  PICKUP HANDLER (กด F เก็บของ)
-- ═══════════════════════════════════════════════
PickupItemEvent.OnServerEvent:Connect(function(player, part)
	if not part or not part:IsA("BasePart") then return end
	if not part:IsDescendantOf(itemSpawnsFolder) then return end
	if part.Transparency >= 1 then return end  -- ถูกเก็บไปแล้ว

	local itemId = string.match(part.Name, "ItemSpawn_(.+)")
	if not itemId then return end

	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData then return end

	-- เช็คระยะ
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if (rootPart.Position - part.Position).Magnitude > PICKUP_DISTANCE then return end

	-- กำหนดจำนวน
	local quantity = 1
	if ItemDatabase.IsStackable(itemId) and itemData.StackSize then
		quantity = itemData.StackSize
	end

	-- เพิ่มเข้า Inventory
	if not _G.InventoryManager then
		warn("[ItemSpawner] InventoryManager ยังไม่โหลด!")
		return
	end

	local success, err = _G.InventoryManager.AddItem(player, itemId, quantity)
	if not success then
		warn("[ItemSpawner] เก็บไม่ได้:", err)
		return
	end

	print("[ItemSpawner]", player.Name, "picked up", itemData.Name)

	-- ซ่อน Part
	local savedPos = part.Position
	part.Transparency = 1
	local billboard = part:FindFirstChild("ItemBillboard")
	if billboard then billboard.Enabled = false end
	local light = part:FindFirstChildOfClass("PointLight")
	if light then light.Enabled = false end

	-- Respawn
	task.delay(RESPAWN_TIME, function()
		if part and part.Parent then
			part.Position = savedPos
			part.Transparency = 0.3
			if billboard then billboard.Enabled = true end
			if light then light.Enabled = true end
			setupPickupVisual(part, itemData)
		end
	end)
end)

-- ═══════════════════════════════════════════════
--  DROPPED ITEM (ทิ้งของ)
-- ═══════════════════════════════════════════════
SpawnDroppedItem.Event:Connect(function(itemId, position)
	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData then return end

	local part = Instance.new("Part")
	part.Name = "ItemSpawn_" .. itemId
	part.Position = position + Vector3.new(0, HOVER_HEIGHT, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Parent = itemSpawnsFolder

	setupPickupVisual(part, itemData)
end)

print("[ItemSpawner] Ready —", #itemSpawnsFolder:GetChildren(), "spawn points")