--------------------------------------------------------------
-- WeaponHandler.lua  (Script)
-- วางใน: ServerScriptService
--
-- จัดการการยิงปืน, กระสุน (Projectile), Damage, และ Melee
--------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

-- ═══════════════════════════════════════════════
--  โหลด Dependencies
-- ═══════════════════════════════════════════════
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

-- รอให้ InventoryManager โหลดก่อน
task.wait(1)

-- ═══════════════════════════════════════════════
--  REMOTE EVENTS
-- ═══════════════════════════════════════════════
local function createRemote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local ShootEvent  = createRemote("ShootWeapon")  -- Client ขอส่งกระสุน
local MeleeEvent  = createRemote("MeleeAttack")  -- Client ขอฟันมีด
local ReloadEvent = createRemote("ReloadWeapon") -- Client ขอรีโหลด

-- ═══════════════════════════════════════════════
--  ANTI-CHEAT / COOLDOWN TRACKING
-- ═══════════════════════════════════════════════
local playerCooldowns = {} -- [player.UserId] = timestamp ครั้งล่าสุดที่ยิง

local function canFire(player, fireRate)
	local lastFire = playerCooldowns[player.UserId] or 0
	local now = os.clock()
	if now - lastFire >= fireRate * 0.9 then -- ให้ระยะเผื่อ 10% กัน ping
		playerCooldowns[player.UserId] = now
		return true
	end
	return false
end

-- ทำความสะอาดข้อมูลเมื่อออกเกม
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)

-- ═══════════════════════════════════════════════
--  PROJECTILE SYSTEM (ปืน)
-- ═══════════════════════════════════════════════
local function createProjectile(player, itemData, originPosition, shootDirection)
	-- สร้าง Part เป็นกระสุน
	local bullet = Instance.new("Part")
	bullet.Name = "Projectile_" .. player.Name
	bullet.Size = Vector3.new(0.2, 0.2, 1) -- กระสุนทรงยาว
	bullet.BrickColor = BrickColor.new("Bright yellow")
	bullet.Material = Enum.Material.Neon
	bullet.CanCollide = false -- ไม่ชนกับของทั่วไปทันที (ใช้ Touched)
	bullet.Massless = true

	-- ชี้ไปทางที่จะยิง
	bullet.CFrame = CFrame.lookAt(originPosition, originPosition + shootDirection)

	-- ใส่ BodyVelocity เพื่อให้กระสุนพุ่ง
	local bv = Instance.new("BodyVelocity")
	bv.Velocity = shootDirection * itemData.ProjectileSpeed
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Parent = bullet

	-- ทำลายกระสุนอัตโนมัติหลัง 3 วินาที (กันค้างในแมพ)
	Debris:AddItem(bullet, 3)
	bullet.Parent = workspace

	-- ตรวจจับการชน
	local hitConnection
	hitConnection = bullet.Touched:Connect(function(hit)
		-- ข้ามถ้าชนผู้เล่นตัวเอง หรือชนอาวุธ
		if hit:IsDescendantOf(player.Character) then return end
		if hit.Name == "Handle" then return end

		-- ตรวจสอบว่าชนสิ่งที่มีเลือด (Humanoid) ไหม
		local model = hit:FindFirstAncestorOfClass("Model")
		if model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				-- ปิดการชนซ้ำ
				hitConnection:Disconnect()

				-- คำนวณ Damage เบื้องต้น (จะเพิ่มระบบ Headshot ทีหลัง)
				local damage = itemData.Damage

				-- สร้าง Visual Hit Marker ชั่วคราว
				local highlight = Instance.new("Highlight")
				highlight.FillColor = Color3.new(1, 0, 0)
				highlight.FillTransparency = 0.5
				highlight.OutlineTransparency = 1
				highlight.Parent = model
				Debris:AddItem(highlight, 0.2)

				humanoid:TakeDamage(damage)
				print("[WeaponHandler]", player.Name, "hit", model.Name, "for", damage, "damage!")

				-- ทำลายกระสุน
				bullet:Destroy()
				return
			end
		end

		-- ชนกำแพง/พื้น
		if hit.CanCollide then
			hitConnection:Disconnect()
			bullet:Destroy()
		end
	end)
end

-- ═══════════════════════════════════════════════
--  EVENT: ยิงปืน
-- ═══════════════════════════════════════════════
ShootEvent.OnServerEvent:Connect(function(player, originPosition, targetPosition)
	-- ตรวจสอบ InventoryManager
	if not _G.InventoryManager then return end

	-- เช็คว่าผู้เล่นกำลังถืออาวุธไหน
	local itemId, currentAmmo, slotName = _G.InventoryManager.GetActiveWeapon(player)
	if not itemId then return end

	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData or itemData.Type ~= "Weapon" or itemData.Subtype == "Melee" then return end

	-- เช็ค Cooldown
	if not canFire(player, itemData.FireRate) then return end

	-- หักกระสุน
	local success, remainingAmmo = _G.InventoryManager.UseAmmo(player)
	if not success then return end -- ไม่มีกระสุน

	-- คำนวณทิศทาง
	local character = player.Character
	if not character then return end

	local shootDirection = (targetPosition - originPosition).Unit

	-- ถ้าเป็นปืนลูกซอง ยิงหลายนัด
	if itemData.Subtype == "Shotgun" then
		local pellets = itemData.Pellets or 8
		for i = 1, pellets do
			-- เพิ่ม Spread (การกระจาย)
			local spreadAngle = math.rad(itemData.Spread or 5)
			local randomDir = CFrame.lookAt(Vector3.zero, shootDirection) * CFrame.Angles(
				(math.random() - 0.5) * spreadAngle,
				(math.random() - 0.5) * spreadAngle,
				0
			)
			createProjectile(player, itemData, originPosition, randomDir.LookVector)
		end
	else
		-- ปืนปกติ ยิงนัดเดียว
		createProjectile(player, itemData, originPosition, shootDirection)
	end
end)

-- ═══════════════════════════════════════════════
--  EVENT: มีด (Melee)
-- ═══════════════════════════════════════════════
MeleeEvent.OnServerEvent:Connect(function(player, targetPosition)
	if not _G.InventoryManager then return end

	local itemId, _, _ = _G.InventoryManager.GetActiveWeapon(player)
	if not itemId then return end

	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData or itemData.Subtype ~= "Melee" then return end

	if not canFire(player, itemData.AttackSpeed or 0.5) then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- ค้นหาเป้าหมายในระยะ Range
	local range = itemData.Range or 7
	local hitAny = false

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local targetRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local distance = (targetRoot.Position - rootPart.Position).Magnitude
				if distance <= range then
					local humanoid = otherPlayer.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid:TakeDamage(itemData.Damage)
						print("[WeaponHandler]", player.Name, "knifed", otherPlayer.Name, "for", itemData.Damage)
						hitAny = true
					end
				end
			end
		end
	end

	-- TODO: สามารถเพิ่มการฟันโดน NPC/Zombie ตรงนี้ได้
end)

-- ═══════════════════════════════════════════════
--  EVENT: รีโหลดปืน
-- ═══════════════════════════════════════════════
ReloadEvent.OnServerEvent:Connect(function(player)
	if not _G.InventoryManager then return end

	local success, newAmmo, reloadTime = _G.InventoryManager.Reload(player)
	if success then
		print("[WeaponHandler]", player.Name, "reloaded. Ammo:", newAmmo)
		-- สามารถส่ง Event แจ้งให้ Client เล่น Animation รีโหลดได้ที่นี่
	end
end)

print("[WeaponHandler] Ready")