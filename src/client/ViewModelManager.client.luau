--------------------------------------------------------------
-- ViewModelManager.luau  (LocalScript)
-- จัดการแขนและอาวุธแบบ First Person แท้ๆ (เฉพาะตอนมุมมอง First Person)
--------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local EquipUpdateEvent = ReplicatedStorage:WaitForChild("EquipUpdate")
local startGameplayEvent = ReplicatedStorage:WaitForChild("StartGameplay")

local viewModel: Model? = nil
local vmAnimator: Animator? = nil
local currentWeaponId = nil

-- CFrame พื้นฐานของ ViewModel เทียบกับกล้อง
local VM_OFFSET = CFrame.new(0, -1.0, -1.5)

local function clearViewModel()
	if viewModel then
		viewModel:Destroy()
		viewModel = nil
		vmAnimator = nil
	end
end

-- ดึงปืนจากตัวจริงมาใส่ ViewModel
local function syncWeaponToViewModel(char: Model)
	if not viewModel then return end
	
	-- ลบปืนเก่า
	local oldWep = viewModel:FindFirstChild("EquippedWeapon")
	if oldWep then oldWep:Destroy() end
	local rightHand = viewModel:FindFirstChild("RightHand")
	if rightHand then
		local oldGrip = rightHand:FindFirstChild("RightGrip")
		if oldGrip then oldGrip:Destroy() end
	end

	if not currentWeaponId then return end

	-- รอให้ปืนโผล่ที่ตัวจริงก่อน
	local realWeapon = char:WaitForChild("EquippedWeapon", 2)
	if not realWeapon then return end

	local vmWeapon = realWeapon:Clone()
	-- ปรับให้ปืนใน ViewModel เห็นชัดเจน 100%
	for _, part in ipairs(vmWeapon:GetDescendants()) do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
			part.CanCollide = false
			part.CastShadow = false
		end
	end
	vmWeapon.Parent = viewModel

	local realGrip = char:FindFirstChild("RightHand") and char.RightHand:FindFirstChild("RightGrip")
	local rightHand = viewModel:FindFirstChild("RightHand")
	if realGrip and rightHand then
		local vmGrip = realGrip:Clone()
		vmGrip.Part0 = rightHand
		vmGrip.Part1 = vmWeapon:FindFirstChild("Handle") or vmWeapon.PrimaryPart
		vmGrip.Parent = rightHand
	end
end

local function buildViewModel(char: Model)
	print("[ViewModelManager] buildViewModel started for", char.Name)
	clearViewModel()
	
	-- รอให้ RightHand โหลดเสร็จก่อนโคลน (กันบัค RightHand is not a valid member)
	if not char:WaitForChild("RightHand", 5) then
		warn("[ViewModelManager] Failed to find RightHand on Character!")
		return
	end
	
	local oldArch = char.Archivable
	char.Archivable = true
	viewModel = char:Clone()
	char.Archivable = oldArch
	
	if not viewModel then
		print("[ViewModelManager] char:Clone() returned nil!")
		return
	end
	
	-- บังคับเซ็ต PrimaryPart เสมอ (ป้องกันบัคที่ Avatar ธรรมดาไม่มี PrimaryPart)
	local hrp = viewModel:FindFirstChild("HumanoidRootPart")
	if hrp then
		viewModel.PrimaryPart = hrp
	else
		warn("[ViewModelManager] NO HumanoidRootPart in cloned character!")
		return
	end
	
	print("[ViewModelManager] char cloned successfully")
	viewModel.Name = "ViewModel"
	
	local function isArm(name)
		return name == "RightUpperArm" or name == "RightLowerArm" or name == "RightHand" or
		       name == "LeftUpperArm" or name == "LeftLowerArm" or name == "LeftHand"
	end
	
	for _, child in ipairs(viewModel:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.CanCollide = false
			child.CastShadow = false
			
			if isArm(child.Name) then
				child.LocalTransparencyModifier = 0
				child.Transparency = 0
			else
				if child.Name ~= "HumanoidRootPart" then
					child.LocalTransparencyModifier = 1
					child.Transparency = 1
				end
			end
		elseif child:IsA("Decal") and child.Parent and child.Parent:IsA("BasePart") then
			if not isArm(child.Parent.Name) then
				child.Transparency = 1
			end
		elseif child:IsA("Accessory") then
			-- ซ่อน Accessory ทั้งหมด
			local handle = child:FindFirstChild("Handle")
			if handle then handle.LocalTransparencyModifier = 1 handle.Transparency = 1 end
		end
	end
	
	-- ลบอาวุธเก่าที่ติดมากับการ Clone
	local oldWep = viewModel:FindFirstChild("EquippedWeapon")
	if oldWep then oldWep:Destroy() end
	
	local hum = viewModel:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		vmAnimator = hum:FindFirstChildOfClass("Animator")
		if not vmAnimator then
			vmAnimator = Instance.new("Animator")
			vmAnimator.Parent = hum
		end
	end
	
	-- DEBUG CUBE: ช่วยตรวจสอบว่า ViewModel อยู่ตรงไหน!
	if viewModel.PrimaryPart then
		local debugCube = Instance.new("Part")
		debugCube.Name = "DEBUG_CUBE"
		debugCube.Size = Vector3.new(0.5, 0.5, 0.5)
		debugCube.Color = Color3.new(1, 0, 0) -- สีแดง
		debugCube.Material = Enum.Material.Neon
		debugCube.CanCollide = false
		debugCube.Anchored = false
		debugCube.Massless = true
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = debugCube
		weld.Part1 = viewModel.PrimaryPart
		weld.Parent = debugCube
		
		debugCube.CFrame = viewModel.PrimaryPart.CFrame
		debugCube.Parent = viewModel
	end
	
	print("[ViewModelManager] ViewModel built successfully with", #viewModel:GetDescendants(), "descendants")
	
	_G.ViewModelAnimator = vmAnimator
	
	viewModel.Parent = workspace
	print("[ViewModelManager] ViewModel parented to workspace (Local only)")
	
	syncWeaponToViewModel(char)
end

startGameplayEvent.OnClientEvent:Connect(function()
	print("[ViewModelManager] StartGameplayEvent received")
	if player.Character then
		buildViewModel(player.Character)
	else
		print("[ViewModelManager] player.Character is nil during StartGameplayEvent")
	end
end)

EquipUpdateEvent.OnClientEvent:Connect(function(_, itemId)
	currentWeaponId = itemId
	if player.Character then
		task.delay(0.1, function()
			syncWeaponToViewModel(player.Character)
		end)
	end
end)

-- ควบคุม ViewModel ให้ติดกล้องและคำนวณ ADS
RunService.RenderStepped:Connect(function(dt)
	local currentCam = workspace.CurrentCamera
	if not viewModel or not viewModel.PrimaryPart or not currentCam then return end
	
	-- ใช้ Workspace แทน Camera เพื่อหลีกเลี่ยงบัคการ Render ของ Humanoid
	if viewModel.Parent ~= workspace then
		viewModel.Parent = workspace
	end
	
	local targetCFrame = currentCam.CFrame * VM_OFFSET
	
	-- ซ่อน/แสดง ViewModel ตามมุมมอง
	local isFirstPerson = _G.IsFirstPerson or false
	
	if not isFirstPerson then
		viewModel:PivotTo(CFrame.new(0, 5000, 0)) -- ซ่อนไว้บนฟ้าชั่วคราวตอนมุมมอง Third Person (ห้ามลงใต้ดินเกิน -500 เดี๋ยวโดนระบบเกมลบทิ้ง)
		return
	end
	
	-- ค่อยๆ ขยับกล้องไปหา AimPart ถ้า IsADS
	if _G.IsADS then
		local wep = viewModel:FindFirstChild("EquippedWeapon")
		local aimPart = wep and wep:FindFirstChild("AimPart")
		if aimPart then
			-- หา offset จาก Root ไปหา AimPart
			local offset = viewModel.PrimaryPart.CFrame:ToObjectSpace(aimPart.CFrame)
			-- ให้ ViewModel เลื่อนถอยกลับไปเท่ากับระยะ offset
			targetCFrame = currentCam.CFrame * offset:Inverse()
		end
	end
	
	-- เลื่อน ViewModel แบบดิบๆ ไปก่อน (ในอนาคตใส่ Spring ได้)
	viewModel:PivotTo(targetCFrame)
end)

player.CharacterAdded:Connect(function(char)
	char.Humanoid.Died:Connect(clearViewModel)
end)

print("[ViewModelManager] Ready")
