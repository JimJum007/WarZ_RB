--------------------------------------------------------------
-- InventoryUI.lua  (LocalScript)
--
-- ?? วางใน: StarterPlayer  StarterPlayerScripts
--    (ไม่ใช่ StarterGui! เพราะ CharacterAutoLoads = false
--     ทำให้ StarterGui ไม่ clone จนกว่าตัวละครจะ Spawn)
--
-- กด I เพื่อเปิด/ปิด Inventory (หลังกด PLAY แล้วเท่านั้น)
--------------------------------------------------------------

local Players               = game:GetService("Players")
local UserInputService      = game:GetService("UserInputService")
local TweenService          = game:GetService("TweenService")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local RunService            = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- โหลด ItemDatabase + RemoteEvents
local ItemDatabase       = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local SyncInventoryEvent = ReplicatedStorage:WaitForChild("SyncInventory")
local EquipItemEvent     = ReplicatedStorage:WaitForChild("EquipItem")
local UnequipItemEvent   = ReplicatedStorage:WaitForChild("UnequipItem")

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  ป้องกัน script ทำงานซ้ำ
-- ออออออออออออออออออออออออออออออออออออออออออออ
if playerGui:FindFirstChild("InventoryGui") then
	return -- มี GUI อยู่แล้ว ไม่สร้างซ้ำ
end

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  ? ปิด Roblox CoreGui ที่กลืนปุ่ม I
--     Avatar Inspect Menu ใช้ปุ่ม I เป็น default
--     ทำให้ InputBegan ไม่ fire สำหรับ I เลย
-- ออออออออออออออออออออออออออออออออออออออออออออ
local StarterGui  = game:GetService("StarterGui")
local GuiService  = game:GetService("GuiService")

-- ปิด Inspect Menu (ปุ่ม I)
pcall(function()
	GuiService:SetInspectMenuEnabled(false)
end)

-- ปิด Backpack เดิมของ Roblox (เราใช้ Inventory เอง)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  SHARED STATE (ให้ CrosshairClient อ่านได้)
-- ออออออออออออออออออออออออออออออออออออออออออออ
local inventoryOpenValue = playerGui:FindFirstChild("InventoryOpen")
if not inventoryOpenValue then
	inventoryOpenValue = Instance.new("BoolValue")
	inventoryOpenValue.Name   = "InventoryOpen"
	inventoryOpenValue.Value  = false
	inventoryOpenValue.Parent = playerGui
end

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  COLOR PALETTE  (Survival / Horror Style)
-- ออออออออออออออออออออออออออออออออออออออออออออ
local C = {
	bg           = Color3.fromRGB(30, 28, 26),
	overlay      = Color3.fromRGB(0, 0, 0),

	tabActive    = Color3.fromRGB(150, 30, 30),
	tabInactive  = Color3.fromRGB(55, 50, 45),
	tabHover     = Color3.fromRGB(75, 70, 65),
	topBar       = Color3.fromRGB(40, 37, 34),

	slot         = Color3.fromRGB(45, 42, 38),
	slotBorder   = Color3.fromRGB(90, 25, 25),
	slotHover    = Color3.fromRGB(58, 54, 48),
	slotSelected = Color3.fromRGB(70, 45, 40),

	bpBar        = Color3.fromRGB(40, 38, 35),
	btnRed       = Color3.fromRGB(140, 35, 35),
	btnRedHover  = Color3.fromRGB(165, 50, 50),

	text         = Color3.fromRGB(220, 210, 190),
	textSub      = Color3.fromRGB(160, 150, 135),
	textDim      = Color3.fromRGB(100, 95, 85),
	textGold     = Color3.fromRGB(220, 180, 80),

	detailBg     = Color3.fromRGB(38, 35, 32),
	weightBg     = Color3.fromRGB(55, 50, 45),
	weightFill   = Color3.fromRGB(150, 35, 35),
	separator    = Color3.fromRGB(70, 60, 55),
	equipLabel   = Color3.fromRGB(130, 125, 115),

	backBtn      = Color3.fromRGB(50, 47, 43),
	backBtnHover = Color3.fromRGB(65, 60, 55),
}

local FONT_BOLD    = Enum.Font.GothamBold
local FONT_SEMI    = Enum.Font.GothamSemibold
local FONT_REGULAR = Enum.Font.Gotham

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  INVENTORY DATA  (ข้อมูลจาก Server)
-- ออออออออออออออออออออออออออออออออออออออออออออ
local equippedItems = {
	primary   = nil,  -- { name, desc, itemId }
	secondary = nil,
	armor     = nil,
	headgear  = nil,
}

local gridItems = {}  -- [1..20] = { name, desc, itemId, quantity } or nil

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  STATE
-- ออออออออออออออออออออออออออออออออออออออออออออ
local isOpen          = false
local activeTab       = "INVENTORY"
local selectedSlot    = nil
local gameStarted     = false
local savedWalkSpeed  = nil   -- เก็บค่า WalkSpeed ก่อนเปิด Inventory
local savedJumpPower  = nil   -- เก็บค่า JumpPower ก่อนเปิด Inventory

-- forward declarations
local detailPreview, detailNameLbl, detailDescLbl

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  UTILITY HELPERS
-- ออออออออออออออออออออออออออออออออออออออออออออ
local function addCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 4)
	c.Parent = parent
	return c
end

local function addStroke(parent, col, th)
	local s = Instance.new("UIStroke")
	s.Color     = col or C.slotBorder
	s.Thickness = th  or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addPad(parent, t, b, l, r)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, t or 0)
	p.PaddingBottom = UDim.new(0, b or 0)
	p.PaddingLeft   = UDim.new(0, l or 0)
	p.PaddingRight  = UDim.new(0, r or 0)
	p.Parent = parent
	return p
end

local function tweenColor(obj, prop, color, dur)
	TweenService:Create(
		obj,
		TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad),
		{[prop] = color}
	):Play()
end

local selectedSource = nil   -- "grid" or "equip"
local selectedIndex  = nil   -- grid slot number or equip key ("primary" etc.)

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  FORWARD DECLARATIONS สำหรับฟังก์ชัน UI
-- ออออออออออออออออออออออออออออออออออออออออออออ
local showDetail
local selectSlot

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  เปิด / ปิด INVENTORY
-- ออออออออออออออออออออออออออออออออออออออออออออ
local gui -- สร้างด้านล่าง

local function openInventory()
	isOpen = true
	gui.Enabled = true
	gui.DisplayOrder = 1000
	inventoryOpenValue.Value = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	GuiService.SelectedObject = nil

	-- ? หยุดตัวละครเดิน (ป้องกันตัวละครขยับตอนเปิด Inventory)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			savedWalkSpeed = humanoid.WalkSpeed
			savedJumpPower = humanoid.JumpPower
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end
end

local function closeInventory()
	isOpen = false
	gui.Enabled = false
	gui.DisplayOrder = 10
	inventoryOpenValue.Value = false

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	GuiService.SelectedObject = nil

	-- ? คืนค่าเดิน/กระโดดให้ตัวละคร
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if savedWalkSpeed then humanoid.WalkSpeed = savedWalkSpeed end
			if savedJumpPower then humanoid.JumpPower = savedJumpPower end
		end
	end
	savedWalkSpeed = nil
	savedJumpPower = nil
end

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  SCREEN GUI
-- ออออออออออออออออออออออออออออออออออออออออออออ
gui = Instance.new("ScreenGui")
gui.Name           = "InventoryGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 10
gui.Enabled        = false
gui.Parent         = playerGui

-- ฤฤ dark overlay ฤฤ
local overlay = Instance.new("Frame")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = C.overlay
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel        = 0
overlay.ZIndex                 = 1
overlay.Parent                 = gui

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  MAIN FRAME
-- ออออออออออออออออออออออออออออออออออออออออออออ
local main = Instance.new("Frame")
main.Name             = "MainFrame"
main.AnchorPoint      = Vector2.new(0.5, 0.5)
main.Position         = UDim2.new(0.5, 0, 0.5, 0)
main.Size             = UDim2.new(0, 1120, 0, 660)
main.BackgroundColor3 = C.bg
main.BorderSizePixel  = 0
main.ZIndex           = 2
main.Parent           = gui
addCorner(main, 6)
addStroke(main, Color3.fromRGB(55, 48, 42), 2)

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  TOP NAVIGATION BAR
-- ออออออออออออออออออออออออออออออออออออออออออออ
local topBar = Instance.new("Frame")
topBar.Name             = "TopBar"
topBar.Size             = UDim2.new(1, 0, 0, 44)
topBar.BackgroundColor3 = C.topBar
topBar.BorderSizePixel  = 0
topBar.ZIndex           = 3
topBar.Parent           = main
addCorner(topBar, 6)

local topCover = Instance.new("Frame")
topCover.Size             = UDim2.new(1, 0, 0, 12)
topCover.Position         = UDim2.new(0, 0, 1, -12)
topCover.BackgroundColor3 = C.topBar
topCover.BorderSizePixel  = 0
topCover.ZIndex           = 3
topCover.Parent           = topBar

local accentLine = Instance.new("Frame")
accentLine.Size             = UDim2.new(1, 0, 0, 2)
accentLine.Position         = UDim2.new(0, 0, 1, 0)
accentLine.BackgroundColor3 = C.slotBorder
accentLine.BorderSizePixel  = 0
accentLine.ZIndex           = 3
accentLine.Parent           = topBar

local tabListLayout = Instance.new("UIListLayout")
tabListLayout.FillDirection = Enum.FillDirection.Horizontal
tabListLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tabListLayout.Padding       = UDim.new(0, 3)
tabListLayout.Parent        = topBar
addPad(topBar, 5, 0, 10, 0)

local tabs    = {"INVENTORY", "MAP", "MISSIONS", "OPTIONS", "QUIT"}
local tabBtns = {}

for i, name in ipairs(tabs) do
	local btn = Instance.new("TextButton")
	btn.Name             = "Tab_" .. name
	btn.Size             = UDim2.new(0, 135, 1, -5)
	btn.BackgroundColor3 = (name == activeTab) and C.tabActive or C.tabInactive
	btn.BorderSizePixel  = 0
	btn.Text             = name
	btn.TextColor3       = C.text
	btn.TextSize         = 14
	btn.Font             = FONT_BOLD
	btn.LayoutOrder      = i
	btn.AutoButtonColor  = false
	btn.ZIndex           = 4
	btn.Parent           = topBar
	addCorner(btn, 4)

	tabBtns[name] = btn

	btn.MouseEnter:Connect(function()
		if name ~= activeTab then tweenColor(btn, "BackgroundColor3", C.tabHover) end
	end)
	btn.MouseLeave:Connect(function()
		if name ~= activeTab then tweenColor(btn, "BackgroundColor3", C.tabInactive) end
	end)
	btn.MouseButton1Click:Connect(function()
		for n, b in pairs(tabBtns) do
			tweenColor(b, "BackgroundColor3", n == name and C.tabActive or C.tabInactive)
		end
		activeTab = name
	end)
end

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  CONTENT AREA
-- ออออออออออออออออออออออออออออออออออออออออออออ
local content = Instance.new("Frame")
content.Name                   = "Content"
content.Size                   = UDim2.new(1, -24, 1, -58)
content.Position               = UDim2.new(0, 12, 0, 50)
content.BackgroundTransparency = 1
content.ZIndex                 = 3
content.Parent                 = main

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  LEFT PANEL  (58%)
-- ออออออออออออออออออออออออออออออออออออออออออออ
local leftPanel = Instance.new("Frame")
leftPanel.Name                   = "LeftPanel"
leftPanel.Size                   = UDim2.new(0.58, 0, 1, 0)
leftPanel.BackgroundTransparency = 1
leftPanel.ZIndex                 = 3
leftPanel.Parent                 = content

-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
--  EQUIPMENT SLOTS  (4 ช่อง)
-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
local equipRow = Instance.new("Frame")
equipRow.Name                   = "EquipmentRow"
equipRow.Size                   = UDim2.new(1, 0, 0, 105)
equipRow.BackgroundTransparency = 1
equipRow.ZIndex                 = 3
equipRow.Parent                 = leftPanel

local equipListLayout2 = Instance.new("UIListLayout")
equipListLayout2.FillDirection = Enum.FillDirection.Horizontal
equipListLayout2.SortOrder     = Enum.SortOrder.LayoutOrder
equipListLayout2.Padding       = UDim.new(0, 8)
equipListLayout2.Parent        = equipRow

local equipDefs = {
	{ key = "primary",   label = "PRIMARY WEAPON",   sub = "Rifle / Shotgun" },
	{ key = "secondary", label = "SECONDARY WEAPON", sub = "Pistol / Knife"  },
	{ key = "armor",     label = "ARMOR",            sub = "Body Armor"      },
	{ key = "headgear",  label = "HEADGEAR",         sub = "Hat / Helmet"    },
}

for i, def in ipairs(equipDefs) do
	local wrap = Instance.new("Frame")
	wrap.Name                   = "EQ_" .. def.key
	wrap.Size                   = UDim2.new(0.25, -6, 1, 0)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder            = i
	wrap.ZIndex                 = 3
	wrap.Parent                 = equipRow

	local box = Instance.new("TextButton")
	box.Name             = "Box"
	box.Size             = UDim2.new(1, 0, 0, 72)
	box.BackgroundColor3 = C.slot
	box.BorderSizePixel  = 0
	box.Text             = ""
	box.AutoButtonColor  = false
	box.ZIndex           = 4
	box.Parent           = wrap
	addCorner(box, 4)
	addStroke(box, C.slotBorder, 1)

	local iconBg = Instance.new("Frame")
	iconBg.Size             = UDim2.new(0, 38, 0, 38)
	iconBg.AnchorPoint      = Vector2.new(0.5, 0)
	iconBg.Position         = UDim2.new(0.5, 0, 0, 5)
	iconBg.BackgroundColor3 = Color3.fromRGB(38, 36, 33)
	iconBg.BorderSizePixel  = 0
	iconBg.ZIndex           = 5
	iconBg.Parent           = box
	addCorner(iconBg, 4)

	local eqItem = equippedItems[def.key]
	if eqItem then
		local nm = Instance.new("TextLabel")
		nm.Size                   = UDim2.new(1, -8, 0, 16)
		nm.Position               = UDim2.new(0, 4, 1, -20)
		nm.BackgroundTransparency = 1
		nm.Text                   = eqItem.name
		nm.TextColor3             = C.textSub
		nm.TextSize               = 10
		nm.Font                   = FONT_SEMI
		nm.TextTruncate           = Enum.TextTruncate.AtEnd
		nm.ZIndex                 = 5
		nm.Parent                 = box
	end

	box.MouseEnter:Connect(function()
		if box ~= selectedSlot then tweenColor(box, "BackgroundColor3", C.slotHover) end
	end)
	box.MouseLeave:Connect(function()
		if box ~= selectedSlot then tweenColor(box, "BackgroundColor3", C.slot) end
	end)
	box.MouseButton1Click:Connect(function()
		local currentEquip = equippedItems[def.key]
		if currentEquip then
			selectSlot(box, currentEquip, "equip", def.key)
		end
	end)

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, 0, 0, 13)
	lbl.Position               = UDim2.new(0, 0, 0, 75)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = def.label
	lbl.TextColor3             = C.equipLabel
	lbl.TextSize               = 9
	lbl.Font                   = FONT_BOLD
	lbl.TextXAlignment         = Enum.TextXAlignment.Left
	lbl.ZIndex                 = 4
	lbl.Parent                 = wrap

	local sub = Instance.new("TextLabel")
	sub.Size                   = UDim2.new(1, 0, 0, 12)
	sub.Position               = UDim2.new(0, 0, 0, 89)
	sub.BackgroundTransparency = 1
	sub.Text                   = def.sub
	sub.TextColor3             = C.textDim
	sub.TextSize               = 8
	sub.Font                   = FONT_REGULAR
	sub.TextXAlignment         = Enum.TextXAlignment.Left
	sub.ZIndex                 = 4
	sub.Parent                 = wrap
end

-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
--  BACKPACK INFO BAR
-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
local bpBar = Instance.new("Frame")
bpBar.Name             = "BackpackBar"
bpBar.Size             = UDim2.new(1, 0, 0, 52)
bpBar.Position         = UDim2.new(0, 0, 0, 112)
bpBar.BackgroundColor3 = C.bpBar
bpBar.BorderSizePixel  = 0
bpBar.ZIndex           = 3
bpBar.Parent           = leftPanel
addCorner(bpBar, 4)
addStroke(bpBar, C.separator, 1)

local bpTypeL = Instance.new("TextLabel")
bpTypeL.Size                   = UDim2.new(0, 120, 0, 14)
bpTypeL.Position               = UDim2.new(0, 14, 0, 6)
bpTypeL.BackgroundTransparency = 1
bpTypeL.Text                   = "BACKPACK TYPE"
bpTypeL.TextColor3             = C.textDim
bpTypeL.TextSize               = 9
bpTypeL.Font                   = FONT_BOLD
bpTypeL.TextXAlignment         = Enum.TextXAlignment.Left
bpTypeL.ZIndex                 = 4
bpTypeL.Parent                 = bpBar

local bpNameL = Instance.new("TextLabel")
bpNameL.Size                   = UDim2.new(0, 200, 0, 20)
bpNameL.Position               = UDim2.new(0, 14, 0, 24)
bpNameL.BackgroundTransparency = 1
bpNameL.Text                   = "MEDIUM BACKPACK"
bpNameL.TextColor3             = C.text
bpNameL.TextSize               = 14
bpNameL.Font                   = FONT_BOLD
bpNameL.TextXAlignment         = Enum.TextXAlignment.Left
bpNameL.ZIndex                 = 4
bpNameL.Parent                 = bpBar

local wBarBg = Instance.new("Frame")
wBarBg.Size             = UDim2.new(0, 160, 0, 8)
wBarBg.Position         = UDim2.new(1, -310, 0.5, -4)
wBarBg.BackgroundColor3 = C.weightBg
wBarBg.BorderSizePixel  = 0
wBarBg.ZIndex           = 4
wBarBg.Parent           = bpBar
addCorner(wBarBg, 4)

local wFill = Instance.new("Frame")
wFill.Size             = UDim2.new(0.15, 0, 1, 0)
wFill.BackgroundColor3 = C.weightFill
wFill.BorderSizePixel  = 0
wFill.ZIndex           = 5
wFill.Parent           = wBarBg
addCorner(wFill, 4)

local wMax = Instance.new("TextLabel")
wMax.Size                   = UDim2.new(0, 65, 0, 20)
wMax.Position               = UDim2.new(1, -140, 0.5, -10)
wMax.BackgroundTransparency = 1
wMax.Text                   = "200 LBS"
wMax.TextColor3             = C.text
wMax.TextSize               = 12
wMax.Font                   = FONT_BOLD
wMax.TextXAlignment         = Enum.TextXAlignment.Left
wMax.ZIndex                 = 4
wMax.Parent                 = bpBar

local wCur = Instance.new("TextLabel")
wCur.Size                   = UDim2.new(0, 65, 0, 20)
wCur.Position               = UDim2.new(1, -70, 0.5, -10)
wCur.BackgroundTransparency = 1
wCur.Text                   = "30 LBS"
wCur.TextColor3             = C.textSub
wCur.TextSize               = 12
wCur.Font                   = FONT_REGULAR
wCur.TextXAlignment         = Enum.TextXAlignment.Left
wCur.ZIndex                 = 4
wCur.Parent                 = bpBar

-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
--  INVENTORY GRID  (5 ? 4 = 20 slots)
-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
local gridOuter = Instance.new("Frame")
gridOuter.Name             = "GridOuter"
gridOuter.Size             = UDim2.new(1, 0, 0, 380)
gridOuter.Position         = UDim2.new(0, 0, 0, 172)
gridOuter.BackgroundColor3 = Color3.fromRGB(34, 32, 29)
gridOuter.BorderSizePixel  = 0
gridOuter.ZIndex           = 3
gridOuter.Parent           = leftPanel
addCorner(gridOuter, 4)
addStroke(gridOuter, C.separator, 1)

local gridInner = Instance.new("Frame")
gridInner.Name                   = "GridInner"
gridInner.Size                   = UDim2.new(1, -16, 1, -16)
gridInner.Position               = UDim2.new(0, 8, 0, 8)
gridInner.BackgroundTransparency = 1
gridInner.ZIndex                 = 3
gridInner.Parent                 = gridOuter

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize              = UDim2.new(0.2, -5, 0.25, -5)
gridLayout.CellPadding           = UDim2.new(0, 5, 0, 5)
gridLayout.SortOrder             = Enum.SortOrder.LayoutOrder
gridLayout.FillDirection         = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = 5
gridLayout.Parent                = gridInner

for i = 1, 20 do
	local slot = Instance.new("TextButton")
	slot.Name             = "Slot_" .. i
	slot.BackgroundColor3 = C.slot
	slot.BorderSizePixel  = 0
	slot.Text             = ""
	slot.LayoutOrder      = i
	slot.AutoButtonColor  = false
	slot.ZIndex           = 4
	slot.Parent           = gridInner
	addCorner(slot, 3)
	addStroke(slot, C.slotBorder, 1)

	local item = gridItems[i]

	if item then
		local ico = Instance.new("Frame")
		ico.Size             = UDim2.new(0, 34, 0, 34)
		ico.AnchorPoint      = Vector2.new(0.5, 0)
		ico.Position         = UDim2.new(0.5, 0, 0, 6)
		ico.BackgroundColor3 = Color3.fromRGB(38, 36, 33)
		ico.BorderSizePixel  = 0
		ico.ZIndex           = 5
		ico.Parent           = slot
		addCorner(ico, 4)

		local nm = Instance.new("TextLabel")
		nm.Size                   = UDim2.new(1, -8, 0, 28)
		nm.Position               = UDim2.new(0, 4, 1, -30)
		nm.BackgroundTransparency = 1
		nm.Text                   = item.name
		nm.TextColor3             = C.textSub
		nm.TextSize               = 9
		nm.Font                   = FONT_SEMI
		nm.TextWrapped            = true
		nm.TextXAlignment         = Enum.TextXAlignment.Left
		nm.TextYAlignment         = Enum.TextYAlignment.Bottom
		nm.ZIndex                 = 5
		nm.Parent                 = slot

		if item.stack then
			local badge = Instance.new("TextLabel")
			badge.Size             = UDim2.new(0, 30, 0, 16)
			badge.Position         = UDim2.new(1, -34, 0, 4)
			badge.BackgroundColor3 = Color3.fromRGB(62, 57, 52)
			badge.BorderSizePixel  = 0
			badge.Text             = "x" .. item.stack
			badge.TextColor3       = C.text
			badge.TextSize         = 10
			badge.Font             = FONT_BOLD
			badge.ZIndex           = 6
			badge.Parent           = slot
			addCorner(badge, 3)
		end
	end

	slot.MouseEnter:Connect(function()
		if slot ~= selectedSlot then tweenColor(slot, "BackgroundColor3", C.slotHover) end
	end)
	slot.MouseLeave:Connect(function()
		if slot ~= selectedSlot then tweenColor(slot, "BackgroundColor3", C.slot) end
	end)
	slot.MouseButton1Click:Connect(function()
		local currentItem = gridItems[i]
		if currentItem then
			selectSlot(slot, currentItem, "grid", i)
		end
	end)
end

-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
--  CHANGE BACKPACK BUTTON
-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
local changeBp = Instance.new("TextButton")
changeBp.Name             = "ChangeBackpack"
changeBp.Size             = UDim2.new(0, 230, 0, 38)
changeBp.AnchorPoint      = Vector2.new(0.5, 0)
changeBp.Position         = UDim2.new(0.5, 0, 0, 560)
changeBp.BackgroundColor3 = C.btnRed
changeBp.BorderSizePixel  = 0
changeBp.Text             = ""
changeBp.AutoButtonColor  = false
changeBp.ZIndex           = 4
changeBp.Parent           = leftPanel
addCorner(changeBp, 4)

local circleIco = Instance.new("Frame")
circleIco.Size             = UDim2.new(0, 22, 0, 22)
circleIco.Position         = UDim2.new(0, 14, 0.5, -11)
circleIco.BackgroundColor3 = Color3.fromRGB(105, 25, 25)
circleIco.BorderSizePixel  = 0
circleIco.ZIndex           = 5
circleIco.Parent           = changeBp
addCorner(circleIco, 11)

local changeTxt = Instance.new("TextLabel")
changeTxt.Size                   = UDim2.new(1, -48, 1, 0)
changeTxt.Position               = UDim2.new(0, 44, 0, 0)
changeTxt.BackgroundTransparency = 1
changeTxt.Text                   = "CHANGE BACKPACK"
changeTxt.TextColor3             = C.text
changeTxt.TextSize               = 13
changeTxt.Font                   = FONT_BOLD
changeTxt.TextXAlignment         = Enum.TextXAlignment.Left
changeTxt.ZIndex                 = 5
changeTxt.Parent                 = changeBp

changeBp.MouseEnter:Connect(function()
	tweenColor(changeBp, "BackgroundColor3", C.btnRedHover)
end)
changeBp.MouseLeave:Connect(function()
	tweenColor(changeBp, "BackgroundColor3", C.btnRed)
end)

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  RIGHT PANEL  (42%)  —  Item Detail
-- ออออออออออออออออออออออออออออออออออออออออออออ
local rightPanel = Instance.new("Frame")
rightPanel.Name                   = "RightPanel"
rightPanel.Size                   = UDim2.new(0.42, 0, 1, 0)
rightPanel.Position               = UDim2.new(0.58, 8, 0, 0)
rightPanel.BackgroundTransparency = 1
rightPanel.ZIndex                 = 3
rightPanel.Parent                 = content

detailPreview = Instance.new("Frame")
detailPreview.Name             = "Preview"
detailPreview.Size             = UDim2.new(1, 0, 0, 300)
detailPreview.BackgroundColor3 = C.detailBg
detailPreview.BorderSizePixel  = 0
detailPreview.ZIndex           = 4
detailPreview.Parent           = rightPanel
addCorner(detailPreview, 4)
addStroke(detailPreview, C.separator, 1)

local bigIco = Instance.new("Frame")
bigIco.Size             = UDim2.new(0, 120, 0, 120)
bigIco.AnchorPoint      = Vector2.new(0.5, 0.5)
bigIco.Position         = UDim2.new(0.5, 0, 0.45, 0)
bigIco.BackgroundColor3 = Color3.fromRGB(48, 45, 40)
bigIco.BorderSizePixel  = 0
bigIco.ZIndex           = 5
bigIco.Parent           = detailPreview
addCorner(bigIco, 8)

local bigIcoLabel = Instance.new("TextLabel")
bigIcoLabel.Size                   = UDim2.new(1, 0, 1, 0)
bigIcoLabel.BackgroundTransparency = 1
bigIcoLabel.Text                   = "[ PREVIEW ]"
bigIcoLabel.TextColor3             = C.textDim
bigIcoLabel.TextSize               = 13
bigIcoLabel.Font                   = FONT_REGULAR
bigIcoLabel.ZIndex                 = 6
bigIcoLabel.Parent                 = bigIco

local detailBox = Instance.new("Frame")
detailBox.Name             = "DetailBox"
detailBox.Size             = UDim2.new(1, 0, 0, 290)
detailBox.Position         = UDim2.new(0, 0, 0, 308)
detailBox.BackgroundColor3 = C.detailBg
detailBox.BorderSizePixel  = 0
detailBox.ZIndex           = 4
detailBox.Parent           = rightPanel
addCorner(detailBox, 4)
addStroke(detailBox, C.separator, 1)

detailNameLbl = Instance.new("TextLabel")
detailNameLbl.Name                   = "ItemName"
detailNameLbl.Size                   = UDim2.new(1, -24, 0, 30)
detailNameLbl.Position               = UDim2.new(0, 12, 0, 12)
detailNameLbl.BackgroundTransparency = 1
detailNameLbl.Text                   = ""
detailNameLbl.TextColor3             = C.textGold
detailNameLbl.TextSize               = 18
detailNameLbl.Font                   = FONT_BOLD
detailNameLbl.TextXAlignment         = Enum.TextXAlignment.Left
detailNameLbl.TextYAlignment         = Enum.TextYAlignment.Top
detailNameLbl.ZIndex                 = 5
detailNameLbl.Parent                 = detailBox

local detailSep = Instance.new("Frame")
detailSep.Size             = UDim2.new(1, -24, 0, 1)
detailSep.Position         = UDim2.new(0, 12, 0, 46)
detailSep.BackgroundColor3 = C.separator
detailSep.BorderSizePixel  = 0
detailSep.ZIndex           = 5
detailSep.Parent           = detailBox

detailDescLbl = Instance.new("TextLabel")
detailDescLbl.Name                   = "ItemDesc"
detailDescLbl.Size                   = UDim2.new(1, -24, 1, -60)
detailDescLbl.Position               = UDim2.new(0, 12, 0, 54)
detailDescLbl.BackgroundTransparency = 1
detailDescLbl.Text                   = "Select an item to view details."
detailDescLbl.TextColor3             = C.textSub
detailDescLbl.TextSize               = 13
detailDescLbl.Font                   = FONT_REGULAR
detailDescLbl.TextWrapped            = true
detailDescLbl.TextXAlignment         = Enum.TextXAlignment.Left
detailDescLbl.TextYAlignment         = Enum.TextYAlignment.Top
detailDescLbl.LineHeight             = 1.35
detailDescLbl.ZIndex                 = 5
detailDescLbl.Parent                 = detailBox

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  BACK TO GAME BUTTON
-- ออออออออออออออออออออออออออออออออออออออออออออ
local backBtn = Instance.new("TextButton")
backBtn.Name             = "BackToGame"
backBtn.Size             = UDim2.new(0, 185, 0, 38)
backBtn.Position         = UDim2.new(1, -197, 1, -48)
backBtn.BackgroundColor3 = C.backBtn
backBtn.BorderSizePixel  = 0
backBtn.Text             = "BACK TO GAME"
backBtn.TextColor3       = C.text
backBtn.TextSize         = 13
backBtn.Font             = FONT_BOLD
backBtn.AutoButtonColor  = false
backBtn.ZIndex           = 4
backBtn.Parent           = main
addCorner(backBtn, 4)
addStroke(backBtn, C.separator, 1)

backBtn.MouseEnter:Connect(function()
	tweenColor(backBtn, "BackgroundColor3", C.backBtnHover)
end)
backBtn.MouseLeave:Connect(function()
	tweenColor(backBtn, "BackgroundColor3", C.backBtn)
end)
backBtn.MouseButton1Click:Connect(function()
	closeInventory()
end)
function showDetail(item, source, index)
	-- ซ่อนปุ่ม action เก่า
	if detailBox then
		local oldBtn = detailBox:FindFirstChild("ActionBtn")
		if oldBtn then oldBtn:Destroy() end
	end

	if not item then
		detailNameLbl.Text = ""
		detailDescLbl.Text = "Select an item to view details."
		return
	end

	detailNameLbl.Text = string.upper(item.name)
	detailDescLbl.Text = item.desc or ""

	-- สร้างปุ่ม EQUIP / UNEQUIP
	if source and detailBox then
		local actionBtn = Instance.new("TextButton")
		actionBtn.Name             = "ActionBtn"
		actionBtn.Size             = UDim2.new(0, 140, 0, 32)
		actionBtn.Position         = UDim2.new(1, -152, 1, -44)
		actionBtn.BorderSizePixel  = 0
		actionBtn.AutoButtonColor  = false
		actionBtn.Font             = FONT_BOLD
		actionBtn.TextSize         = 12
		actionBtn.ZIndex           = 6
		actionBtn.Parent           = detailBox
		addCorner(actionBtn, 4)

		if source == "grid" then
			-- ปุ่ม EQUIP (ถ้าเป็น equipment item)
			local equipSlot = ItemDatabase.GetEquipSlot(item.itemId)
			if equipSlot then
				actionBtn.Text             = " EQUIP"
				actionBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
				actionBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
				actionBtn.MouseButton1Click:Connect(function()
					EquipItemEvent:FireServer(index)
				end)
			else
				actionBtn:Destroy()  -- ไม่ใช่ equipment item
			end
		elseif source == "equip" then
			-- ปุ่ม UNEQUIP
			local slotMap = { primary = "Primary", secondary = "Secondary", armor = "Armor", headgear = "Headgear" }
			actionBtn.Text             = " UNEQUIP"
			actionBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
			actionBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 50)
			actionBtn.MouseButton1Click:Connect(function()
				UnequipItemEvent:FireServer(slotMap[index])
			end)
		end
	end
end

function selectSlot(btn, item, source, index)
	if selectedSlot and selectedSlot ~= btn then
		tweenColor(selectedSlot, "BackgroundColor3", C.slot)
	end
	selectedSlot   = btn
	selectedSource = source
	selectedIndex  = index
	tweenColor(btn, "BackgroundColor3", C.slotSelected)
	showDetail(item, source, index)
end

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  REFRESH UI จาก Server Data
-- ออออออออออออออออออออออออออออออออออออออออออออ
local function refreshUI()
	-- ฤฤฤฤฤ อัพเดต Grid Slots ฤฤฤฤฤ
	for i = 1, 20 do
		local slot = gridInner:FindFirstChild("Slot_" .. i)
		if not slot then continue end

		-- ลบ child เก่า (icon, name, badge) ยกเว้น UICorner/UIStroke
		for _, child in ipairs(slot:GetChildren()) do
			if not child:IsA("UICorner") and not child:IsA("UIStroke") then
				child:Destroy()
			end
		end
		local item = gridItems[i]

		if item then
			-- Icon placeholder
			local ico = Instance.new("Frame")
			ico.Size             = UDim2.new(0, 34, 0, 34)
			ico.AnchorPoint      = Vector2.new(0.5, 0)
			ico.Position         = UDim2.new(0.5, 0, 0, 6)
			ico.BackgroundColor3 = Color3.fromRGB(38, 36, 33)
			ico.BorderSizePixel  = 0
			ico.ZIndex           = 5
			ico.Parent           = slot
			addCorner(ico, 4)

			-- Item name
			local nm = Instance.new("TextLabel")
			nm.Size                   = UDim2.new(1, -8, 0, 28)
			nm.Position               = UDim2.new(0, 4, 1, -30)
			nm.BackgroundTransparency = 1
			nm.Text                   = item.name
			nm.TextColor3             = C.textSub
			nm.TextSize               = 9
			nm.Font                   = FONT_SEMI
			nm.TextWrapped            = true
			nm.TextXAlignment         = Enum.TextXAlignment.Left
			nm.TextYAlignment         = Enum.TextYAlignment.Bottom
			nm.ZIndex                 = 5
			nm.Parent                 = slot

			-- Stack badge
			if item.quantity and item.quantity > 1 then
				local badge = Instance.new("TextLabel")
				badge.Size             = UDim2.new(0, 30, 0, 16)
				badge.Position         = UDim2.new(1, -34, 0, 4)
				badge.BackgroundColor3 = Color3.fromRGB(62, 57, 52)
				badge.BorderSizePixel  = 0
				badge.Text             = "x" .. item.quantity
				badge.TextColor3       = C.text
				badge.TextSize         = 10
				badge.Font             = FONT_BOLD
				badge.ZIndex           = 6
				badge.Parent           = slot
				addCorner(badge, 3)
			end
		end
	end

	-- ฤฤฤฤฤ อัพเดต Equipment Slots ฤฤฤฤฤ
	local slotMap = { primary = "Primary", secondary = "Secondary", armor = "Armor", headgear = "Headgear" }
	for key, slotName in pairs(slotMap) do
		local wrap = equipRow:FindFirstChild("EQ_" .. key)
		if not wrap then continue end
		local box = wrap:FindFirstChild("Box")
		if not box then continue end

		-- ลบ name label เก่า
		for _, child in ipairs(box:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		local eqItem = equippedItems[key]
		if eqItem then
			local nm = Instance.new("TextLabel")
			nm.Size                   = UDim2.new(1, -8, 0, 16)
			nm.Position               = UDim2.new(0, 4, 1, -20)
			nm.BackgroundTransparency = 1
			nm.Text                   = eqItem.name
			nm.TextColor3             = C.textSub
			nm.TextSize               = 10
			nm.Font                   = FONT_SEMI
			nm.TextTruncate           = Enum.TextTruncate.AtEnd
			nm.ZIndex                 = 5
			nm.Parent                 = box
		end
	end

	-- รีเซ็ตปุ่มที่เลือกไว้ก่อนหน้าให้เป็นสีพื้นปกติ (ก่อนจะ select ใหม่)
	if selectedSlot then
		tweenColor(selectedSlot, "BackgroundColor3", C.slot)
	end
	selectedSlot = nil

	-- พยายาม re-select ช่องเดิม (ถ้ายังมีไอเทมอยู่)
	if selectedSource == "grid" and selectedIndex then
		local item = gridItems[selectedIndex]
		local newSlotBtn = gridInner:FindFirstChild("Slot_" .. selectedIndex)
		if item and newSlotBtn then
			selectSlot(newSlotBtn, item, "grid", selectedIndex)
		else
			showDetail(nil)
		end
	elseif selectedSource == "equip" and selectedIndex then
		local eqItem = equippedItems[selectedIndex]
		local wrap = equipRow:FindFirstChild("EQ_" .. selectedIndex)
		if eqItem and wrap then
			local newBox = wrap:FindFirstChild("Box")
			if newBox then
				selectSlot(newBox, eqItem, "equip", selectedIndex)
			else
				showDetail(nil)
			end
		else
			showDetail(nil)
		end
	else
		showDetail(nil)
	end
end

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  รับ Inventory Sync จาก Server
-- ออออออออออออออออออออออออออออออออออออออออออออ
SyncInventoryEvent.OnClientEvent:Connect(function(data)
	if not data then return end

	-- อัพเดต gridItems
	gridItems = {}
	if data.grid then
		for i, slotData in pairs(data.grid) do
			local idx = tonumber(i)
			if idx and slotData.itemId then
				local itemData = ItemDatabase.GetItem(slotData.itemId)
				if itemData then
					gridItems[idx] = {
						name     = itemData.Name,
						desc     = itemData.Description,
						itemId   = slotData.itemId,
						quantity = slotData.quantity or 1,
					}
				end
			end
		end
	end

	-- อัพเดต equippedItems
	equippedItems = { primary = nil, secondary = nil, armor = nil, headgear = nil }
	if data.equipment then
		local keyMap = { Primary = "primary", Secondary = "secondary", Armor = "armor", Headgear = "headgear" }
		for slot, eqData in pairs(data.equipment) do
			local key = keyMap[slot]
			if key and eqData.itemId then
				local itemData = ItemDatabase.GetItem(eqData.itemId)
				if itemData then
					equippedItems[key] = {
						name   = itemData.Name,
						desc   = itemData.Description,
						itemId = eqData.itemId,
						ammo   = eqData.ammo,
					}
				end
			end
		end
	end

	refreshUI()
end)

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  TOGGLE INPUT  (Press I)
--  ? ใช้ ContextActionService:BindActionAtPriority
--     ด้วย priority สูงสุด (10000)
--     เพื่อแย่งปุ่ม I คืนจาก Roblox core scripts
--     ที่ bind ปุ่ม I ด้วย priority ต่ำกว่า
-- ออออออออออออออออออออออออออออออออออออออออออออ
local ContextActionService = game:GetService("ContextActionService")

local function handleInventoryToggle(_actionName, inputState, _inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if not gameStarted then
		return Enum.ContextActionResult.Pass
	end

	-- ป้องกันตอนพิมพ์ chat
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end

	print("[InventoryUI] Toggle! isOpen:", isOpen, "->", not isOpen)

	if isOpen then
		closeInventory()
	else
		openInventory()
	end

	-- Sink = กลืน input ไม่ให้ core scripts เห็น
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"ToggleInventory",
	handleInventoryToggle,
	false,
	10000,
	Enum.KeyCode.B,
	Enum.KeyCode.I
)

print("[InventoryUI] Bound to B/I keys")

-- ออออออออออออออออออออออออออออออออออออออออออออ
--  รอ StartGameplay  เปิดให้กด I ได้
-- ออออออออออออออออออออออออออออออออออออออออออออ
local startGameplayEvent = ReplicatedStorage:WaitForChild("StartGameplay")
startGameplayEvent.OnClientEvent:Connect(function()
	gameStarted = true
	print("[InventoryUI] Game started — press I to toggle inventory")
end)

print("[InventoryUI] Script loaded, waiting for PLAY...")