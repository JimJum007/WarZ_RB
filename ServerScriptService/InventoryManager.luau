--------------------------------------------------------------
-- InventoryManager.lua  (Script)
-- วางใน: ServerScriptService
--
-- จัดการ Inventory ฝั่ง Server (source of truth)
-- Client ส่ง request  Server ตรวจสอบ + อัพเดต  sync กลับ Client
--------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  โหลด ItemDatabase
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  REMOTE EVENTS
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function createRemote(name, className)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new(className or "RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local PickupItemEvent    = createRemote("PickupItem")       -- Client  Server
local DropItemEvent      = createRemote("DropItem")         -- Client  Server
local EquipItemEvent     = createRemote("EquipItem")        -- Client  Server
local UnequipItemEvent   = createRemote("UnequipItem")      -- Client  Server
local SwapSlotsEvent     = createRemote("SwapSlots")        -- Client  Server
local SwitchWeaponEvent  = createRemote("SwitchWeaponSlot") -- Client  Server
local SyncInventoryEvent = createRemote("SyncInventory")    -- Server  Client
local EquipUpdateEvent   = createRemote("EquipUpdate")      -- Server  Client

-- BindableEvent สำหรับสั่ง ItemSpawner สร้างของกลางแมพ
local SpawnDroppedItem = ReplicatedStorage:FindFirstChild("SpawnDroppedItem")
if not SpawnDroppedItem then
	SpawnDroppedItem = Instance.new("BindableEvent")
	SpawnDroppedItem.Name   = "SpawnDroppedItem"
	SpawnDroppedItem.Parent = ReplicatedStorage
end


-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  CONSTANTS
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local GRID_SIZE = 20  -- 5?4 = 20 slots

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  PLAYER INVENTORIES
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local inventories = {}  -- [player] = { grid = {...}, equipment = {...} }

local function createInventory()
	local inv = {
		grid = {},        -- [slotIndex] = { itemId = "...", quantity = 1 }
		equipment = {     -- [slotName] = { itemId = "...", ammo = 0 } or nil
			Primary   = nil,
			Secondary = nil,
			Armor     = nil,
			Headgear  = nil,
		},
		activeWeaponSlot = nil,  -- "Primary" หรือ "Secondary"
	}

	-- สร้าง grid ว่าง 20 slots
	for i = 1, GRID_SIZE do
		inv.grid[i] = nil
	end

	return inv
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  HELPER FUNCTIONS
-- อออออออออออออออออออออออออออออออออออออออออออออออ

-- หา slot ว่างใน grid
local function findEmptySlot(inv)
	for i = 1, GRID_SIZE do
		if inv.grid[i] == nil then
			return i
		end
	end
	return nil  -- เต็ม
end

-- หา slot ที่มี item เดียวกันและยัง stack ได้
local function findStackableSlot(inv, itemId)
	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData or not itemData.StackSize then return nil end

	for i = 1, GRID_SIZE do
		local slot = inv.grid[i]
		if slot and slot.itemId == itemId then
			if slot.quantity < itemData.StackSize then
				return i
			end
		end
	end
	return nil
end

-- Sync inventory ทั้งหมดไป Client
local function syncInventory(player)
	local inv = inventories[player]
	if not inv then return end

	-- ส่ง grid + equipment ไป Client
	local gridData = {}
	for i = 1, GRID_SIZE do
		if inv.grid[i] then
			gridData[i] = {
				itemId   = inv.grid[i].itemId,
				quantity = inv.grid[i].quantity,
				ammo     = inv.grid[i].ammo,
			}
		end
	end

	local equipData = {}
	for slot, data in pairs(inv.equipment) do
		if data then
			equipData[slot] = {
				itemId = data.itemId,
				ammo   = data.ammo or 0,
			}
		end
	end

	SyncInventoryEvent:FireClient(player, {
		grid      = gridData,
		equipment = equipData,
		activeWeaponSlot = inv.activeWeaponSlot,
	})
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  PUBLIC API (ใช้โดย script อื่น)
-- อออออออออออออออออออออออออออออออออออออออออออออออ

-- เพิ่มไอเทมเข้า Inventory
function InventoryManager_AddItem(player, itemId, quantity, ammo)
	local inv = inventories[player]
	if not inv then return false, "No inventory" end

	local itemData = ItemDatabase.GetItem(itemId)
	if not itemData then return false, "Invalid item" end

	quantity = quantity or 1

	-- ถ้า stack ได้  หา slot ที่มีอยู่แล้ว
	if ItemDatabase.IsStackable(itemId) then
		while quantity > 0 do
			local stackSlot = findStackableSlot(inv, itemId)
			if stackSlot then
				local slot = inv.grid[stackSlot]
				local canAdd = itemData.StackSize - slot.quantity
				local toAdd = math.min(canAdd, quantity)
				slot.quantity = slot.quantity + toAdd
				quantity = quantity - toAdd
			else
				-- หา slot ว่าง
				local emptySlot = findEmptySlot(inv)
				if not emptySlot then
					syncInventory(player)
					return false, "Inventory full"
				end
				local toAdd = math.min(quantity, itemData.StackSize)
				inv.grid[emptySlot] = { itemId = itemId, quantity = toAdd }
				quantity = quantity - toAdd
			end
		end
	else
		-- ไม่ stack  1 item ต่อ 1 slot
		local emptySlot = findEmptySlot(inv)
		if not emptySlot then
			syncInventory(player)
			return false, "Inventory full"
		end
		inv.grid[emptySlot] = { itemId = itemId, quantity = 1, ammo = ammo or 0 }
	end

	syncInventory(player)
	return true
end

-- ลบไอเทมจาก grid slot
function InventoryManager_RemoveFromSlot(player, slotIndex, quantity)
	local inv = inventories[player]
	if not inv then return false end

	local slot = inv.grid[slotIndex]
	if not slot then return false end

	quantity = quantity or slot.quantity
	slot.quantity = slot.quantity - quantity

	if slot.quantity <= 0 then
		inv.grid[slotIndex] = nil
	end

	syncInventory(player)
	return true
end

-- Equip item จาก grid  equipment slot
function InventoryManager_EquipItem(player, gridSlot)
	local inv = inventories[player]
	if not inv then return false end

	local gridItem = inv.grid[gridSlot]
	if not gridItem then return false end

	local equipSlot = ItemDatabase.GetEquipSlot(gridItem.itemId)
	if not equipSlot then return false end  -- ไม่ใช่ equipment

	local itemData = ItemDatabase.GetItem(gridItem.itemId)

	-- ถ้ามีของเดิมอยู่  ย้ายกลับ grid
	local oldEquip = inv.equipment[equipSlot]
	if oldEquip then
		-- คืนของเดิมลง slot เดิม พร้อมกระสุนที่ค้างในแม็ก
		inv.grid[gridSlot] = {
			itemId   = oldEquip.itemId,
			quantity = 1,
			ammo     = oldEquip.ammo or 0,
		}
	else
		inv.grid[gridSlot] = nil
	end

	-- ใส่ equipment ใหม่ (กระสุนติดมากับไอเทม ไม่เติมฟรี)
	local newEquip = { itemId = gridItem.itemId }
	if ItemDatabase.IsGun(gridItem.itemId) then
		newEquip.ammo = gridItem.ammo or 0
	end

	inv.equipment[equipSlot] = newEquip

	-- ถ้า equip อาวุธ  ตั้งเป็น active weapon
	if equipSlot == "Primary" or equipSlot == "Secondary" then
		inv.activeWeaponSlot = equipSlot
		EquipUpdateEvent:FireClient(player, equipSlot, newEquip.itemId)
	end

	syncInventory(player)
	return true
end

-- Unequip จาก equipment  grid
function InventoryManager_UnequipItem(player, equipSlotName)
	local inv = inventories[player]
	if not inv then return false end

	local equip = inv.equipment[equipSlotName]
	if not equip then return false end

	local emptySlot = findEmptySlot(inv)
	if not emptySlot then return false, "Inventory full" end

	inv.grid[emptySlot] = { itemId = equip.itemId, quantity = 1, ammo = equip.ammo or 0 }
	inv.equipment[equipSlotName] = nil

	-- ถ้าถอดอาวุธที่กำลังใช้  ไม่มี active weapon
	if inv.activeWeaponSlot == equipSlotName then
		inv.activeWeaponSlot = nil
		EquipUpdateEvent:FireClient(player, nil, nil)
	end

	syncInventory(player)
	return true
end

-- สลับอาวุธ (กด 1/2)
function InventoryManager_SwitchWeapon(player, slot)
	local inv = inventories[player]
	if not inv then return end

	if slot ~= "Primary" and slot ~= "Secondary" then return end

	local equip = inv.equipment[slot]
	if equip then
		inv.activeWeaponSlot = slot
		EquipUpdateEvent:FireClient(player, slot, equip.itemId)
	end

	syncInventory(player)
end

-- ดึงข้อมูล active weapon
function InventoryManager_GetActiveWeapon(player)
	local inv = inventories[player]
	if not inv or not inv.activeWeaponSlot then return nil end

	local equip = inv.equipment[inv.activeWeaponSlot]
	if not equip then return nil end

	return equip.itemId, equip.ammo, inv.activeWeaponSlot
end

-- ใช้กระสุน (ยิง 1 นัด)
function InventoryManager_UseAmmo(player)
	local inv = inventories[player]
	if not inv or not inv.activeWeaponSlot then return false end

	local equip = inv.equipment[inv.activeWeaponSlot]
	if not equip or not equip.ammo or equip.ammo <= 0 then return false end

	equip.ammo = equip.ammo - 1
	syncInventory(player)
	return true, equip.ammo
end

-- Reload อาวุธปัจจุบัน
function InventoryManager_Reload(player)
	local inv = inventories[player]
	if not inv or not inv.activeWeaponSlot then return false end

	local equip = inv.equipment[inv.activeWeaponSlot]
	if not equip then return false end

	local itemData = ItemDatabase.GetItem(equip.itemId)
	if not itemData or not itemData.MagazineSize then return false end

	local needed = itemData.MagazineSize - (equip.ammo or 0)
	if needed <= 0 then return false end  -- กระสุนเต็มแล้ว

	local ammoType = itemData.AmmoType
	if not ammoType then return false end

	-- หากระสุนใน grid
	local totalFound = 0
	local ammoSlots = {}

	for i = 1, GRID_SIZE do
		local slot = inv.grid[i]
		if slot then
			local slotData = ItemDatabase.GetItem(slot.itemId)
			if slotData and slotData.AmmoType == ammoType and slotData.Type == "Ammo" then
				table.insert(ammoSlots, i)
				totalFound = totalFound + slot.quantity
			end
		end
	end

	if totalFound <= 0 then return false, "No ammo" end

	-- ใช้กระสุนจาก grid
	local toUse = math.min(needed, totalFound)
	local remaining = toUse

	for _, slotIdx in ipairs(ammoSlots) do
		if remaining <= 0 then break end
		local slot = inv.grid[slotIdx]
		local take = math.min(slot.quantity, remaining)
		slot.quantity = slot.quantity - take
		remaining = remaining - take

		if slot.quantity <= 0 then
			inv.grid[slotIdx] = nil
		end
	end

	equip.ammo = (equip.ammo or 0) + toUse

	syncInventory(player)
	return true, equip.ammo, itemData.ReloadTime
end

-- ดึง Inventory ของผู้เล่น (สำหรับ script อื่นใช้)
function InventoryManager_GetInventory(player)
	return inventories[player]
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  REMOTE EVENT HANDLERS
-- อออออออออออออออออออออออออออออออออออออออออออออออ

EquipItemEvent.OnServerEvent:Connect(function(player, gridSlot)
	if type(gridSlot) ~= "number" then return end
	InventoryManager_EquipItem(player, gridSlot)
end)

UnequipItemEvent.OnServerEvent:Connect(function(player, equipSlotName)
	if type(equipSlotName) ~= "string" then return end
	InventoryManager_UnequipItem(player, equipSlotName)
end)

DropItemEvent.OnServerEvent:Connect(function(player, gridSlot)
	if type(gridSlot) ~= "number" then return end

	local inv = inventories[player]
	if not inv then return end

	local slot = inv.grid[gridSlot]
	if not slot then return end

	-- ลบจาก inventory
	local droppedItemId  = slot.itemId
	local droppedQty     = slot.quantity or 1
	local droppedAmmo    = slot.ammo or 0
	inv.grid[gridSlot] = nil

	-- สร้าง pickup Part ที่ตำแหน่งผู้เล่น
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- ส่ง event ไป ItemSpawner เพื่อสร้าง pickup
			SpawnDroppedItem:Fire(
				droppedItemId,
				rootPart.Position + rootPart.CFrame.LookVector * 5,
				droppedQty,
				droppedAmmo
			)
		end
	end

	syncInventory(player)
end)

SwapSlotsEvent.OnServerEvent:Connect(function(player, fromSlot, toSlot)
	if type(fromSlot) ~= "number" or type(toSlot) ~= "number" then return end

	local inv = inventories[player]
	if not inv then return end

	if fromSlot < 1 or fromSlot > GRID_SIZE then return end
	if toSlot < 1 or toSlot > GRID_SIZE then return end

	-- สลับ slot
	local temp = inv.grid[fromSlot]
	inv.grid[fromSlot] = inv.grid[toSlot]
	inv.grid[toSlot] = temp

	syncInventory(player)
end)

SwitchWeaponEvent.OnServerEvent:Connect(function(player, slotName)
	if type(slotName) ~= "string" then return end
	InventoryManager_SwitchWeapon(player, slotName)
end)

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  DEATH DROP — ตายแล้วของกระจายกลางแมพ
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function dropAllOnDeath(player, deathPos)
	local inv = inventories[player]
	if not inv then return end

	local loot = {}
	for i = 1, GRID_SIZE do
		local s = inv.grid[i]
		if s then
			table.insert(loot, { itemId = s.itemId, quantity = s.quantity or 1, ammo = s.ammo or 0 })
		end
	end
	for _, eq in pairs(inv.equipment) do
		if eq then
			table.insert(loot, { itemId = eq.itemId, quantity = 1, ammo = eq.ammo or 0 })
		end
	end

	local total = #loot
	for i, entry in ipairs(loot) do
		local angle  = (i / math.max(total, 1)) * math.pi * 2
		local radius = 3 + (i % 3)
		local offset = Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)
		SpawnDroppedItem:Fire(entry.itemId, deathPos + offset, entry.quantity, entry.ammo)
	end

	-- ล้าง inventory
	inventories[player] = createInventory()
	syncInventory(player)
	EquipUpdateEvent:FireClient(player, nil, nil)
end

local function hookCharacter(player, character)
	character:SetAttribute("Team", "Player")
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then return end

	hum.Died:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		local pos  = root and root.Position or Vector3.new(0, 10, 0)
		dropAllOnDeath(player, pos)
	end)
end

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  PLAYER JOIN / LEAVE
-- อออออออออออออออออออออออออออออออออออออออออออออออ
local function onPlayerAdded(player)
	inventories[player] = createInventory()

	player.CharacterAdded:Connect(function(char)
		hookCharacter(player, char)
	end)
	if player.Character then
		hookCharacter(player, player.Character)
	end

	-- ?? ของเริ่มต้น (debug) — ลบออกตอน production
	task.defer(function()
		InventoryManager_AddItem(player, "pistol", 1, 7)
		InventoryManager_AddItem(player, "knife", 1)
		InventoryManager_AddItem(player, "ammo_pistol", 30)
		InventoryManager_AddItem(player, "bandage", 3)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)   -- กันผู้เล่นที่ join ก่อน script โหลดเสร็จ
end

Players.PlayerRemoving:Connect(function(player)
	inventories[player] = nil
end)

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  MAKE FUNCTIONS GLOBAL (ให้ Script อื่นเรียกได้)
-- อออออออออออออออออออออออออออออออออออออออออออออออ

-- ใช้ _G สำหรับ cross-script communication
_G.InventoryManager = {
	AddItem        = InventoryManager_AddItem,
	RemoveFromSlot = InventoryManager_RemoveFromSlot,
	EquipItem      = InventoryManager_EquipItem,
	UnequipItem    = InventoryManager_UnequipItem,
	SwitchWeapon   = InventoryManager_SwitchWeapon,
	GetActiveWeapon = InventoryManager_GetActiveWeapon,
	UseAmmo        = InventoryManager_UseAmmo,
	Reload         = InventoryManager_Reload,
	GetInventory   = InventoryManager_GetInventory,
	SyncInventory  = syncInventory,
}

print("[InventoryManager] Ready")