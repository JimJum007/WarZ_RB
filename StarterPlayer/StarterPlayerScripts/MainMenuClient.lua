local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local camera = Workspace.CurrentCamera
local loginCameraPart = ReplicatedStorage:WaitForChild("LoginCamera")

-- ขอให้ Client โหลดพื้นที่รอบจุดกล้อง Login
task.spawn(function()
	local success, err = pcall(function()
		player:RequestStreamAroundAsync(loginCameraPart.Position)
	end)

	if not success then
		warn("ไม่สามารถโหลดพื้นที่หน้า Login ได้:", err)
	end
end)

-- ระบบกล้องหน้า Login แบบ cinematic
local cameraConnection
local cameraStartTime = 0

local function enableLoginCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	cameraStartTime = time()

	-- ยกเลิกการขยับเดิมก่อน ป้องกันการเชื่อมซ้ำ
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	cameraConnection = RunService.RenderStepped:Connect(function()
		local elapsed = time() - cameraStartTime

		-- ส่ายซ้าย-ขวาช้า ๆ
		local moveX = math.sin(elapsed * 0.22) * 1.2

		-- ขยับขึ้น-ลงเบามาก
		local moveY = math.sin(elapsed * 0.35) * 0.25

		-- ซูมหน้า-หลังช้า ๆ
		local moveZ = math.cos(elapsed * 0.18) * 0.5

		-- หมุนกล้องนิดเดียว หน่วยเป็นองศา
		local rotateY = math.rad(math.sin(elapsed * 0.22) * 1.5)
		local rotateX = math.rad(math.cos(elapsed * 0.28) * 0.4)

		camera.CFrame =
			loginCameraPart.CFrame
			* CFrame.new(moveX, moveY, moveZ)
			* CFrame.Angles(rotateX, rotateY, 0)
	end)
end

local function disableLoginCamera()
	-- หยุดเอฟเฟกต์กล้องก่อนคืนกล้องให้ผู้เล่น
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	camera.CameraType = Enum.CameraType.Custom
end

-- เปิดกล้องหน้า Login ทันทีเมื่อเข้าเกม
enableLoginCamera()

local playEvent = ReplicatedStorage:WaitForChild("PlayGame")

-- สร้างหน้าจอเมนู
local menu = Instance.new("ScreenGui")
menu.Name = "MainMenu"
menu.IgnoreGuiInset = true
menu.ResetOnSpawn = false
menu.DisplayOrder = 100
menu.Parent = playerGui

-- พื้นหลังโปร่ง เพื่อให้เห็นฉากจาก LoginCamera
local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(10, 15, 13)
background.BackgroundTransparency = 0.55
background.BorderSizePixel = 0
background.Parent = menu

-- กล่องเมนูกลางจอ
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(430, 300)
panel.BackgroundColor3 = Color3.fromRGB(25, 30, 28)
panel.BorderSizePixel = 0
panel.Parent = background

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

-- ชื่อเกม
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 35)
title.Size = UDim2.fromOffset(370, 60)
title.BackgroundTransparency = 1
title.Text = "LAST NIGHT"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = panel

-- ข้อความรอง
local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0, 105)
subtitle.Size = UDim2.fromOffset(350, 25)
subtitle.BackgroundTransparency = 1
subtitle.Text = "SURVIVE THE OUTBREAK"
subtitle.TextColor3 = Color3.fromRGB(145, 165, 150)
subtitle.Font = Enum.Font.Gotham
subtitle.TextScaled = true
subtitle.Parent = panel

-- ปุ่ม Play
local playButton = Instance.new("TextButton")
playButton.AnchorPoint = Vector2.new(0.5, 0.5)
playButton.Position = UDim2.new(0.5, 0, 0, 190)
playButton.Size = UDim2.fromOffset(270, 62)
playButton.BackgroundColor3 = Color3.fromRGB(62, 120, 72)
playButton.BorderSizePixel = 0
playButton.Text = "PLAY"
playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playButton.Font = Enum.Font.GothamBold
playButton.TextScaled = true
playButton.Parent = panel

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = playButton

-- กด Play แล้วขอให้ Server Spawn ตัวละคร
-- สร้างหน้าจอ Loading หลังผู้เล่นกด Play
local function createLoadingScreen()
	local loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "LoadingGui"
	loadingGui.IgnoreGuiInset = true
	loadingGui.ResetOnSpawn = false
	loadingGui.DisplayOrder = 200
	loadingGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(7, 10, 9)
	background.BorderSizePixel = 0
	background.Parent = loadingGui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.fromOffset(700, 85)
	title.BackgroundTransparency = 1
	title.Text = "LAST NIGHT"
	title.TextColor3 = Color3.fromRGB(240, 240, 230)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = background

	local status = Instance.new("TextLabel")
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.56)
	status.Size = UDim2.fromOffset(500, 35)
	status.BackgroundTransparency = 1
	status.Text = "LOADING MAP..."
	status.TextColor3 = Color3.fromRGB(150, 170, 155)
	status.Font = Enum.Font.Gotham
	status.TextScaled = true
	status.Parent = background

	-- พื้นหลังของแถบโหลด
	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 0.5)
	barBack.Position = UDim2.fromScale(0.5, 0.64)
	barBack.Size = UDim2.fromOffset(380, 16)
	barBack.BackgroundColor3 = Color3.fromRGB(40, 48, 43)
	barBack.BorderSizePixel = 0
	barBack.Parent = background

	local barBackCorner = Instance.new("UICorner")
	barBackCorner.CornerRadius = UDim.new(1, 0)
	barBackCorner.Parent = barBack

	-- แถบโหลดสีเขียว
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(77, 140, 83)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill

	local percent = Instance.new("TextLabel")
	percent.AnchorPoint = Vector2.new(0.5, 0.5)
	percent.Position = UDim2.fromScale(0.5, 0.7)
	percent.Size = UDim2.fromOffset(200, 28)
	percent.BackgroundTransparency = 1
	percent.Text = "0%"
	percent.TextColor3 = Color3.fromRGB(190, 200, 190)
	percent.Font = Enum.Font.GothamBold
	percent.TextScaled = true
	percent.Parent = background

	return loadingGui, barFill, status, percent
end

-- เมื่อกด PLAY
playButton.Activated:Connect(function()
	playButton.Active = false

	-- ซ่อนหน้า Login
	menu.Enabled = false

	-- แสดงหน้า Loading
	local loadingGui, barFill, status, percent = createLoadingScreen()

	-- โหลดแบบแสดงความคืบหน้า (เอฟเฟกต์)
	for i = 1, 100 do
		barFill.Size = UDim2.new(i / 100, 0, 1, 0)
		percent.Text = tostring(i) .. "%"

		if i < 35 then
			status.Text = "CONNECTING..."
		elseif i < 75 then
			status.Text = "LOADING MAP..."
		else
			status.Text = "PREPARING PLAYER..."
		end

		task.wait(0.015)
	end

	status.Text = "READY"

	-- คืนการควบคุมกล้องให้ตัวละครก่อน Spawn
	disableLoginCamera()

	-- สั่ง Server ให้ Spawn ตัวละคร
	playEvent:FireServer()

	task.wait(0.5)

	loadingGui:Destroy()
	menu:Destroy()
end)

