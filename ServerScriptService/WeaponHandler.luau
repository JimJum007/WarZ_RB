--------------------------------------------------------------
-- WeaponHandler.lua  (Script)
-- วางใน: ServerScriptService
--
-- ยิง / Melee / Damage / Armor / Headshot / Anti-cheat
-- v2 — Raycast projectile, server-authoritative origin, reload lock
--------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

task.wait(1) -- รอ InventoryManager

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  REMOTE EVENTS
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function createRemote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name   = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local ShootEvent    = createRemote("ShootWeapon")
local MeleeEvent    = createRemote("MeleeAttack")
local ReloadEvent   = createRemote("ReloadWeapon")
local HitMarkerEvent = createRemote("HitMarker")   -- Server  Client (feedback)

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  CONSTANTS
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local MAX_BULLET_RANGE = 600
local MAX_STEP         = 25    -- cap ระยะต่อเฟรม กัน lag spike ทะลุกำแพง
local HEADSHOT_MULT    = 2

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  ANTI-CHEAT STATE
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local playerCooldowns = {}   -- [UserId] = timestamp ยิงล่าสุด
local reloadingUntil  = {}   -- [UserId] = timestamp reload เสร็จ

local function canFire(player, fireRate)
	-- กำลัง reload  ยิงไม่ได้
	if (reloadingUntil[player.UserId] or 0) > os.clock() then return false end

	local lastFire = playerCooldowns[player.UserId] or 0
	local now      = os.clock()
	if now - lastFire >= (fireRate or 0.5) * 0.9 then  -- เผื่อ ping 10%
		playerCooldowns[player.UserId] = now
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
	reloadingUntil[player.UserId]  = nil
end)

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  DAMAGE GATE (PvP + PvE)
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function canDamage(attackerChar, victimChar)
	if not attackerChar or not victimChar then return false end
	if attackerChar == victimChar then return false end

	local aTeam = attackerChar:GetAttribute("Team") or "Player"
	local vTeam = victimChar:GetAttribute("Team")  or "Player"

	-- NPC ฝ่ายเดียวกันไม่ทำร้ายกันเอง / Player ยิงได้ทุกอย่าง
	if aTeam == vTeam and aTeam ~= "Player" then return false end
	return true
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  DAMAGE CALC — Armor + Headshot
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function resolveDamage(attacker, hitPart, baseDamage)
	if not hitPart then return false end

	local model = hitPart:FindFirstAncestorOfClass("Model")
	if not model then return false end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if not canDamage(attacker.Character, model) then return false end

	local isHead = (hitPart.Name == "Head")
	local dmg    = isHead and (baseDamage * HEADSHOT_MULT) or baseDamage

	-- ลด damage ตาม equipment ของเหยื่อ
	local victim = Players:GetPlayerFromCharacter(model)
	if victim and _G.InventoryManager then
		local inv = _G.InventoryManager.GetInventory(victim)
		if inv then
			if isHead and inv.equipment.Headgear then
				local hd = ItemDatabase.GetItem(inv.equipment.Headgear.itemId)
				if hd then dmg = dmg * (1 - (hd.HeadshotReduction or 0)) end
			end
			if inv.equipment.Armor then
				local ar = ItemDatabase.GetItem(inv.equipment.Armor.itemId)
				if ar then dmg = dmg * (1 - (ar.DamageReduction or 0)) end
			end
		end
	end

	-- Visual feedback
	local hl = Instance.new("Highlight")
	hl.FillColor           = isHead and Color3.new(1, 0.45, 0) or Color3.new(1, 0, 0)
	hl.FillTransparency    = 0.6
	hl.OutlineTransparency = 1
	hl.Parent = model
	Debris:AddItem(hl, 0.15)

	hum:TakeDamage(dmg)
	HitMarkerEvent:FireClient(attacker, isHead, math.floor(dmg + 0.5))

	print(string.format("[WeaponHandler] %s  %s  %.1f dmg%s",
		attacker.Name, model.Name, dmg, isHead and "  (HEADSHOT)" or ""))
	return true
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  PROJECTILE — Raycast แบบเดินทีละ step
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function createProjectile(player, itemData, origin, direction)
	local speed    = itemData.ProjectileSpeed or 400
	local traveled = 0

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		player.Character,
		workspace:FindFirstChild("ItemSpawns"),
	}

	local bullet = Instance.new("Part")
	bullet.Name       = "Projectile"
	bullet.Size       = Vector3.new(0.15, 0.15, 1.4)
	bullet.Color      = Color3.fromRGB(255, 230, 120)
	bullet.Material   = Enum.Material.Neon
	bullet.Anchored   = true
	bullet.CanCollide = false
	bullet.CanQuery   = false
	bullet.CanTouch   = false
	bullet.CastShadow = false
	bullet.CFrame     = CFrame.lookAt(origin, origin + direction)
	bullet.Parent     = workspace

	local pos  = origin
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not bullet.Parent then
			conn:Disconnect()
			return
		end

		local step   = math.min(speed * dt, MAX_STEP)
		local result = workspace:Raycast(pos, direction * step, params)

		if result then
			resolveDamage(player, result.Instance, itemData.Damage)
			conn:Disconnect()
			bullet:Destroy()
			return
		end

		pos = pos + direction * step
		bullet.CFrame = CFrame.lookAt(pos, pos + direction)

		traveled = traveled + step
		if traveled >= MAX_BULLET_RANGE then
			conn:Disconnect()
			bullet:Destroy()
		end
	end)
end

-- กระจายทิศทางตาม Spread (องศา)
local function applySpread(direction, spreadDeg)
	if not spreadDeg or spreadDeg <= 0 then return direction end
	local rad = math.rad(spreadDeg)
	local cf  = CFrame.lookAt(Vector3.zero, direction)
		* CFrame.Angles(
			(math.random() - 0.5) * rad,
			(math.random() - 0.5) * rad,
			0
		)
	return cf.LookVector
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  EVENT: ยิงปืน
-- อออออออออออออออออออออออออออออออออออออออออออออออ
ShootEvent.OnServerEvent:Connect(function(player, aimPoint)
	if typeof(aimPoint) ~= "Vector3" then return end
	if not _G.InventoryManager then return end

	local itemId = _G.InventoryManager.GetActiveWeapon(player)
	if not itemId then return end

	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData then return end
	if itemData.Type ~= "Weapon" or itemData.Subtype == "Melee" then return end

	if not canFire(player, itemData.FireRate) then return end

	-- หักกระสุน (server เป็นคนตัดสิน)
	local ok = _G.InventoryManager.UseAmmo(player)
	if not ok then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- ?? Server คำนวณจุดยิงเอง ห้ามเชื่อ client
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local delta  = aimPoint - origin
	if delta.Magnitude < 0.1 then return end
	if delta.Magnitude > MAX_BULLET_RANGE * 1.5 then return end  -- กัน aim ข้ามแมพ
	local dir = delta.Unit

	if itemData.Subtype == "Shotgun" then
		for _ = 1, (itemData.Pellets or 8) do
			createProjectile(player, itemData, origin, applySpread(dir, itemData.Spread))
		end
	else
		createProjectile(player, itemData, origin, applySpread(dir, itemData.Spread))
	end
end)

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  EVENT: Melee
-- อออออออออออออออออออออออออออออออออออออออออออออออ
MeleeEvent.OnServerEvent:Connect(function(player)
	if not _G.InventoryManager then return end

	local itemId = _G.InventoryManager.GetActiveWeapon(player)
	if not itemId then return end

	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData or itemData.Subtype ~= "Melee" then return end

	if not canFire(player, itemData.AttackSpeed or 0.5) then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local range  = itemData.Range or 7
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local hits    = workspace:GetPartBoundsInRadius(rootPart.Position, range, params)
	local damaged = {}

	for _, part in ipairs(hits) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not damaged[model] then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and canDamage(character, model) then
				-- ต้องหันหน้าไปทางเป้าหมาย (กันฟันคนข้างหลัง)
				local toTarget = model:GetPivot().Position - rootPart.Position
				if toTarget.Magnitude > 0.1 then
					local dot = rootPart.CFrame.LookVector:Dot(toTarget.Unit)
					if dot > 0.3 then
						damaged[model] = true
						resolveDamage(player, part, itemData.Damage)
					end
				end
			end
		end
	end
end)

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  EVENT: Reload
-- อออออออออออออออออออออออออออออออออออออออออออออออ
ReloadEvent.OnServerEvent:Connect(function(player)
	if not _G.InventoryManager then return end
	if (reloadingUntil[player.UserId] or 0) > os.clock() then return end  -- กันสแปม

	local success, newAmmo, reloadTime = _G.InventoryManager.Reload(player)
	if success then
		reloadingUntil[player.UserId] = os.clock() + (reloadTime or 2)
		print("[WeaponHandler]", player.Name, "reloading ", newAmmo)
	end
end)

print("[WeaponHandler] Ready (v2 — raycast + server-auth)")