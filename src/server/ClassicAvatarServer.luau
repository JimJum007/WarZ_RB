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

local playerGui = player:WaitForChild("PlayerGui")
local function updateHud() end   -- HUD ย้ายไป HUDClient แล้ว

-- รับการเปลี่ยนแปลงอาวุธจาก Server (จากการกด 1/2 สลับปืน หรือ equip/unequip)
EquipUpdateEvent.OnClientEvent:Connect(function(slotName, itemId)
	isReloading = false
	lastFireTime = 0
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
		if _G.PlayWeaponAction then _G.PlayWeaponAction("Attack") end
		MeleeEvent:FireServer()
	else
		-- ปืน
		if currentAmmo > 0 then
			lastFireTime = now
			currentAmmo = currentAmmo - 1 -- หักหลอกใน Client ไปก่อนให้ดูเร็ว Server จะหักจริงทีหลัง
			updateHud()

			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				if _G.PlayWeaponAction then _G.PlayWeaponAction("Fire") end
				ShootEvent:FireServer(mouse.Hit.Position)
			end
		else
			-- กระสุนหมด
			-- สามารถเล่นเสียงแชะ (Click) ได้ที่นี่
		end
	end
end

-- ลูปสำหรับการยิงแบบออโต้ (กดค้าง)
-- ยิงต่อเนื่องเฉพาะปืนออโต้
RunService.Heartbeat:Connect(function()
	if not isMouseDown or not currentWeaponId then return end
	local itemData = ItemDatabase.GetItem(currentWeaponId)
	if itemData and itemData.Automatic then
		fireWeapon()
	end
end)

-- ═══════════════════════════════════════════════
--  INPUTS
-- ═══════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isMouseDown = true
		fireWeapon()   -- นัดแรกยิงทันที (รองรับ semi-auto)
	elseif input.KeyCode == Enum.KeyCode.R then
		if currentWeaponId and not isReloading then
			local itemData = ItemDatabase.GetItem(currentWeaponId)
			if itemData and itemData.Subtype ~= "Melee" and currentAmmo < (itemData.MagazineSize or 0) then
				isReloading = true
				player:SetAttribute("Reloading", true)
				ReloadEvent:FireServer()

				-- หน่วงเวลา Reload (Server จะ Sync กลับมาอีกที แต่ตั้งหลอกๆ ให้คลิกไม่ได้ไปก่อน)
				task.delay(itemData.ReloadTime or 2, function()
					isReloading = false
					player:SetAttribute("Reloading", false)
				end)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.One then
		-- ขอ Server สลับเป็นอาวุธหลัก
		-- ต้องส่งผ่าน Remote แต่เพื่อให้เร็วและมี InventoryManager ใน_G อยู่บน Server เราควรเพิ่ม RemoteEvent
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

local HitMarkerEvent = ReplicatedStorage:WaitForChild("HitMarker")
HitMarkerEvent.OnClientEvent:Connect(function(isHead, dmg)
	print(isHead and "HEADSHOT!" or "HIT", dmg)
	-- TODO: แสดง X สีแดงกลางจอ + เสียง tick
end)

print("[WeaponClient] Ready")