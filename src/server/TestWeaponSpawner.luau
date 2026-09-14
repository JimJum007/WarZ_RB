--------------------------------------------------------------
-- TestWeaponSpawner.luau  (Script — ServerScriptService)
-- เสกอาวุธทดสอบกลางแมพ
-- ⚠️ ไม่สร้าง BillboardGui เอง — ปล่อยให้ ItemSpawner จัดการ visual
--    (ก่อนหน้านี้สร้างซ้อนกัน 2 อัน ป้ายชื่อทับกัน)
--------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

local ENABLED       = true               -- ปิดตอน production
local startPosition = Vector3.new(0, 5, 20)
local spacing       = 4

local itemSpawnsFolder = workspace:FindFirstChild("ItemSpawns")
if not itemSpawnsFolder then
	itemSpawnsFolder = Instance.new("Folder")
	itemSpawnsFolder.Name   = "ItemSpawns"
	itemSpawnsFolder.Parent = workspace
end

-- กระสุนติดมาด้วยตอนเก็บ (ไม่งั้นเก็บปืนมาแล้วยิงไม่ออก)
local STARTING_AMMO = {
	rifle = 30, ak = 30, smg = 30, lmg = 100, sniper = 10,
	shotgun = 5, pistol = 7,
}

local function spawnItemForTesting()
	local offset = 0
	for itemId, itemData in pairs(ItemDatabase.Items) do
		if type(itemData) == "table" and itemData.Type == "Weapon" then
			local dropPart = Instance.new("Part")
			dropPart.Name       = "ItemSpawn_" .. itemId
			dropPart.Size       = Vector3.new(1.5, 1.5, 1.5)
			dropPart.Position   = startPosition + Vector3.new(offset, 0, 0)
			dropPart.Anchored   = true
			dropPart.CanCollide = false

			-- ให้ ItemSpawner รู้ว่าต้องใส่กระสุนเท่าไหร่
			dropPart:SetAttribute("SpawnAmmo", STARTING_AMMO[itemId] or 0)

			dropPart.Parent = itemSpawnsFolder   -- ChildAdded → ItemSpawner ตกแต่งให้เอง
			offset = offset + spacing
		end
	end
	print("[TestWeaponSpawner] เสกอาวุธทดสอบเสร็จ")
end

if ENABLED then
	task.wait(2)
	spawnItemForTesting()
end