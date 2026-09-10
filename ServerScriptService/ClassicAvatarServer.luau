local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local template = Workspace:WaitForChild("TemplateR6")
local replacing = {}
local activeCharacters = {}

local FALLBACK_SHIRT = "rbxassetid://144076760"
local FALLBACK_PANTS = "rbxassetid://144076358"

local function copyClothing(templateCharacter, character)
	for _, className in {"Shirt", "Pants", "ShirtGraphic"} do
		for _, item in character:GetChildren() do
			if item:IsA(className) then
				item:Destroy()
			end
		end
	end

	for _, item in templateCharacter:GetChildren() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			local clone = item:Clone()
			if clone:IsA("Shirt") and clone.ShirtTemplate == "" then
				clone.ShirtTemplate = FALLBACK_SHIRT
			elseif clone:IsA("Pants") and clone.PantsTemplate == "" then
				clone.PantsTemplate = FALLBACK_PANTS
			end
			clone.Parent = character
		end
	end
end

local function prepareCharacter(character)
	for _, instance in character:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.Anchored = false
		end
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if rootPart then
		rootPart.Anchored = false
	end
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.PlatformStand = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator", humanoid)
		end
	end

	local shirt = character:FindFirstChildOfClass("Shirt")
	if not shirt then
		shirt = Instance.new("Shirt")
		shirt.Parent = character
	end
	if shirt.ShirtTemplate == "" then
		shirt.ShirtTemplate = FALLBACK_SHIRT
	end

	local pants = character:FindFirstChildOfClass("Pants")
	if not pants then
		pants = Instance.new("Pants")
		pants.Parent = character
	end
	if pants.PantsTemplate == "" then
		pants.PantsTemplate = FALLBACK_PANTS
	end
end

local function assignCharacterNetworkOwnership(player, character)
	if not character:IsDescendantOf(Workspace) then
		return
	end
	for _, instance in character:GetDescendants() do
		if instance:IsA("BasePart") and not instance.Anchored then
			instance:SetNetworkOwner(player)
		end
	end
end

local function markStandardAvatar(character)
	character:SetAttribute("ClassicAvatar", true)
	character:SetAttribute("HitboxStandard", "R6")
end

local function replaceWithR6(player, character)
	if replacing[player] or activeCharacters[player] == character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	replacing[player] = true
	local spawnPivot = character:GetPivot()
	local classicCharacter = template:Clone()
	classicCharacter.Name = player.Name
	copyClothing(template, classicCharacter)
	prepareCharacter(classicCharacter)
	markStandardAvatar(classicCharacter)
	classicCharacter:PivotTo(spawnPivot)
	classicCharacter.Parent = Workspace
	assignCharacterNetworkOwnership(player, classicCharacter)
	player.Character = classicCharacter
	activeCharacters[player] = classicCharacter
	character:Destroy()
	replacing[player] = nil
	print("[ClassicAvatar] Standard R6 ready for " .. player.Name)
end

local function hookPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.defer(replaceWithR6, player, character)
	end)
	if player.Character then
		task.defer(replaceWithR6, player, player.Character)
	end
end

Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(player)
	replacing[player] = nil
	activeCharacters[player] = nil
end)

for _, player in Players:GetPlayers() do
	hookPlayer(player)
end