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

	-- รอให้ตัวละครเกิดจริงก่อน ค่อยให้ Client ล็อกเมาส์/แสดงเป้า
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 5)

	startGameplayEvent:FireClient(player)
end)