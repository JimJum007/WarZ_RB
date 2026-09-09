--------------------------------------------------------------
-- CrosshairClient.lua  (LocalScript)
-- วางใน: StarterPlayer → StarterPlayerScripts
--
-- ✅ Smooth FPS Camera System
--    - Spring-based transitions ทุกอย่าง
--    - Sprint + FOV change (Shift ค้าง)
--    - ADS / Aim Down Sights (คลิกขวาค้าง)
--    - Smooth stance (ย่อ/หมอบ)
--    - Smooth 1st ↔ 3rd person
--    - Smooth shoulder swap
--    - Head tilt ตอนเดินเฉียง
--    - Inventory integration (ปุ่ม B)
--------------------------------------------------------------

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local startGameplayEvent = ReplicatedStorage:WaitForChild("StartGameplay")

-- ═══════════════════════════════════════════════
--  SPRING CLASS  (ฟิสิกส์สปริงสำหรับ smooth motion)
-- ═══════════════════════════════════════════════
local Spring = {}
Spring.__index = Spring

function Spring.new(initial, speed, damping)
	return setmetatable({
		Position = initial,
		Velocity = typeof(initial) == "number" and 0 or Vector3.zero,
		Target   = initial,
		Speed    = speed   or 10,
		Damping  = damping or 1,
	}, Spring)
end

function Spring:Update(dt)
	local s = self.Speed
	local d = self.Damping
	local displacement = self.Position - self.Target

	if typeof(displacement) == "number" then
		local springForce  = -s * s * displacement
		local dampingForce = -2 * d * s * self.Velocity
		self.Velocity = self.Velocity + (springForce + dampingForce) * dt
		self.Position = self.Position + self.Velocity * dt
	else
		local springForce  = displacement * (-s * s)
		local dampingForce = self.Velocity * (-2 * d * s)
		self.Velocity = self.Velocity + (springForce + dampingForce) * dt
		self.Position = self.Position + self.Velocity * dt
	end

	return self.Position
end

function Spring:Reset(value)
	self.Position = value
	self.Target   = value
	self.Velocity = typeof(value) == "number" and 0 or Vector3.zero
end

-- ═══════════════════════════════════════════════
--  INVENTORY STATE
-- ═══════════════════════════════════════════════
local function isInventoryOpen()
	local val = playerGui:FindFirstChild("InventoryOpen")
	return val and val.Value or false
end

-- ═══════════════════════════════════════════════
--  CROSSHAIR GUI
-- ═══════════════════════════════════════════════
local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name           = "CrosshairGui"
crosshairGui.IgnoreGuiInset = true
crosshairGui.ResetOnSpawn   = false
crosshairGui.DisplayOrder   = 300
crosshairGui.Enabled        = false
crosshairGui.Parent         = playerGui

local crosshair = Instance.new("TextLabel")
crosshair.Name                   = "Crosshair"
crosshair.AnchorPoint            = Vector2.new(0.5, 0.5)
crosshair.Position               = UDim2.fromScale(0.5, 0.5)
crosshair.Size                   = UDim2.fromOffset(34, 34)
crosshair.BackgroundTransparency = 1
crosshair.Text                   = "+"
crosshair.TextColor3             = Color3.fromRGB(255, 255, 255)
crosshair.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
crosshair.TextStrokeTransparency = 0
crosshair.Font                   = Enum.Font.GothamBold
crosshair.TextScaled             = true
crosshair.Parent                 = crosshairGui

-- ข้อความบอก mode ชั่วคราว
local modeText = Instance.new("TextLabel")
modeText.AnchorPoint            = Vector2.new(0.5, 0.5)
modeText.Position               = UDim2.new(0.5, 0, 0.5, 48)
modeText.Size                   = UDim2.fromOffset(320, 24)
modeText.BackgroundTransparency = 1
modeText.Text                   = ""
modeText.TextColor3             = Color3.fromRGB(210, 220, 210)
modeText.TextStrokeTransparency = 0.5
modeText.Font                   = Enum.Font.GothamBold
modeText.TextScaled             = true
modeText.Parent                 = crosshairGui

-- ═══════════════════════════════════════════════
--  CONSTANTS
-- ═══════════════════════════════════════════════

-- Mouse
local MOUSE_SENSITIVITY = 0.0025

-- Third Person defaults
local TP_DISTANCE      = 8
local TP_HEIGHT        = 1.3
local TP_SHOULDER      = 2.3

-- FOV
local FOV_NORMAL = 70
local FOV_SPRINT = 85
local FOV_ADS    = 50

-- Sprint
local SPRINT_SPEED_MULT = 1.5   -- คูณ WalkSpeed ตอน sprint

-- ADS
local ADS_DISTANCE_MULT = 0.5   -- กล้องเข้าใกล้ตัวละคร 50%
local ADS_WALK_MULT     = 0.5   -- เดินช้าลง 50% ตอน ADS
local ADS_CROSSHAIR_SIZE = 20   -- crosshair เล็กลงตอน ADS

-- Head tilt
local TILT_ANGLE = math.rad(2.5) -- เอียง 2.5 องศา

-- Crosshair
local CROSSHAIR_NORMAL_SIZE = 34

-- Stance
local CROUCH_WALK_SPEED = 9
local PRONE_WALK_SPEED  = 4

-- ═══════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════
local playing          = false
local firstPerson      = false
local characterOnRight = false

local yaw   = 0
local pitch = 0

local currentCharacter, humanoid, rootPart, head

local stance          = "Stand"
local normalWalkSpeed = 16
local normalHipHeight = 2
local normalJumpPower = 50

local isSprinting = false
local isADS       = false
local hasWeapon   = false  -- ⚠️ เปลี่ยนเป็น true เมื่อมีระบบอาวุธ (ADS ใช้ได้เฉพาะตอนถืออาวุธ)

-- Animation
local CROUCH_ANIMATION_ID = ""
local PRONE_ANIMATION_ID  = ""
local crouchTrack, proneTrack

-- ═══════════════════════════════════════════════
--  SPRINGS
-- ═══════════════════════════════════════════════
local heightSpring    = Spring.new(0, 12, 1)           -- camera height offset
local fovSpring       = Spring.new(FOV_NORMAL, 8, 1)   -- field of view
local shoulderSpring  = Spring.new(TP_SHOULDER, 10, 1)  -- shoulder offset L/R
local distanceSpring  = Spring.new(TP_DISTANCE, 8, 1)   -- camera distance (3rd)
local tiltSpring      = Spring.new(0, 10, 1)            -- head tilt roll
local crosshairSpring = Spring.new(CROSSHAIR_NORMAL_SIZE, 12, 1) -- crosshair size

-- ═══════════════════════════════════════════════
--  UTILITY
-- ═══════════════════════════════════════════════
local function showModeText(text)
	modeText.Text = text
	task.delay(1.3, function()
		if modeText.Text == text then
			modeText.Text = ""
		end
	end)
end

local function setFirstPersonVisibility(isFirstPerson)
	if not currentCharacter then return end

	for _, object in ipairs(currentCharacter:GetDescendants()) do
		if object:IsA("BasePart") then
			local isHead = (object.Name == "Head")
			local isAccessory = object:FindFirstAncestorOfClass("Accessory") ~= nil
			if isHead or isAccessory then
				object.LocalTransparencyModifier = isFirstPerson and 1 or 0
			end
		end
		if object:IsA("Decal") and object.Name == "face" then
			object.Transparency = isFirstPerson and 1 or 0
		end
	end
end

local function lockMouse()
	if isInventoryOpen() then return end
	UserInputService.MouseBehavior  = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

-- ═══════════════════════════════════════════════
--  ANIMATION
-- ═══════════════════════════════════════════════
local function loadAnimation(animationId)
	if animationId == "" or not humanoid then return nil end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animationId

	local track = animator:LoadAnimation(anim)
	track.Looped   = true
	track.Priority = Enum.AnimationPriority.Action
	return track
end

local function stopStanceAnimations()
	if crouchTrack and crouchTrack.IsPlaying then crouchTrack:Stop(0.15) end
	if proneTrack  and proneTrack.IsPlaying  then proneTrack:Stop(0.15)  end
end

-- ═══════════════════════════════════════════════
--  CHARACTER SETUP
-- ═══════════════════════════════════════════════
local function setupCharacter(character)
	currentCharacter = character
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	head     = character:FindFirstChild("Head")

	normalWalkSpeed = humanoid.WalkSpeed
	normalHipHeight = humanoid.HipHeight
	normalJumpPower = humanoid.JumpPower

	crouchTrack = loadAnimation(CROUCH_ANIMATION_ID)
	proneTrack  = loadAnimation(PRONE_ANIMATION_ID)

	stance     = "Stand"
	isSprinting = false
	isADS       = false

	humanoid.AutoRotate = false

	-- เริ่มต้นกล้องจากทิศทางตัวละคร
	local _, startYaw, _ = rootPart.CFrame:ToOrientation()
	yaw   = startYaw
	pitch = 0

	-- Reset springs
	heightSpring:Reset(0)
	fovSpring:Reset(FOV_NORMAL)
	shoulderSpring:Reset(characterOnRight and -TP_SHOULDER or TP_SHOULDER)
	distanceSpring:Reset(TP_DISTANCE)
	tiltSpring:Reset(0)
	crosshairSpring:Reset(CROSSHAIR_NORMAL_SIZE)

	setFirstPersonVisibility(firstPerson)
end

-- ═══════════════════════════════════════════════
--  STANCE SYSTEM
-- ═══════════════════════════════════════════════
local function getBaseWalkSpeed()
	if stance == "Crouch" then return CROUCH_WALK_SPEED
	elseif stance == "Prone" then return PRONE_WALK_SPEED
	else return normalWalkSpeed
	end
end

local function setStance(newStance)
	if not humanoid then return end

	stance = newStance
	stopStanceAnimations()

	if stance == "Stand" then
		humanoid.WalkSpeed  = normalWalkSpeed
		humanoid.HipHeight  = normalHipHeight
		humanoid.JumpPower  = normalJumpPower
		heightSpring.Target = 0
		showModeText("STANDING")

	elseif stance == "Crouch" then
		humanoid.WalkSpeed  = CROUCH_WALK_SPEED
		humanoid.HipHeight  = normalHipHeight * 0.65
		humanoid.JumpPower  = 0
		heightSpring.Target = -0.65
		if crouchTrack then crouchTrack:Play(0.15) end
		showModeText("CROUCH")

	elseif stance == "Prone" then
		humanoid.WalkSpeed  = PRONE_WALK_SPEED
		humanoid.HipHeight  = normalHipHeight * 0.3
		humanoid.JumpPower  = 0
		heightSpring.Target = -1.15
		if proneTrack then proneTrack:Play(0.15) end
		showModeText("PRONE")
	end

	-- Sprint หยุดเมื่อย่อ/หมอบ
	if stance ~= "Stand" then
		isSprinting = false
	end
end

-- ═══════════════════════════════════════════════
--  MOUSE INPUT
-- ═══════════════════════════════════════════════
UserInputService.InputChanged:Connect(function(input)
	if not playing then return end
	if isInventoryOpen() then return end

	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local sens = MOUSE_SENSITIVITY
		-- ADS ลด sensitivity เล็กน้อย
		if isADS then sens = sens * 0.7 end

		yaw   = yaw   - input.Delta.X * sens
		pitch = pitch - input.Delta.Y * sens
		pitch = math.clamp(pitch, math.rad(-75), math.rad(75))
	end
end)

-- ═══════════════════════════════════════════════
--  KEY INPUT
-- ═══════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not playing then return end
	if isInventoryOpen() then return end

	-- V = สลับ First/Third Person
	if input.KeyCode == Enum.KeyCode.V then
		firstPerson = not firstPerson
		setFirstPersonVisibility(firstPerson)
		showModeText(firstPerson and "FIRST PERSON" or "THIRD PERSON")
	end

	-- E = สลับไหล่ (Third Person เท่านั้น)
	if input.KeyCode == Enum.KeyCode.E and not firstPerson then
		characterOnRight = not characterOnRight
		-- Spring จะ tween ไปตำแหน่งใหม่
		shoulderSpring.Target = characterOnRight and -TP_SHOULDER or TP_SHOULDER
		showModeText(characterOnRight and "RIGHT SHOULDER" or "LEFT SHOULDER")
	end

	-- C = ย่อ / ลุก
	if input.KeyCode == Enum.KeyCode.C then
		setStance(stance == "Crouch" and "Stand" or "Crouch")
	end

	-- Z = หมอบ / ลุก
	if input.KeyCode == Enum.KeyCode.Z then
		setStance(stance == "Prone" and "Stand" or "Prone")
	end
end)

-- ═══════════════════════════════════════════════
--  MAIN CAMERA RENDER STEP
-- ═══════════════════════════════════════════════
RunService:BindToRenderStep("GameplayCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not playing or not rootPart or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Inventory เปิด → หยุดกล้อง
	if isInventoryOpen() then
		crosshair.Visible = false
		return
	else
		crosshair.Visible = true
	end

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	lockMouse()

	-- ─────────────────────────────────────
	-- SPRINT (Shift ค้าง + กำลังเดิน + ยืน)
	-- ─────────────────────────────────────
	local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	local isMoving  = humanoid.MoveDirection.Magnitude > 0.1
	local canSprint = (stance == "Stand") and not isADS

	if shiftHeld and isMoving and canSprint then
		if not isSprinting then
			isSprinting = true
			humanoid.WalkSpeed = normalWalkSpeed * SPRINT_SPEED_MULT
		end
	else
		if isSprinting then
			isSprinting = false
			humanoid.WalkSpeed = getBaseWalkSpeed()
		end
	end

	-- ─────────────────────────────────────
	-- ADS (คลิกขวาค้าง)
	-- ─────────────────────────────────────
	local rmbHeld = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

	if rmbHeld and not isSprinting and hasWeapon then
		if not isADS then
			isADS = true
			-- ลดความเร็วเดิน
			if not isSprinting then
				humanoid.WalkSpeed = getBaseWalkSpeed() * ADS_WALK_MULT
			end
		end
	else
		if isADS then
			isADS = false
			humanoid.WalkSpeed = getBaseWalkSpeed()
		end
	end

	-- ─────────────────────────────────────
	-- SPRING TARGETS (อัพเดตเป้าหมายของ springs)
	-- ─────────────────────────────────────

	-- FOV
	if isADS then
		fovSpring.Target = FOV_ADS
	elseif isSprinting then
		fovSpring.Target = FOV_SPRINT
	else
		fovSpring.Target = FOV_NORMAL
	end

	-- Distance (3rd person — ADS เข้าใกล้)
	if isADS and not firstPerson then
		distanceSpring.Target = TP_DISTANCE * ADS_DISTANCE_MULT
	else
		distanceSpring.Target = TP_DISTANCE
	end

	-- Crosshair size
	if isADS then
		crosshairSpring.Target = ADS_CROSSHAIR_SIZE
	else
		crosshairSpring.Target = CROSSHAIR_NORMAL_SIZE
	end

	-- (Head tilt ถูกปิด — เมาหัว)

	-- ─────────────────────────────────────
	-- UPDATE SPRINGS
	-- ─────────────────────────────────────
	local smoothHeight    = heightSpring:Update(dt)
	local smoothFOV       = fovSpring:Update(dt)
	local smoothShoulder  = shoulderSpring:Update(dt)
	local smoothDistance   = distanceSpring:Update(dt)
	local smoothTilt      = tiltSpring:Update(dt)
	local smoothCrosshair = crosshairSpring:Update(dt)

	-- Apply FOV
	camera.FieldOfView = smoothFOV

	-- Apply crosshair size
	local cs = math.floor(smoothCrosshair + 0.5)
	crosshair.Size = UDim2.fromOffset(cs, cs)

	-- ─────────────────────────────────────
	-- CHARACTER ROTATION
	-- ─────────────────────────────────────
	rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, yaw, 0)

	-- ─────────────────────────────────────
	-- CAMERA ROTATION (yaw + pitch + tilt)
	-- ─────────────────────────────────────
	local rotation = CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(pitch, 0, 0)
		* CFrame.Angles(0, 0, smoothTilt)

	-- ─────────────────────────────────────
	-- CAMERA POSITION
	-- ─────────────────────────────────────
	if firstPerson then
		-- ═══ FIRST PERSON ═══
		local camPos
		if head then
			camPos = head.Position
				+ Vector3.new(0, 0.2 + smoothHeight, 0)
				+ rotation.LookVector * 0.35
		else
			camPos = rootPart.Position + Vector3.new(0, 2.5 + smoothHeight, 0)
		end

		camera.CFrame = CFrame.new(camPos, camPos + rotation.LookVector * 100)
			* CFrame.Angles(0, 0, smoothTilt)

	else
		-- ═══ THIRD PERSON ═══
		local focusPos = rootPart.Position + Vector3.new(0, TP_HEIGHT + smoothHeight, 0)

		local desiredPos = (
			CFrame.new(focusPos)
				* rotation
				* CFrame.new(smoothShoulder, TP_HEIGHT, smoothDistance)
		).Position

		local lookTarget = focusPos + rotation.LookVector * 100

		-- Wall collision (ป้องกันกล้องทะลุกำแพง)
		local rayDir = desiredPos - focusPos
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {currentCharacter}

		local hit = workspace:Raycast(focusPos, rayDir, rayParams)
		if hit then
			desiredPos = hit.Position - rayDir.Unit * 0.35
		end

		camera.CFrame = CFrame.new(desiredPos, lookTarget)
			* CFrame.Angles(0, 0, smoothTilt)
	end
end)

-- ═══════════════════════════════════════════════
--  STARTUP
-- ═══════════════════════════════════════════════
startGameplayEvent.OnClientEvent:Connect(function()
	local character = player.Character or player.CharacterAdded:Wait()
	setupCharacter(character)

	playing = true
	crosshairGui.Enabled = true
	lockMouse()

	showModeText("THIRD PERSON • V: FIRST PERSON • E: SHOULDER")
end)

-- กรณีตายแล้วเกิดใหม่
player.CharacterAdded:Connect(function(character)
	if playing then
		setupCharacter(character)
	end
end)