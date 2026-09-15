-- FirstPersonClient.luau — ซ่อนร่างตัวเองในมุม first person (ยังเห็นแขน + ปืน)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local EquipUpdateEvent = ReplicatedStorage:WaitForChild("EquipUpdate")

-- ระยะกล้องจากหัว — ต่ำกว่านี้ถือว่า first person (สอดคล้อง CrosshairClient V-mode)
local FIRST_PERSON_HEAD_DIST = 1.15

-- Option A: ซ่อนทั้งตัวใน First Person (เพราะเราจะมี ViewModel แยกต่างหาก)

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
			obj.LocalTransparencyModifier = firstPerson and 1 or 0
		elseif obj:IsA("Decal") and obj.Name == "face" then
			obj.Transparency = firstPerson and 1 or 0
		end
	end

	setWeaponVisible(not firstPerson)
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

local startGameplayEvent = ReplicatedStorage:WaitForChild("StartGameplay")

startGameplayEvent.OnClientEvent:Connect(function()
	if player.Character then
		bindCharacter(player.Character)
	end
end)

EquipUpdateEvent.OnClientEvent:Connect(function()
	forceRefresh = true
end)

RunService.RenderStepped:Connect(refreshIfNeeded)

print("[FirstPersonClient] Ready — ซ่อนร่างใน first person, เหลือแขน+ปืน")