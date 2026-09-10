--------------------------------------------------------------
-- GripTuner — เครื่องมือปรับตำแหน่งปืนในมือ (ลบทิ้งเมื่อจูนเสร็จ)
-- ปุ่ม: I/K = หน้า-หลัง | J/L = ซ้าย-ขวา | U/O = ขึ้น-ลง
--       ลูกศร = หมุน | P = print ค่าออกมา
--------------------------------------------------------------
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")

local player = Players.LocalPlayer
local STEP, ROT = 0.05, math.rad(5)

local offset = CFrame.new(0, -0.8, -0.5) * CFrame.Angles(math.rad(-90), 0, 0)

local function getMotor()
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	return hand and hand:FindFirstChild("WeaponGrip")
end

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	local k = input.KeyCode
	local d

	if     k == Enum.KeyCode.I then d = CFrame.new(0, 0, -STEP)
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
		local p, r = offset.Position, {offset:ToOrientation()}
		print(("CFrame.new(%.2f, %.2f, %.2f) * CFrame.Angles(math.rad(%.0f), math.rad(%.0f), math.rad(%.0f)),")
			:format(p.X, p.Y, p.Z, math.deg(r[1]), math.deg(r[2]), math.deg(r[3])))
		return
	else return end

	offset = offset * d
	local motor = getMotor()
	if motor then motor.C0 = offset end
end)

print("[GripTuner] IJKL/UO = ขยับ | ลูกศร = หมุน | P = พิมพ์ค่า")