--------------------------------------------------------------
-- WeaponClient.lua  (LocalScript)
-- วางใน: StarterPlayer → StarterPlayerScripts
--
-- จัดการ Input ของอาวุธ (คลิกยิง, รีโหลด, สลับปืน) และแสดง HUD อาวุธ
--------------------------------------------------------------

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

-- รอให้เกมเริ่ม
local startGameplay = ReplicatedStorage:WaitForChild("StartGameplay")
startGameplay.OnClientEvent:Wait()

-- ═══════════════════════════════════════════════
--  โหลดโมดูล & RemoteEvents
-- ═══════════════════════════════════════════════
local ItemDatabase       = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local ShootEvent         = ReplicatedStorage:WaitForChild("ShootWeapon")
local MeleeEvent         = ReplicatedStorage:WaitForChild("MeleeAttack")
local ReloadEvent        = ReplicatedStorage:WaitForChild("ReloadWeapon")
local EquipUpdateEvent   = ReplicatedStorage:WaitForChild("EquipUpdate")
local SyncInventoryEvent = ReplicatedStorage:WaitForChild("SyncInventory")

-- ═══════════════════════════════════════════════
--  STATE อาวุธปัจจุบัน
-- ═══════════════════════════════════════════════
local currentWeaponId = nil
local currentAmmo     = 0
local isReloading     = false
local isMouseDown     = false
local lastFireTime    = 0

-- ═══════════════════════════════════════════════
--  สร้าง HUD แสดงอาวุธและกระสุน
-- ═══════════════════════════════════════════════
local playerGui = player:WaitForChild("PlayerGui")
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "WeaponHudGui"
hudGui.ResetOnSpawn = false
hudGui.Parent = playerGui

local hudFrame = Instance.new("Frame")
hudFrame.Size = UDim2.new(0, 200, 0, 70)
hudFrame.Position = UDim2.new(1, -220, 1, -90) -- มุมขวาล่าง
hudFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
hudFrame.BackgroundTransparency = 0.5
hudFrame.BorderSizePixel = 0
hudFrame.Visible = false
hudFrame.Parent = hudGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hudFrame

local weaponNameLbl = Instance.new("TextLabel")
weaponNameLbl.Size = UDim2.new(1, -20, 0, 30)
weaponNameLbl.Position = UDim2.new(0, 10, 0, 5)
weaponNameLbl.BackgroundTransparency = 1
weaponNameLbl.Text = "WEAPON NAME"
weaponNameLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
weaponNameLbl.Font = Enum.Font.GothamBold
weaponNameLbl.TextSize = 16
weaponNameLbl.TextXAlignment = Enum.TextXAlignment.Right
weaponNameLbl.Parent = hudFrame

local ammoLbl = Instance.new("TextLabel")
ammoLbl.Size = UDim2.new(1, -20, 0, 30)
ammoLbl.Position = UDim2.new(0, 10, 0, 35)
ammoLbl.BackgroundTransparency = 1
ammoLbl.Text = "30 / 30"
ammoLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
ammoLbl.Font = Enum.Font.GothamBold
ammoLbl.TextSize = 24
ammoLbl.TextXAlignment = Enum.TextXAlignment.Right
ammoLbl.Parent = hudFrame

-- ═══════════════════════════════════════════════
--  อัพเดต HUD
-- ═══════════════════════════════════════════════
local function updateHud()
	if not currentWeaponId then
		hudFrame.Visible = false
		return
	end

	local itemData = ItemDatabase.GetItem(currentWeaponId)
	if not itemData then return end

	hudFrame.Visible = true
	weaponNameLbl.Text = itemData.Name:upper()

	if itemData.Subtype == "Melee" then
		ammoLbl.Text = "∞"
	else
		if isReloading then
			ammoLbl.Text = "RELOADING..."
			ammoLbl.TextColor3 = Color3.fromRGB(255, 200, 0)
		else
			ammoLbl.Text = tostring(currentAmmo) .. " / " .. tostring(itemData.MagazineSize or 0)

			if currentAmmo == 0 then
				ammoLbl.TextColor3 = Color3.fromRGB(255, 50, 50)
			else
				ammoLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end
end

-- รับการเปลี่ยนแปลงอาวุธจาก Server (จากการกด 1/2 สลับปืน หรือ equip/unequip)
EquipUpdateEvent.OnClientEvent:Connect(function(slotName, itemId)
	if itemId then
		currentWeaponId = itemId
	else
		currentWeaponId = nil
	end
	updateHud()
end)

-- รับข้อมูลกระสุนอัพเดต
SyncInventoryEvent.OnClientEvent:Connect(function(data)
	if not data or not data.equipment or not data.activeWeaponSlot then return end

	local activeEq = data.equipment[data.activeWeaponSlot]
	if activeEq and activeEq.itemId == currentWeaponId then
		currentAmmo = activeEq.ammo or 0
		updateHud()
	end
end)

-- ═══════════════════════════════════════════════
--  ระบบยิง
-- ═══════════════════════════════════════════════
local function fireWeapon()
	if not currentWeaponId or isReloading then return end

	-- เช็คว่าเปิด Inventory อยู่ไหม
	local flag = playerGui:FindFirstChild("InventoryOpen")
	if flag and flag.Value then return end

	local itemData = ItemDatabase.GetItem(currentWeaponId)
	if not itemData then return end

	-- เช็ค Cooldown
	local now = os.clock()
	if now - lastFireTime < (itemData.FireRate or 0.5) then return end

	if itemData.Subtype == "Melee" then
		-- ฟันมีด
		lastFireTime = now
		MeleeEvent:FireServer(mouse.Hit.Position)
	else
		-- ปืน
		if currentAmmo > 0 then
			lastFireTime = now
			currentAmmo = currentAmmo - 1 -- หักหลอกใน Client ไปก่อนให้ดูเร็ว Server จะหักจริงทีหลัง
			updateHud()

			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				-- จุดกำเนิดกระสุน (สมมติว่าเป็นตรงหน้าอก)
				local origin = character.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0)
				ShootEvent:FireServer(origin, mouse.Hit.Position)
			end
		else
			-- กระสุนหมด
			-- สามารถเล่นเสียงแชะ (Click) ได้ที่นี่
		end
	end
end

-- ลูปสำหรับการยิงแบบออโต้ (กดค้าง)
RunService.RenderStepped:Connect(function()
	if isMouseDown and currentWeaponId then
		local itemData = ItemDatabase.GetItem(currentWeaponId)
		if itemData and itemData.Type == "Weapon" then
			-- ถ้าปืนออโต้ หรือเป็นปืนแต่กดคลิกพอดี (Semi-auto ต้องทำเพิ่มถ้าอยากให้กดทีละนัด)
			-- ตอนนี้ให้ยิงออโต้หมดถ้าระยะเวลา Cooldown ถึง
			fireWeapon()
		end
	end
end)

-- ═══════════════════════════════════════════════
--  INPUTS
-- ═══════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isMouseDown = true
	elseif input.KeyCode == Enum.KeyCode.R then
		if currentWeaponId and not isReloading then
			local itemData = ItemDatabase.GetItem(currentWeaponId)
			if itemData and itemData.Subtype ~= "Melee" and currentAmmo < (itemData.MagazineSize or 0) then
				isReloading = true
				updateHud()
				ReloadEvent:FireServer()

				-- หน่วงเวลา Reload (Server จะ Sync กลับมาอีกที แต่ตั้งหลอกๆ ให้คลิกไม่ได้ไปก่อน)
				task.delay(itemData.ReloadTime or 2, function()
					isReloading = false
					updateHud()
				end)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.One then
		-- ขอ Server สลับเป็นอาวุธหลัก
		-- ต้องส่งผ่าน Remote แต่เพื่อให้เร็วและมี InventoryManager ใน_G อยู่บน Server เราควรเพิ่ม RemoteEvent
		local swapRemote = ReplicatedStorage:FindFirstChild("EquipItem") -- เราใช้ร่วมกับตอนคลิกใน Inventory?
		-- เนื่องจากเรายังไม่มี Remote สำหรับ SwitchWeapon แบบกดเลข งั้นขอใช้ Remote พิเศษ หรือให้ _G จัดการ
		local switchRemote = ReplicatedStorage:FindFirstChild("SwitchWeaponSlot")
		if switchRemote then switchRemote:FireServer("Primary") end
	elseif input.KeyCode == Enum.KeyCode.Two then
		local switchRemote = ReplicatedStorage:FindFirstChild("SwitchWeaponSlot")
		if switchRemote then switchRemote:FireServer("Secondary") end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isMouseDown = false
	end
end)

print("[WeaponClient] Ready")