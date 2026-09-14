-- WeaponLeftHandIK.luau (ServerScriptService)
-- IK มือซ้ายไป LeftGripAttachment — replicate ให้ผู้เล่นอื่นเห็น

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

-- น้ำหนัก IK (0–1) — ปรับตรงนี้
local LEFT_HAND_IK_WEIGHT = 1

local WeaponChanged = ReplicatedStorage:WaitForChild("WeaponChanged")
local ReloadEvent = ReplicatedStorage:WaitForChild("ReloadWeapon")

local ikByPlayer = {} -- [player] = IKControl

local function findWeaponHandle(character: Model): BasePart?
	local weapon = character:FindFirstChild("EquippedWeapon")
	if not weapon then return nil end
	if weapon:IsA("Tool") then
		local h = weapon:FindFirstChild("Handle")
		if h and h:IsA("BasePart") then return h end
	end
	if weapon:IsA("Model") and weapon.PrimaryPart and weapon.PrimaryPart:IsA("BasePart") then
		return weapon.PrimaryPart
	end
	local named = weapon:FindFirstChild("Handle", true)
	if named and named:IsA("BasePart") then return named end
	for _, d in ipairs(weapon:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function clearIK(player: Player)
	local ik = ikByPlayer[player]
	if ik then
		ik:Destroy()
		ikByPlayer[player] = nil
	end
end

local function isReloading(character: Model): boolean
	local untilAt = character:GetAttribute("ReloadingUntil")
	if typeof(untilAt) == "number" and untilAt > os.clock() then
		return true
	end
	return false
end

local function shouldUseLeftIK(itemId: string?): boolean
	if not itemId then return false end
	local item = ItemDatabase.GetItem(itemId)
	if not item or item.Type ~= "Weapon" then return false end
	if item.UseLeftHandIK == false then return false end
	if item.UseLeftHandIK == true then return true end
	-- default: ปืนยาวใช้ IK, pistol/melee ไม่ใช้
	local sub = item.Subtype
	return sub ~= "Pistol" and sub ~= "Melee"
end

local function applyIK(player: Player, itemId: string?)
	clearIK(player)

	local character = player.Character
	if not character then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	local leftUpper = character:FindFirstChild("LeftUpperArm")
	local leftHand = character:FindFirstChild("LeftHand")
	if not hum or not leftUpper or not leftHand then return end

	if not shouldUseLeftIK(itemId) then return end

	local handle = findWeaponHandle(character)
	if not handle then return end

	local target = handle:FindFirstChild("LeftGripAttachment")
	if not target or not target:IsA("Attachment") then
		warn("[WeaponLeftHandIK] ไม่มี LeftGripAttachment:", itemId)
		return
	end

	local ik = Instance.new("IKControl")
	ik.Name = "LeftHandWeaponIK"
	ik.Type = Enum.IKControlType.Transform
	ik.ChainRoot = leftUpper
	ik.EndEffector = leftHand
	ik.Target = target
	ik.Weight = LEFT_HAND_IK_WEIGHT
	ik.Parent = hum

	ikByPlayer[player] = ik
end

local function refreshWeight(player: Player, itemId: string?)
	local ik = ikByPlayer[player]
	if not ik then return end

	local character = player.Character
	if not character then
		clearIK(player)
		return
	end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		ik.Weight = 0
		return
	end

	if not character:FindFirstChild("EquippedWeapon") or not shouldUseLeftIK(itemId) then
		ik.Weight = 0
		return
	end

	if isReloading(character) then
		ik.Weight = 0
		return
	end

	ik.Weight = LEFT_HAND_IK_WEIGHT
end

WeaponChanged.Event:Connect(function(player, itemId)
	if not player or not player:IsA("Player") then return end
	if not itemId then
		clearIK(player)
		return
	end
	-- รอ WeaponModelHandler ติดปืน
	task.defer(function()
		if not player.Parent then return end
		applyIK(player, itemId)
	end)
end)

ReloadEvent.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end
	local itemId = _G.InventoryManager and _G.InventoryManager.GetActiveWeapon(player)
	local item = itemId and ItemDatabase.GetItem(itemId)
	local t = item and item.ReloadTime or 2
	character:SetAttribute("ReloadingUntil", os.clock() + t)
end)

RunService.Heartbeat:Connect(function()
	if not _G.InventoryManager then return end
	for _, player in ipairs(Players:GetPlayers()) do
		local itemId = _G.InventoryManager.GetActiveWeapon(player)
		refreshWeight(player, itemId)
	end
end)

local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		clearIK(player)
	end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end

Players.PlayerRemoving:Connect(function(player)
	clearIK(player)
end)

print("[WeaponLeftHandIK] Ready (server IK)")
