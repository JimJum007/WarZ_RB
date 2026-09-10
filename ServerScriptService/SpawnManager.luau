local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local playEvent = getRemoteEvent("PlayGame")
local startGameplayEvent = getRemoteEvent("StartGameplay")

-- รับคำสั่งจากปุ่ม PLAY
playEvent.OnServerEvent:Connect(function(player)
	-- ถ้ายังไม่มีตัวละคร ให้ Spawn
	if not player.Character then
		player:LoadCharacter()
	end

	-- รอให้ตัวละครมาตรฐานถูกติดตั้งเสร็จก่อนส่งสัญญาณเริ่มเกม
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

	startGameplayEvent:FireClient(player)
end)