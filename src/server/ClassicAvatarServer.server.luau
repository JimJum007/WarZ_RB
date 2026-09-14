--------------------------------------------------------------
-- ClassicAvatarServer.luau  (Script — ServerScriptService)
--
-- 🔄 R15 MODE — ไม่ swap ตัวละครแล้ว ใช้ R15 ของ Roblox ตรงๆ
--
-- หน้าที่:
--   1. ถอด Animate script ของ Roblox ออก (AnimationController คุมเอง)
--   2. ตั้งค่า Humanoid + attribute ให้สคริปต์อื่นเช็ค
--      (เสื้อผ้า/hitbox มาจาก AvatarStandardizer + LoadCharacterWithHumanoidDescription)
--
-- ⚠️ ต้องตั้ง Game Settings → Avatar → Avatar Type = R15
--    และ Animation = Standard ไม่งั้นจะ warn เตือน
--------------------------------------------------------------

local Players = game:GetService("Players")

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local STRIP_ANIMATE = true   -- false = ใช้ Animate ของ Roblox (ทางลัดฉุกเฉิน)

local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50

-- ═══════════════════════════════════════════════
--  ถอด Animate script ของ Roblox
--  ⚠️ ห้าม Stop แทร็กใน Animator — จะไปฆ่าของ AnimationController ด้วย
--     (race condition: client เริ่มเล่นแล้ว server มาหยุดทับ)
-- ═══════════════════════════════════════════════
local function stripDefaultAnimate(character)
	local existing = character:FindFirstChild("Animate")
	if existing then
		existing:Destroy()
		return
	end

	-- ยังไม่มา → ดักรอ แล้วเก็บกวาดเมื่อมันโผล่
	local conn
	conn = character.ChildAdded:Connect(function(child)
		if child.Name == "Animate" then
			child:Destroy()
			if conn.Connected then conn:Disconnect() end
		end
	end)

	task.delay(6, function()
		if conn and conn.Connected then conn:Disconnect() end
	end)
end

-- ═══════════════════════════════════════════════
--  ตั้งค่า Humanoid
-- ═══════════════════════════════════════════════
local function configureHumanoid(humanoid)
	if not humanoid:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	humanoid.AutoRotate           = true
	humanoid.UseJumpPower         = true
	humanoid.WalkSpeed            = DEFAULT_WALKSPEED
	humanoid.JumpPower            = DEFAULT_JUMPPOWER
	humanoid.PlatformStand        = false
	humanoid.BreakJointsOnDeath   = false   -- ตายแล้วไม่หลุดเป็นชิ้นๆ

	-- ปิด Physics state (กันตัวละครกลิ้งแปลกๆ ตอนโดนชน)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
end

-- ═══════════════════════════════════════════════
--  ตรวจ rig — เตือนถ้ายังเป็น R6
-- ═══════════════════════════════════════════════
local warnedOnce = false

local function verifyRig(character, humanoid)
	local isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)
		and character:FindFirstChild("UpperTorso") ~= nil

	if not isR15 and not warnedOnce then
		warnedOnce = true
		warn("╔══════════════════════════════════════════════╗")
		warn("║  ⚠️  ตัวละครไม่ใช่ R15!                       ║")
		warn("║  อนิเมชันจะไม่เล่นเลย (โหลดผ่านแต่เงียบ)      ║")
		warn("║                                              ║")
		warn("║  แก้: Home → Game Settings → Avatar          ║")
		warn("║       Avatar Type = R15                      ║")
		warn("║       Animation   = Standard                 ║")
		warn("║  แล้วปิด-เปิด Studio ใหม่                     ║")
		warn("╚══════════════════════════════════════════════╝")
	end

	return isR15
end

-- ═══════════════════════════════════════════════
--  SETUP หลัก
-- ═══════════════════════════════════════════════
local setupDone = {}   -- [character] = true  กันทำซ้ำ

local function setupCharacter(player, character)
	if not character or not character.Parent then return end
	if setupDone[character] then return end
	setupDone[character] = true

	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10)
	if not humanoid then
		warn("[Avatar] ❌ ไม่พบ Humanoid ของ " .. player.Name)
		return
	end

	character:WaitForChild("HumanoidRootPart", 10)

	local isR15 = verifyRig(character, humanoid)

	configureHumanoid(humanoid)

	if STRIP_ANIMATE then
		stripDefaultAnimate(character)
		task.wait(0.15)   -- ให้ Animate ตายสนิทก่อนปล่อยสัญญาณ
	end

	-- ⚠️ ลำดับสำคัญ — ClassicAvatar ต้องตั้ง "ท้ายสุด"
	--    เพราะ client ใช้ attribute นี้เป็นสัญญาณว่า "ตัวละครพร้อมแล้ว"
	character:SetAttribute("HitboxStandard", isR15 and "R15" or "R6")
	local teamName = player:GetAttribute("Team")
	if typeof(teamName) ~= "string" or teamName == "" then
		teamName = "Player"
	end
	character:SetAttribute("Team", teamName)
	player:SetAttribute("Team", teamName)
	character:SetAttribute("ClassicAvatar", true)

	print(string.format("[Avatar] %s ready for %s",
		isR15 and "R15" or "⚠️ R6", player.Name))
end

-- ═══════════════════════════════════════════════
--  HOOKS
-- ═══════════════════════════════════════════════
local function hookPlayer(player)
	-- CharacterAppearanceLoaded = เสื้อผ้า/accessory มาครบแล้ว
	player.CharacterAppearanceLoaded:Connect(function(character)
		task.defer(setupCharacter, player, character)
	end)

	-- สำรอง: บางเคส appearance ไม่ fire (offline / asset ล่ม)
	player.CharacterAdded:Connect(function(character)
		task.delay(1.5, function()
			if character.Parent and not setupDone[character] then
				setupCharacter(player, character)
			end
		end)
	end)

	if player.Character then
		task.defer(setupCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	local char = player.Character
	if char then setupDone[char] = nil end
end)

print("[ClassicAvatarServer] Ready — R15 mode" ..
	(STRIP_ANIMATE and " (Animate stripped)" or " (Animate kept)"))