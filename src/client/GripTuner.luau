--------------------------------------------------------------
-- GripTuner.luau — จูน HAND_OFFSET ตัวเดียว (ลบทิ้งเมื่อจูนเสร็จ)
-- ปุ่ม: I/K = หน้า-หลัง | J/L = ซ้าย-ขวา | U/O = ขึ้น-ลง
--       ลูกศร = หมุน | P = print ค่า HAND_OFFSET | Backspace = reset
-- ⚠️  dev เท่านั้น — server ตั้ง Motor6D จริงใน WeaponModelHandler
--------------------------------------------------------------
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

local player = Players.LocalPlayer
local STEP, ROT = 0.05, math.rad(5)

-- sync กับ ItemDatabase.DefaultHandOffset / WeaponModelHandler
local DEFAULT_HAND_OFFSET = ItemDatabase.DefaultHandOffset
local handOffset = DEFAULT_HAND_OFFSET

local function getMotor()
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	return hand and hand:FindFirstChild("WeaponGrip"), hand
end

local function applyHandOffsetToMotor()
	local motor, hand = getMotor()
	if not motor or not hand then return end
	local rightGrip = hand:FindFirstChild("RightGripAttachment")
	if rightGrip and rightGrip:IsA("Attachment") then
		motor.C0 = rightGrip.CFrame * handOffset
	else
		motor.C0 = CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0) * handOffset
	end
end

local function formatOffset(cf: CFrame): string
	local p, r = cf.Position, { cf:ToOrientation() }
	return string.format(
		"HAND_OFFSET = CFrame.new(%.2f, %.2f, %.2f) * CFrame.Angles(math.rad(%.0f), math.rad(%.0f), math.rad(%.0f))",
		p.X, p.Y, p.Z, math.deg(r[1]), math.deg(r[2]), math.deg(r[3])
	)
end

-- UI แสดงค่า realtime
local billboard: BillboardGui? = nil
local valueLabel: TextLabel? = nil

local function ensureDisplay()
	local char = player.Character
	if not char then return end
	local head = char:FindFirstChild("Head")
	if not head then return end

	if not billboard or not billboard.Parent then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "GripTunerDisplay"
		billboard.Size = UDim2.fromOffset(420, 56)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
		bg.BackgroundTransparency = 0.25
		bg.BorderSizePixel = 0
		bg.Parent = billboard

		valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.fromScale(1, 1)
		valueLabel.BackgroundTransparency = 1
		valueLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
		valueLabel.TextSize = 14
		valueLabel.Font = Enum.Font.Code
		valueLabel.TextWrapped = true
		valueLabel.TextXAlignment = Enum.TextXAlignment.Left
		valueLabel.TextYAlignment = Enum.TextYAlignment.Center
		valueLabel.Parent = bg
	end
end

local function refreshDisplay()
	ensureDisplay()
	if valueLabel then
		valueLabel.Text = formatOffset(handOffset) .. "\nP=copy | Backspace=reset"
	end
end

player.CharacterAdded:Connect(function()
	task.defer(refreshDisplay)
end)

RunService.RenderStepped:Connect(function()
	refreshDisplay()
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	local k = input.KeyCode
	local d

	if k == Enum.KeyCode.Backspace then
		handOffset = DEFAULT_HAND_OFFSET
		applyHandOffsetToMotor()
		refreshDisplay()
		return
	elseif k == Enum.KeyCode.I then d = CFrame.new(0, 0, -STEP)
	elseif k == Enum.KeyCode.K then d = CFrame.new(0, 0,  STEP)
	elseif k == Enum.KeyCode.J then d = CFrame.new(-STEP, 0, 0)
	elseif k == Enum.KeyCode.L then d = CFrame.new( STEP, 0, 0)
	elseif k == Enum.KeyCode.U then d = CFrame.new(0,  STEP, 0)
	elseif k == Enum.KeyCode.O then d = CFrame.new(0, -STEP, 0)
	elseif k == Enum.KeyCode.Up    then d = CFrame.Angles( ROT, 0, 0)
	elseif k == Enum.KeyCode.Down  then d = CFrame.Angles(-ROT, 0, 0)
	elseif k == Enum.KeyCode.Left  then d = CFrame.Angles(0,  ROT, 0)
	elseif k == Enum.KeyCode.Right then d = CFrame.Angles(0, -ROT, 0)
	elseif k == Enum.KeyCode.P then
		print("[GripTuner] " .. formatOffset(handOffset))
		return
	else return end

	handOffset = handOffset * d
	applyHandOffsetToMotor()
end)

refreshDisplay()
print("[GripTuner] จูน HAND_OFFSET | IJKL/UO | ลูกศร | P | Backspace")