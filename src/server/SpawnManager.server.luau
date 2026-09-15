local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AvatarStandardizer = require(ServerScriptService:WaitForChild("AvatarStandardizer"))

-- ไม่ให้ผู้เล่นเกิดทันทีเมื่อเข้าเกม
Players.CharacterAutoLoads = false

-- สร้างหรือดึง RemoteEvent อย่างปลอดภัย
local function getRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)

	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end

	return event
end

local function getBindableEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)

	if not event then
		event = Instance.new("BindableEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end

	return event
end

local playEvent = getRemoteEvent("PlayGame")
local startGameplayEvent = getRemoteEvent("StartGameplay")
local serverCharacterReadyEvent = getBindableEvent("ServerCharacterReady")

local function respawnPlayer(player)
	local desc = AvatarStandardizer.GetHumanoidDescriptionForPlayer(player)
	player:LoadCharacterWithHumanoidDescription(desc)

	local character = player.Character or player.CharacterAdded:Wait()
	local deadline = os.clock() + 10
	while character and os.clock() < deadline do
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and character:GetAttribute("ClassicAvatar") == true then
			break
		end
		task.wait(0.1)
		character = player.Character
	end

	if not character or not character:FindFirstChild("HumanoidRootPart") then
		warn("[SpawnManager] Character was not ready for " .. player.Name)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			task.delay(3, function()
				if player.Parent then
					respawnPlayer(player)
				end
			end)
		end)
	end

	serverCharacterReadyEvent:Fire(player, character)
	startGameplayEvent:FireClient(player)
end

-- รับคำสั่งจากปุ่ม PLAY
playEvent.OnServerEvent:Connect(function(player)
	respawnPlayer(player)
end)