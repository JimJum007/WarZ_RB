-- PickupClient.lua
-- LocalScript สำหรับแสดง Prompt เก็บไอเทมเมื่อผู้เล่นอยู่ใกล้ และจัดการปุ่ม F เพื่อเก็บไอเทม
-- วางไว้ใน StarterPlayer/StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- รอ RemoteEvent 'StartGameplay' ก่อนเริ่มทำงาน (แพทเทิร์นเดียวกับสคริปต์ฝั่งไคลเอนต์อื่นๆ)
local startGameplay = ReplicatedStorage:WaitForChild("StartGameplay")
startGameplay.OnClientEvent:Wait()

-- โหลดโมดูล ItemDatabase สำหรับดึงข้อมูลไอเทมและสีความหายาก
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

-- อ้างอิง RemoteEvent สำหรับส่งคำขอเก็บไอเทมไปยังเซิร์ฟเวอร์
local pickupEvent = ReplicatedStorage:WaitForChild("PickupItem")

-- อ้างอิงผู้เล่นและโฟลเดอร์ไอเทม
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ระยะสูงสุดที่จะแสดง Prompt เก็บไอเทม (หน่วย: สตัด)
local PICKUP_RANGE = 10

-- ตัวแปรเก็บ Part ที่ใกล้ที่สุดในขณะนั้น
local closestPart = nil

----------------------------------------------------------------------------
-- สร้าง UI สำหรับแสดง Prompt เก็บไอเทม
----------------------------------------------------------------------------

-- สร้าง ScreenGui หลัก
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PickupPromptGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- เฟรมพื้นหลังของ Prompt (ธีมมืดแนว Survival)
local promptFrame = Instance.new("Frame")
promptFrame.Name = "PromptFrame"
promptFrame.AnchorPoint = Vector2.new(0.5, 1)
promptFrame.Position = UDim2.new(0.5, 0, 0.92, 0) -- ตำแหน่งกลางล่างของหน้าจอ
promptFrame.Size = UDim2.new(0, 320, 0, 48)
promptFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
promptFrame.BackgroundTransparency = 0.3
promptFrame.BorderSizePixel = 0
promptFrame.Visible = false
promptFrame.Parent = screenGui

-- มุมโค้งมนให้ดูสวยงาม
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = promptFrame

-- ข้อความ '[F]' (สีขาว) แสดงปุ่มกด
local keyLabel = Instance.new("TextLabel")
keyLabel.Name = "KeyLabel"
keyLabel.AnchorPoint = Vector2.new(0, 0.5)
keyLabel.Position = UDim2.new(0, 12, 0.5, 0)
keyLabel.Size = UDim2.new(0, 32, 0, 28)
keyLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
keyLabel.BackgroundTransparency = 0.2
keyLabel.BorderSizePixel = 0
keyLabel.Text = "F"
keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyLabel.TextSize = 16
keyLabel.Font = Enum.Font.GothamBold
keyLabel.Parent = promptFrame

-- มุมโค้งมนสำหรับปุ่ม F
local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 4)
keyCorner.Parent = keyLabel

-- ข้อความ 'Pick up' (สีขาว)
local actionLabel = Instance.new("TextLabel")
actionLabel.Name = "ActionLabel"
actionLabel.AnchorPoint = Vector2.new(0, 0.5)
actionLabel.Position = UDim2.new(0, 52, 0.5, 0)
actionLabel.Size = UDim2.new(0, 60, 1, 0)
actionLabel.BackgroundTransparency = 1
actionLabel.Text = "Pick up"
actionLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
actionLabel.TextSize = 16
actionLabel.Font = Enum.Font.GothamBold
actionLabel.TextXAlignment = Enum.TextXAlignment.Left
actionLabel.Parent = promptFrame

-- ข้อความชื่อไอเทม (สีตามความหายาก)
local itemLabel = Instance.new("TextLabel")
itemLabel.Name = "ItemLabel"
itemLabel.AnchorPoint = Vector2.new(0, 0.5)
itemLabel.Position = UDim2.new(0, 116, 0.5, 0)
itemLabel.Size = UDim2.new(1, -128, 1, 0)
itemLabel.BackgroundTransparency = 1
itemLabel.Text = ""
itemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
itemLabel.TextSize = 16
itemLabel.Font = Enum.Font.GothamBold
itemLabel.TextXAlignment = Enum.TextXAlignment.Left
itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
itemLabel.Parent = promptFrame

----------------------------------------------------------------------------
-- ฟังก์ชันตรวจสอบว่า Inventory เปิดอยู่หรือไม่
----------------------------------------------------------------------------

local function isInventoryOpen()
	-- ตรวจสอบ BoolValue 'InventoryOpen' ใน PlayerGui
	local flag = playerGui:FindFirstChild("InventoryOpen")
	if flag and flag:IsA("BoolValue") then
		return flag.Value
	end
	return false
end

----------------------------------------------------------------------------
-- ฟังก์ชันดึง itemId จากชื่อ Part (รูปแบบ: ItemSpawn_<itemId>)
----------------------------------------------------------------------------

local function getItemIdFromPart(part)
	return string.match(part.Name, "ItemSpawn_(.+)")
end

----------------------------------------------------------------------------
-- วนลูปทุกเฟรมเพื่อหาไอเทมที่ใกล้ที่สุด
----------------------------------------------------------------------------

local scanAccum = 0
RunService.Heartbeat:Connect(function(dt)
	scanAccum = scanAccum + dt
	if scanAccum < 0.1 then return end   -- สแกน 10 ครั้ง/วินาที พอ
	scanAccum = 0

	-- ถ้า Inventory เปิดอยู่ ซ่อน Prompt แล้วข้าม
	if isInventoryOpen() then
		promptFrame.Visible = false
		closestPart = nil
		return
	end

	-- ดึง Character และ HumanoidRootPart ของผู้เล่น
	local character = player.Character
	if not character then
		promptFrame.Visible = false
		closestPart = nil
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		promptFrame.Visible = false
		closestPart = nil
		return
	end

	-- ดึงโฟลเดอร์ ItemSpawns จาก Workspace
	local itemSpawns = workspace:FindFirstChild("ItemSpawns")
	if not itemSpawns then
		promptFrame.Visible = false
		closestPart = nil
		return
	end

	local playerPos = rootPart.Position
	local nearestDist = PICKUP_RANGE
	local nearestPart = nil

	-- วนหา Part ที่ใกล้ที่สุดในระยะ PICKUP_RANGE
	for _, part in ipairs(itemSpawns:GetChildren()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local dist = (part.Position - playerPos).Magnitude
			if dist <= nearestDist then
				-- ตรวจสอบว่า Part นี้มี itemId ที่ถูกต้อง
				local itemId = getItemIdFromPart(part)
				if itemId then
					nearestDist = dist
					nearestPart = part
				end
			end
		end
	end

	-- อัปเดต Prompt ตามผลลัพธ์
	if nearestPart then
		closestPart = nearestPart
		local itemId = getItemIdFromPart(nearestPart)
		local itemData = ItemDatabase.GetItem(itemId)

		if itemData then
			-- แสดงชื่อไอเทมพร้อมสีความหายาก
			local qty = nearestPart:GetAttribute("Quantity")
			if qty and qty > 1 then
				itemLabel.Text = itemData.Name .. "  ?" .. qty
			else
				itemLabel.Text = itemData.Name
			end

			itemLabel.TextColor3 = ItemDatabase.GetRarityColor(itemData.Rarity)
			promptFrame.Visible = true
		else
			-- ไม่พบข้อมูลไอเทมในฐานข้อมูล ซ่อน Prompt
			promptFrame.Visible = false
			closestPart = nil
		end
	else
		-- ไม่มีไอเทมในระยะ ซ่อน Prompt
		promptFrame.Visible = false
		closestPart = nil
	end
end)

----------------------------------------------------------------------------
-- จัดการอินพุตจากผู้เล่น: กดปุ่ม F เพื่อเก็บไอเทม
----------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- ข้ามถ้าเกมประมวลผลอินพุตแล้ว (เช่น พิมพ์ในแชท)
	if gameProcessed then
		return
	end

	-- ตรวจสอบว่ากดปุ่ม F และมีไอเทมที่ใกล้ที่สุดอยู่
	if input.KeyCode == Enum.KeyCode.F and closestPart then
		-- ส่งคำขอเก็บไอเทมไปยังเซิร์ฟเวอร์พร้อม Part อ้างอิง
		pickupEvent:FireServer(closestPart)

		-- ซ่อน Prompt ทันทีเพื่อป้องกันการกดซ้ำ
		promptFrame.Visible = false
		closestPart = nil
	end
end)