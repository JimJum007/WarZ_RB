--------------------------------------------------------------
-- HUDClient.lua  (LocalScript — StarterPlayerScripts)
-- HP bar + Ammo + ชื่ออาวุธ + Hitmarker + Damage flash
--------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ItemDatabase       = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local SyncInventoryEvent = ReplicatedStorage:WaitForChild("SyncInventory")
local EquipUpdateEvent   = ReplicatedStorage:WaitForChild("EquipUpdate")
local HitMarkerEvent     = ReplicatedStorage:WaitForChild("HitMarker")
local startGameplayEvent = ReplicatedStorage:WaitForChild("StartGameplay")

-- ═══════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════
local currentWeaponId = nil
local currentAmmo     = 0
local reserveAmmo     = 0

-- ═══════════════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name           = "HUDGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 50
gui.Enabled        = false
gui.Parent         = playerGui

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 4)
	c.Parent = p
end

-- ───── HP BAR (ซ้ายล่าง) ─────
local hpHolder = Instance.new("Frame")
hpHolder.Size             = UDim2.fromOffset(280, 46)
hpHolder.Position         = UDim2.new(0, 28, 1, -78)
hpHolder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
hpHolder.BackgroundTransparency = 0.45
hpHolder.BorderSizePixel  = 0
hpHolder.Parent           = gui
corner(hpHolder, 6)

local hpLabel = Instance.new("TextLabel")
hpLabel.Size                   = UDim2.fromOffset(60, 16)
hpLabel.Position               = UDim2.fromOffset(12, 6)
hpLabel.BackgroundTransparency = 1
hpLabel.Text                   = "HEALTH"
hpLabel.TextColor3             = Color3.fromRGB(150, 150, 145)
hpLabel.Font                   = Enum.Font.GothamBold
hpLabel.TextSize               = 10
hpLabel.TextXAlignment         = Enum.TextXAlignment.Left
hpLabel.Parent                 = hpHolder

local hpBarBg = Instance.new("Frame")
hpBarBg.Size             = UDim2.new(1, -24, 0, 14)
hpBarBg.Position         = UDim2.fromOffset(12, 24)
hpBarBg.BackgroundColor3 = Color3.fromRGB(45, 42, 38)
hpBarBg.BorderSizePixel  = 0
hpBarBg.Parent           = hpHolder
corner(hpBarBg, 3)

local hpFill = Instance.new("Frame")
hpFill.Size             = UDim2.fromScale(1, 1)
hpFill.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
hpFill.BorderSizePixel  = 0
hpFill.Parent           = hpBarBg
corner(hpFill, 3)

local hpText = Instance.new("TextLabel")
hpText.Size                   = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.Text                   = "100"
hpText.TextColor3             = Color3.fromRGB(235, 230, 220)
hpText.Font                   = Enum.Font.GothamBold
hpText.TextSize               = 11
hpText.ZIndex                 = 3
hpText.Parent                 = hpBarBg

-- ───── AMMO (ขวาล่าง) ─────
local ammoHolder = Instance.new("Frame")
ammoHolder.Size             = UDim2.fromOffset(230, 76)
ammoHolder.Position         = UDim2.new(1, -258, 1, -108)
ammoHolder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ammoHolder.BackgroundTransparency = 0.45
ammoHolder.BorderSizePixel  = 0
ammoHolder.Visible          = false
ammoHolder.Parent           = gui
corner(ammoHolder, 6)

local wpnName = Instance.new("TextLabel")
wpnName.Size                   = UDim2.new(1, -20, 0, 20)
wpnName.Position               = UDim2.fromOffset(10, 8)
wpnName.BackgroundTransparency = 1
wpnName.Text                   = "—"
wpnName.TextColor3             = Color3.fromRGB(200, 195, 185)
wpnName.Font                   = Enum.Font.GothamBold
wpnName.TextSize               = 14
wpnName.TextXAlignment         = Enum.TextXAlignment.Right
wpnName.Parent                 = ammoHolder

local ammoText = Instance.new("TextLabel")
ammoText.Size                   = UDim2.new(1, -20, 0, 40)
ammoText.Position               = UDim2.fromOffset(10, 28)
ammoText.BackgroundTransparency = 1
ammoText.Text                   = "0 / 0"
ammoText.TextColor3             = Color3.fromRGB(255, 255, 255)
ammoText.Font                   = Enum.Font.GothamBlack
ammoText.TextSize               = 30
ammoText.TextXAlignment         = Enum.TextXAlignment.Right
ammoText.Parent                 = ammoHolder

-- ───── HITMARKER (กลางจอ) — วาดด้วย Frame 4 เส้น ─────
local hitMarker = Instance.new("Frame")
hitMarker.Name                   = "HitMarker"
hitMarker.AnchorPoint            = Vector2.new(0.5, 0.5)
hitMarker.Position               = UDim2.fromScale(0.5, 0.5)
hitMarker.Size                   = UDim2.fromOffset(40, 40)
hitMarker.BackgroundTransparency = 1
hitMarker.Parent                 = gui

local hmLines = {}
-- 4 ขีดทำมุม X: บนซ้าย / บนขวา / ล่างซ้าย / ล่างขวา
local LINE_DEFS = {
	{ pos = UDim2.fromScale(0.30, 0.30), rot =  45 },
	{ pos = UDim2.fromScale(0.70, 0.30), rot = -45 },
	{ pos = UDim2.fromScale(0.30, 0.70), rot = -45 },
	{ pos = UDim2.fromScale(0.70, 0.70), rot =  45 },
}

for _, def in ipairs(LINE_DEFS) do
	local line = Instance.new("Frame")
	line.AnchorPoint            = Vector2.new(0.5, 0.5)
	line.Position               = def.pos
	line.Size                   = UDim2.fromOffset(3, 12)
	line.Rotation               = def.rot
	line.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
	line.BackgroundTransparency = 1
	line.BorderSizePixel        = 0
	line.Parent                 = hitMarker
	table.insert(hmLines, line)
end

-- ───── DAMAGE FLASH (ขอบจอแดง) ─────
local dmgFlash = Instance.new("Frame")
dmgFlash.Size                   = UDim2.fromScale(1, 1)
dmgFlash.BackgroundColor3       = Color3.fromRGB(140, 0, 0)
dmgFlash.BackgroundTransparency = 1
dmgFlash.BorderSizePixel        = 0
dmgFlash.ZIndex                 = -1
dmgFlash.Parent                 = gui

-- ═══════════════════════════════════════════════
--  UPDATE FUNCTIONS
-- ═══════════════════════════════════════════════
local function updateAmmo()
	if not currentWeaponId then
		ammoHolder.Visible = false
		return
	end

	local data = ItemDatabase.GetItem(currentWeaponId)
	if not data then return end

	ammoHolder.Visible = true
	wpnName.Text = data.Name:upper()

	if data.Subtype == "Melee" then
		ammoText.Text      = "∞"
		ammoText.TextColor3 = Color3.fromRGB(220, 220, 220)
		return
	end

	if player:GetAttribute("Reloading") then
		ammoText.Text      = "RELOAD"
		ammoText.TextColor3 = Color3.fromRGB(255, 195, 60)
		return
	end

	local mag = data.MagazineSize or 0
	ammoText.Text = string.format("%d / %d", currentAmmo, reserveAmmo)

	if currentAmmo == 0 then
		ammoText.TextColor3 = Color3.fromRGB(255, 65, 65)
	elseif currentAmmo <= mag * 0.25 then
		ammoText.TextColor3 = Color3.fromRGB(255, 180, 60)
	else
		ammoText.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

player:GetAttributeChangedSignal("Reloading"):Connect(updateAmmo)

-- ═══════════════════════════════════════════════
--  HP TRACKING
-- ═══════════════════════════════════════════════
local lastHealth = 100

local function hookHealth(character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then return end
	lastHealth = hum.Health

	local function refresh()
		local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		TweenService:Create(hpFill, TweenInfo.new(0.25), {
			Size = UDim2.fromScale(pct, 1)
		}):Play()
		hpText.Text = tostring(math.ceil(hum.Health))

		if pct <= 0.25 then
			hpFill.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
		elseif pct <= 0.5 then
			hpFill.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
		else
			hpFill.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
		end

		-- โดนยิง → flash แดง
		if hum.Health < lastHealth then
			dmgFlash.BackgroundTransparency = 0.65
			TweenService:Create(dmgFlash, TweenInfo.new(0.45), {
				BackgroundTransparency = 1
			}):Play()
		end
		lastHealth = hum.Health
	end

	hum.HealthChanged:Connect(refresh)
	refresh()
end

if player.Character then hookHealth(player.Character) end
player.CharacterAdded:Connect(hookHealth)

-- ═══════════════════════════════════════════════
--  REMOTE HOOKS
-- ═══════════════════════════════════════════════
EquipUpdateEvent.OnClientEvent:Connect(function(_slot, itemId)
	currentWeaponId = itemId
	updateAmmo()
end)

SyncInventoryEvent.OnClientEvent:Connect(function(data)
	if not data then return end

	-- ammo ในแม็ก
	if data.activeWeaponSlot and data.equipment then
		local eq = data.equipment[data.activeWeaponSlot]
		if eq then
			currentWeaponId = eq.itemId
			currentAmmo     = eq.ammo or 0
		end
	else
		currentWeaponId = nil
	end

	-- นับกระสุนสำรองใน grid
	reserveAmmo = 0
	local wpn = currentWeaponId and ItemDatabase.GetItem(currentWeaponId)
	if wpn and wpn.AmmoType and data.grid then
		for _, slot in pairs(data.grid) do
			local d = ItemDatabase.GetItem(slot.itemId)
			if d and d.Type == "Ammo" and d.AmmoType == wpn.AmmoType then
				reserveAmmo = reserveAmmo + (slot.quantity or 0)
			end
		end
	end

	updateAmmo()
end)

HitMarkerEvent.OnClientEvent:Connect(function(isHead, _dmg)
	local col = isHead and Color3.fromRGB(255, 130, 40) or Color3.fromRGB(255, 255, 255)
	local sz  = isHead and 52 or 40

	hitMarker.Size = UDim2.fromOffset(sz, sz)

	for _, line in ipairs(hmLines) do
		line.BackgroundColor3       = col
		line.BackgroundTransparency = 0
		line.Size                   = UDim2.fromOffset(3, isHead and 15 or 12)

		TweenService:Create(line, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		}):Play()
	end

	TweenService:Create(hitMarker, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.fromOffset(sz + 14, sz + 14),
	}):Play()
end)

-- ═══════════════════════════════════════════════
--  ซ่อน HUD ตอนเปิด Inventory
-- ═══════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
	local flag = playerGui:FindFirstChild("InventoryOpen")
	local open = flag and flag.Value
	hpHolder.Visible   = not open
	ammoHolder.Visible = (not open) and (currentWeaponId ~= nil)
end)

startGameplayEvent.OnClientEvent:Connect(function()
	gui.Enabled = true
end)

print("[HUDClient] Ready")