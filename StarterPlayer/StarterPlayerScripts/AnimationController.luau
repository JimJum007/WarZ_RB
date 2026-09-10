local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local AnimDB = require(ReplicatedStorage:WaitForChild("AnimationDatabase"))
local EquipUpdateEvent = ReplicatedStorage:WaitForChild("EquipUpdate")
local StartGameplayEvent = ReplicatedStorage:WaitForChild("StartGameplay")

local FADE = 0.18
local RUN_AT = 20
local MOVE_EPS = 0.1

local humanoid, animator, character
local cache = {}
local locoTrack, locoId
local poseTrack, poseId
local actionTracks = {}
local weaponSet
local stance = "Stand"

local function getTrack(id, priority, looped)
	if not id or id == "" or not animator then return nil end
	if cache[id] then return cache[id] end

	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[Anim] ‚À≈¥‰¡Ë‰¥È:", id)
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	cache[id] = track
	return track
end

local function stopOwnedTracks()
	if locoTrack then locoTrack:Stop(0) end
	if poseTrack then poseTrack:Stop(0) end
	for _, track in pairs(actionTracks) do
		track:Stop(0)
	end
	locoTrack, locoId = nil, nil
	poseTrack, poseId = nil, nil
	actionTracks = {}
end

local function playLocomotion(id)
	if id == locoId then return end
	local track = getTrack(id, Enum.AnimationPriority.Movement, true)
	if not track then return end
	if locoTrack and locoTrack ~= track then locoTrack:Stop(FADE) end
	track:Play(FADE)
	locoTrack, locoId = track, id
end

local function setWeaponPose(setKey)
	local id = setKey and AnimDB.GetWeaponAnim(setKey, "Pose") or nil
	if id == poseId then return end
	if poseTrack then poseTrack:Stop(FADE) end
	poseTrack, poseId = nil, nil
	if not id then return end
	local track = getTrack(id, Enum.AnimationPriority.Action, true)
	if not track then return end
	track:Play(FADE)
	poseTrack, poseId = track, id
end

local function playAction(name, speed)
	if not weaponSet then return nil end
	local id = AnimDB.GetWeaponAnim(weaponSet, name)
	if not id then return nil end
	local priority = name == "Reload" and Enum.AnimationPriority.Action3 or Enum.AnimationPriority.Action2
	local track = getTrack(id, priority, false)
	if not track then return nil end
	if actionTracks[name] then actionTracks[name]:Stop(0.08) end
	track:Play(0.08)
	if speed then track:AdjustSpeed(speed) end
	actionTracks[name] = track
	track.Stopped:Once(function()
		if actionTracks[name] == track then actionTracks[name] = nil end
	end)
	return track
end

local function stopAction(name)
	local track = actionTracks[name]
	if track then
		track:Stop(0.15)
		actionTracks[name] = nil
	end
end

local function setup(char)
	if not char or not char.Parent or char:GetAttribute("ClassicAvatar") ~= true then return end
	if character == char and humanoid and humanoid.Parent == char and locoTrack then return end

	stopOwnedTracks()
	character = char
	humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	cache = {}

	local idleId = AnimDB.GetLocomotion(stance, "Idle")
	if idleId then
		local idleTrack = getTrack(idleId, Enum.AnimationPriority.Idle, true)
		if idleTrack then
			idleTrack:Play(FADE)
			locoTrack, locoId = idleTrack, idleId
		end
	end
	setWeaponPose(weaponSet)
	print("[AnimationController] R6 animation bound")
end

local function watchCharacter(char)
	if not char then return end
	task.spawn(function()
		local deadline = os.clock() + 12
		while char.Parent and char:GetAttribute("ClassicAvatar") ~= true and os.clock() < deadline do
			task.wait(0.1)
		end
		if char.Parent and char:GetAttribute("ClassicAvatar") == true then
			setup(char)
		end
	end)
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)
player:GetPropertyChangedSignal("Character"):Connect(function()
	if player.Character and player.Character ~= character then watchCharacter(player.Character) end
end)
StartGameplayEvent.OnClientEvent:Connect(function()
	if player.Character then task.defer(setup, player.Character) end
end)

task.spawn(function()
	while task.wait(0.2) do
		local char = player.Character
		if char and char ~= character and char:GetAttribute("ClassicAvatar") == true then setup(char) end
	end
end)

EquipUpdateEvent.OnClientEvent:Connect(function(_, itemId)
	local newSet = AnimDB.GetSetKey(itemId)
	if newSet == weaponSet then return end
	weaponSet = newSet
	setWeaponPose(weaponSet)
	playAction("Equip")
end)

player:GetAttributeChangedSignal("Stance"):Connect(function()
	stance = player:GetAttribute("Stance") or "Stand"
	locoId = nil
end)
player:GetAttributeChangedSignal("Reloading"):Connect(function()
	if player:GetAttribute("Reloading") then playAction("Reload") else stopAction("Reload") end
end)

_G.PlayWeaponAction = function(name, speed)
	if name == "Fire" or name == "Attack" then name = "Shoot" end
	return playAction(name, speed)
end

RunService.RenderStepped:Connect(function()
	if not humanoid or humanoid.Health <= 0 or not character or not character.Parent then return end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping then
		playLocomotion(AnimDB.Locomotion.Jump)
		return
	elseif state == Enum.HumanoidStateType.Freefall then
		playLocomotion(AnimDB.Locomotion.Fall)
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > MOVE_EPS
	local motion = not moving and "Idle" or (humanoid.WalkSpeed >= RUN_AT and "Run" or "Walk")
	local id = AnimDB.GetLocomotion(stance, motion)
	if id then
		playLocomotion(id)
		if locoTrack then
			if motion == "Idle" then locoTrack:AdjustSpeed(1)
			else locoTrack:AdjustSpeed(math.clamp(humanoid.WalkSpeed / ((motion == "Run") and 24 or 14), 0.5, 2)) end
		end
	end
end)

task.spawn(function()
	local assets = {}
	for _, id in ipairs(AnimDB.GetAllIds()) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		table.insert(assets, animation)
	end
	pcall(function() ContentProvider:PreloadAsync(assets) end)
	print("[Anim] Preloaded", #assets)
end)

print("[AnimationController] Ready")