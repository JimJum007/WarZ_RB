--------------------------------------------------------------
-- AvatarStandardizer.luau  (ModuleScript — ServerScriptService)
-- สร้าง HumanoidDescription มาตรฐาน + เตือน Game Settings
-- ทำงานคู่ ClassicAvatarServer (strip Animate / Humanoid / ClassicAvatar flag)
--------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AvatarConfig = require(ReplicatedStorage:WaitForChild("AvatarConfig"))

local warnedSettings = false

local function warnGameSettingsOnce()
	if warnedSettings then
		return
	end
	warnedSettings = true

	warn("╔══════════════════════════════════════════════╗")
	warn("║  [AvatarStandardizer] ตรวจ Game Settings      ║")
	warn("║  Avatar → Avatar Type = R15                   ║")
	warn("║  Avatar → Collision   = Outer Box             ║")
	warn("╚══════════════════════════════════════════════╝")
end

local AvatarStandardizer = {}

function AvatarStandardizer.WarnGameSettings()
	warnGameSettingsOnce()
end

function AvatarStandardizer.GetHumanoidDescriptionForPlayer(player: Player): HumanoidDescription
	return AvatarConfig.BuildDescriptionForPlayer(player)
end

function AvatarStandardizer.GetPresetNameForPlayer(player: Player): string
	return AvatarConfig.GetPresetNameForPlayer(player)
end

-- เรียกครั้งเดียวเมื่อ server โหลด
warnGameSettingsOnce()

return AvatarStandardizer
