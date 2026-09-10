--------------------------------------------------------------
-- ItemDatabase.lua  (ModuleScript)
-- วางใน: ReplicatedStorage
--
-- ข้อมูลไอเทมทั้งหมด — ทั้ง Client และ Server อ่านได้
-- ใช้เป็น source of truth สำหรับระบบ Inventory + Weapon
--------------------------------------------------------------

local ItemDatabase = {}

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  ITEM TYPES
-- อออออออออออออออออออออออออออออออออออออออออออออออ
-- Type:    "Weapon", "Ammo", "Armor", "Headgear", "Consumable"
-- Slot:    "Primary", "Secondary", "Armor", "Headgear", "Inventory"
-- Subtype: "Rifle", "Shotgun", "Pistol", "Melee" (สำหรับ Weapon)
-- Rarity:  "Common", "Uncommon", "Rare", "Epic", "Legendary"

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  RARITY COLORS (สำหรับ UI)
-- อออออออออออออออออออออออออออออออออออออออออออออออ
ItemDatabase.RarityColors = {
	Common    = Color3.fromRGB(180, 180, 180),  -- เทา
	Uncommon  = Color3.fromRGB(80, 200, 80),    -- เขียว
	Rare      = Color3.fromRGB(60, 130, 255),   -- น้ำเงิน
	Epic      = Color3.fromRGB(180, 60, 255),   -- ม่วง
	Legendary = Color3.fromRGB(255, 180, 30),   -- ทอง
}

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  ITEMS
-- อออออออออออออออออออออออออออออออออออออออออออออออ
ItemDatabase.Items = {

	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	--  WEAPONS — Primary
	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	rifle = {
		Name        = "M4A1",
		Type        = "Weapon",
		Slot        = "Primary",
		Subtype     = "Rifle",
		Damage      = 25,
		FireRate    = 0.1,           -- วินาทีต่อนัด (ยิ่งน้อย ยิ่งเร็ว)
		Automatic = true,
		MagazineSize = 30,
		ReloadTime  = 2.5,           -- วินาที
		ProjectileSpeed = 500,       -- studs/วินาที
		Spread      = 1.5,           -- องศา (ยิ่งน้อย ยิ่งแม่น)
		AmmoType    = "Rifle",
		Icon        = "",            -- ใส่ rbxassetid:// ภายหลัง
		Description = "ปืนไรเฟิลอัตโนมัติ ยิงเร็ว แม่นยำ",
		Rarity      = "Rare",
	},

	shotgun = {
		Name        = "M870",
		Type        = "Weapon",
		Slot        = "Primary",
		Subtype     = "Shotgun",
		Damage      = 12,            -- damage ต่อ pellet
		Pellets     = 8,             -- จำนวน pellet ต่อนัด (รวม 12?8 = 96)
		FireRate    = 0.8,
		Automatic = false,
		MagazineSize = 5,
		ReloadTime  = 3.0,           -- reload ทีละนัด (slug by slug)
		ProjectileSpeed = 400,
		Spread      = 5,             -- กระจายกว้าง
		AmmoType    = "Shotgun",
		Icon        = "",
		Description = "ปืนลูกซองระยะใกล้ พลังทำลายสูง",
		Rarity      = "Uncommon",
	},
	
	ak = {
		Name        = "AK-47",
		Type        = "Weapon",
		Slot        = "Primary",
		Subtype     = "Rifle",
		Damage      = 32,
		FireRate    = 0.12,
		Automatic   = true,
		MagazineSize = 30,
		ReloadTime  = 2.8,
		ProjectileSpeed = 480,
		Spread      = 2.2,
		AmmoType    = "Rifle",
		SpawnWithAmmo = 0,
		Description = "ไรเฟิลจู่โจม แรงสูง รีคอยล์เยอะ",
		Rarity      = "Rare",
	},

	smg = {
		Name        = "MP5",
		Type        = "Weapon",
		Slot        = "Primary",
		Subtype     = "SMG",
		Damage      = 16,
		FireRate    = 0.07,
		Automatic   = true,
		MagazineSize = 30,
		ReloadTime  = 2.2,
		ProjectileSpeed = 400,
		Spread      = 2.5,
		AmmoType    = "Pistol",
		SpawnWithAmmo = 0,
		Description = "ปืนกลมือ ยิงเร็ว ใช้กระสุนปืนพก",
		Rarity      = "Uncommon",
	},

	sniper = {
		Name        = "M107",
		Type        = "Weapon",
		Slot        = "Primary",
		Subtype     = "Sniper",
		Damage      = 90,
		FireRate    = 1.4,
		Automatic   = false,
		MagazineSize = 10,
		ReloadTime  = 4.0,
		ProjectileSpeed = 900,
		Spread      = 0.2,
		AmmoType    = "Sniper",
		SpawnWithAmmo = 0,
		Description = "ปืนซุ่มยิง .50 BMG ยิงนัดเดียวจบ",
		Rarity      = "Legendary",
	},

	lmg = {
		Name        = "M249",
		Type        = "Weapon",
		Slot        = "Primary",
		Subtype     = "LMG",
		Damage      = 22,
		FireRate    = 0.09,
		Automatic   = true,
		MagazineSize = 100,
		ReloadTime  = 6.0,
		ProjectileSpeed = 520,
		Spread      = 3.5,
		AmmoType    = "Rifle",
		SpawnWithAmmo = 0,
		Description = "ปืนกลเบา กระสุนเยอะ รีโหลดนาน",
		Rarity      = "Epic",
	},

	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	--  WEAPONS — Secondary
	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	pistol = {
		Name        = "M1911",
		Type        = "Weapon",
		Slot        = "Secondary",
		Subtype     = "Pistol",
		Damage      = 18,
		FireRate    = 0.25,
		Automatic = false,
		MagazineSize = 7,
		ReloadTime  = 1.5,
		ProjectileSpeed = 350,
		Spread      = 2,
		AmmoType    = "Pistol",
		Icon        = "",
		Description = "ปืนพกมาตรฐาน เชื่อถือได้",
		Rarity      = "Common",
	},

	knife = {
		Name        = "Combat Knife",
		Type        = "Weapon",
		Slot        = "Secondary",
		Subtype     = "Melee",
		Damage      = 40,
		AttackSpeed = 0.5,           -- วินาทีต่อครั้ง
		Range       = 7,             -- studs
		Icon        = "",
		Description = "มีดต่อสู้ระยะประชิด เงียบ รวดเร็ว",
		Rarity      = "Common",
	},

	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	--  AMMO
	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	ammo_pistol = {
		Name        = "Pistol Ammo",
		Type        = "Ammo",
		Slot        = "Inventory",
		AmmoType    = "Pistol",
		StackSize   = 30,            -- จำนวนสูงสุดต่อ slot
		Icon        = "",
		Description = "กระสุนปืนพก ?30",
		Rarity      = "Common",
	},

	ammo_rifle = {
		Name        = "Rifle Ammo",
		Type        = "Ammo",
		Slot        = "Inventory",
		AmmoType    = "Rifle",
		StackSize   = 60,
		Icon        = "",
		Description = "กระสุนไรเฟิล ?60",
		Rarity      = "Common",
	},

	ammo_shotgun = {
		Name        = "Shotgun Shells",
		Type        = "Ammo",
		Slot        = "Inventory",
		AmmoType    = "Shotgun",
		StackSize   = 20,
		Icon        = "",
		Description = "กระสุนลูกซอง ?20",
		Rarity      = "Common",
	},

	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	--  ARMOR
	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	armor_light = {
		Name            = "Light Vest",
		Type            = "Armor",
		Slot            = "Armor",
		DamageReduction = 0.15,      -- ลด damage 15%
		Durability      = 100,       -- ความทนทาน (ลดทุกครั้งที่โดนยิง)
		Icon            = "",
		Description     = "เสื้อเกราะเบา ลดความเสียหาย 15%",
		Rarity          = "Common",
	},

	armor_heavy = {
		Name            = "Heavy Armor",
		Type            = "Armor",
		Slot            = "Armor",
		DamageReduction = 0.35,      -- ลด damage 35%
		Durability      = 200,
		Icon            = "",
		Description     = "เสื้อเกราะหนัก ลดความเสียหาย 35%",
		Rarity          = "Rare",
	},

	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	--  HEADGEAR
	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	helmet_basic = {
		Name            = "Basic Helmet",
		Type            = "Headgear",
		Slot            = "Headgear",
		HeadshotReduction = 0.3,     -- ลด headshot damage 30%
		Durability      = 50,
		Icon            = "",
		Description     = "หมวกกันกระสุนพื้นฐาน ลด headshot 30%",
		Rarity          = "Uncommon",
	},

	helmet_military = {
		Name            = "Military Helmet",
		Type            = "Headgear",
		Slot            = "Headgear",
		HeadshotReduction = 0.55,
		Durability      = 100,
		Icon            = "",
		Description     = "หมวกทหาร ลด headshot 55%",
		Rarity          = "Rare",
	},

	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	--  CONSUMABLES
	-- ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ
	medkit = {
		Name        = "Medkit",
		Type        = "Consumable",
		Slot        = "Inventory",
		HealAmount  = 50,
		UseTime     = 3,             -- วินาที (ต้องกดค้าง)
		StackSize   = 3,
		Icon        = "",
		Description = "ชุดปฐมพยาบาล ฟื้นฟู HP 50",
		Rarity      = "Uncommon",
	},

	bandage = {
		Name        = "Bandage",
		Type        = "Consumable",
		Slot        = "Inventory",
		HealAmount  = 20,
		UseTime     = 1.5,
		StackSize   = 5,
		Icon        = "",
		Description = "ผ้าพันแผล ฟื้นฟู HP 20",
		Rarity      = "Common",
	},

	energy_drink = {
		Name        = "Energy Drink",
		Type        = "Consumable",
		Slot        = "Inventory",
		SpeedBoost  = 1.3,           -- คูณ WalkSpeed
		BoostDuration = 15,          -- วินาที
		StackSize   = 3,
		Icon        = "",
		Description = "เครื่องดื่มชูกำลัง เพิ่มความเร็ว 30% นาน 15 วิ",
		Rarity      = "Uncommon",
	},

	ammo_sniper = {
		Name        = "Sniper Rounds",
		Type        = "Ammo",
		Slot        = "Inventory",
		AmmoType    = "Sniper",
		StackSize   = 15,
		Description = "กระสุน .50 BMG ?15",
		Rarity      = "Rare",
	},
}

-- อออออออออออออออออออออออออออออออออออออออออออออออ
--  HELPER FUNCTIONS
-- อออออออออออออออออออออออออออออออออออออออออออออออ

-- ดึงข้อมูลไอเทมจาก ID
function ItemDatabase.GetItem(itemId)
	return ItemDatabase.Items[itemId]
end

-- เช็คว่าเป็นอาวุธไหม
function ItemDatabase.IsWeapon(itemId)
	local item = ItemDatabase.Items[itemId]
	return item and item.Type == "Weapon"
end

-- เช็คว่าเป็นอาวุธปืนไหม (ไม่ใช่ Melee)
function ItemDatabase.IsGun(itemId)
	local item = ItemDatabase.Items[itemId]
	return item and item.Type == "Weapon" and item.Subtype ~= "Melee"
end

-- เช็คว่า stack ได้ไหม (มี StackSize)
function ItemDatabase.IsStackable(itemId)
	local item = ItemDatabase.Items[itemId]
	return item and item.StackSize and item.StackSize > 1
end

-- ดึงสีจาก Rarity
function ItemDatabase.GetRarityColor(rarity)
	return ItemDatabase.RarityColors[rarity] or ItemDatabase.RarityColors.Common
end

-- ดึง slot ที่ถูกต้องสำหรับ equipment
function ItemDatabase.GetEquipSlot(itemId)
	local item = ItemDatabase.Items[itemId]
	if not item then return nil end

	if item.Slot == "Primary" or item.Slot == "Secondary"
		or item.Slot == "Armor" or item.Slot == "Headgear" then
		return item.Slot
	end

	return nil  -- Inventory-only items ไม่ equip ได้
end

-- ดึง AmmoType ที่ปืนใช้
function ItemDatabase.GetAmmoType(itemId)
	local item = ItemDatabase.Items[itemId]
	return item and item.AmmoType or nil
end

-- ดึงรายการไอเทมทั้งหมดตาม Type
function ItemDatabase.GetItemsByType(itemType)
	local result = {}
	for id, item in pairs(ItemDatabase.Items) do
		if item.Type == itemType then
			result[id] = item
		end
	end
	return result
end

return ItemDatabase