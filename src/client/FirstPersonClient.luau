-- FirstPersonClient.luau — ซ่อนร่างตัวเองในมุม first person (ยังเห็นแขน + ปืน)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local EquipUpdateEvent = ReplicatedStorage:WaitForChild("EquipUpdate")

-- ระยะกล้องจากหัว — ต่ำกว่านี้ถือว่า first person (สอดคล้อง CrosshairClient V-mode)
local FIRST_PERSON_HEAD_DIST = 1.15

-- ส่วนที่ยังมองเห็น (มือ + แขน)
local VISIBLE_ARM_PARTS: { [string]: boolean } = {
	RightHand = true,
	RightLowerArm = true,
	RightUpperArm = true,
	LeftHand = true,
	LeftLowerArm = true,
	LeftUpperArm = true,
}

local currentCharacter: Model? = nil
local lastFirstPerson: boolean? = nil
local forceRefresh = false

local function isFirstPersonView(): boolean
	local cam = workspace.CurrentCamera
	local char = currentCharacter
	if not cam or not char then return false end
	local head = char:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return false end
	return (cam.CFrame.Position - head.Position).Magnitude <= FIRST_PERSON_HEAD_DIST
end

local function setWeaponVisible(visible: boolean)
	local char = currentCharacter
	if not char then return end
	local weapon = char:FindFirstChild("EquippedWeapon")
	if not weapon then return end
	local mod = visible and 0 or 1
	for _, d in ipairs(weapon:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = mod
		end
	end
end

local function applyBodyVisibility(firstPerson: boolean)
	local char = currentCharacter
	if not char then return end

	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") then
			local inAccessory = obj:FindFirstAncestorOfClass("Accessory") ~= nil
			if inAccessory then
				obj.LocalTransparencyModifier = firstPerson and 1 or 0
			else
				local keep = VISIBLE_ARM_PARTS[obj.Name] == true
				if firstPerson then
					obj.LocalTransparencyModifier = keep and 0 or 1
				else
					obj.LocalTransparencyModifier = 0
				end
			end
		elseif obj:IsA("Decal") and obj.Name == "face" then
			obj.Transparency = firstPerson and 1 or 0
		end
	end

	if firstPerson then
		setWeaponVisible(true)
	else
		setWeaponVisible(true)
	end
end

local function refreshIfNeeded()
	local fp = isFirstPersonView()
	if fp == lastFirstPerson and not forceRefresh then
		return
	end
	lastFirstPerson = fp
	forceRefresh = false
	applyBodyVisibility(fp)
end

local function bindCharacter(char: Model?)
	currentCharacter = char
	lastFirstPerson = nil
	forceRefresh = true
	refreshIfNeeded()
end

player.CharacterAdded:Connect(function(char)
	bindCharacter(char)
end)

if player.Character then
	bindCharacter(player.Character)
end

EquipUpdateEvent.OnClientEvent:Connect(function()
	forceRefresh = true
end)

RunService.RenderStepped:Connect(refreshIfNeeded)

print("[FirstPersonClient] Ready — ซ่อนร่างใน first person, เหลือแขน+ปืน")