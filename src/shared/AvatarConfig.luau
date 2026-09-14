--------------------------------------------------------------
-- AvatarConfig.luau  (ModuleScript — ReplicatedStorage)
-- ค่ากลางสำหรับ HumanoidDescription — ปรับเสื้อ/กางเกง/สีผิว/หน้าได้ที่นี่
-- รองรับหลาย preset ตามทีม (attribute "Team" ของผู้เล่น)
--------------------------------------------------------------

export type PresetConfig = {
	ShirtId: number,
	PantsId: number,
	FaceId: number,
	HeadColor: Color3,
	TorsoColor: Color3,
	LeftArmColor: Color3,
	RightArmColor: Color3,
	LeftLegColor: Color3,
	RightLegColor: Color3,
}

local Presets: { [string]: PresetConfig } = {
	-- ทีมหลัก — ใช้ default ตอน Team = "Player" หรือไม่รู้จัก
	Survivor = {
		ShirtId = 144076760,
		PantsId = 144076358,
		FaceId = 0,
		HeadColor = Color3.fromRGB(234, 184, 146),
		TorsoColor = Color3.fromRGB(234, 184, 146),
		LeftArmColor = Color3.fromRGB(234, 184, 146),
		RightArmColor = Color3.fromRGB(234, 184, 146),
		LeftLegColor = Color3.fromRGB(234, 184, 146),
		RightLegColor = Color3.fromRGB(234, 184, 146),
	},
	Bandit = {
		ShirtId = 144076760,
		PantsId = 144076358,
		FaceId = 0,
		HeadColor = Color3.fromRGB(198, 152, 109),
		TorsoColor = Color3.fromRGB(198, 152, 109),
		LeftArmColor = Color3.fromRGB(198, 152, 109),
		RightArmColor = Color3.fromRGB(198, 152, 109),
		LeftLegColor = Color3.fromRGB(198, 152, 109),
		RightLegColor = Color3.fromRGB(198, 152, 109),
	},
}

-- แมปชื่อ Team จากเกม → ชื่อ preset
local TEAM_TO_PRESET: { [string]: string } = {
	Player = "Survivor",
	Survivor = "Survivor",
	Bandit = "Bandit",
}

local DEFAULT_PRESET = "Survivor"

local function applyHitboxStandard(desc: HumanoidDescription)
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	desc.HeightScale = 1
	desc.WidthScale = 1
	desc.DepthScale = 1
	desc.HeadScale = 1

	desc.HatAccessory = ""
	desc.HairAccessory = ""
	desc.FaceAccessory = ""
	desc.NeckAccessory = ""
	desc.ShouldersAccessory = ""
	desc.FrontAccessory = ""
	desc.BackAccessory = ""
	desc.WaistAccessory = ""

	desc.Head = 0
	desc.Torso = 0
	desc.LeftArm = 0
	desc.RightArm = 0
	desc.LeftLeg = 0
	desc.RightLeg = 0
	desc.GraphicTShirt = 0
end

local function buildFromPreset(presetName: string): HumanoidDescription
	local cfg = Presets[presetName] or Presets[DEFAULT_PRESET]
	local desc = Instance.new("HumanoidDescription")

	if cfg.ShirtId > 0 then
		desc.Shirt = cfg.ShirtId
	end
	if cfg.PantsId > 0 then
		desc.Pants = cfg.PantsId
	end
	if cfg.FaceId > 0 then
		desc.Face = cfg.FaceId
	end

	desc.HeadColor = cfg.HeadColor
	desc.TorsoColor = cfg.TorsoColor
	desc.LeftArmColor = cfg.LeftArmColor
	desc.RightArmColor = cfg.RightArmColor
	desc.LeftLegColor = cfg.LeftLegColor
	desc.RightLegColor = cfg.RightLegColor

	applyHitboxStandard(desc)
	return desc
end

local AvatarConfig = {}

function AvatarConfig.GetPresetNameForTeam(teamName: string?): string
	if typeof(teamName) == "string" and TEAM_TO_PRESET[teamName] then
		return TEAM_TO_PRESET[teamName]
	end
	if typeof(teamName) == "string" and Presets[teamName] then
		return teamName
	end
	return DEFAULT_PRESET
end

function AvatarConfig.GetPresetNameForPlayer(player: Player): string
	local teamAttr = player:GetAttribute("Team")
	if teamAttr == nil and player.Character then
		teamAttr = player.Character:GetAttribute("Team")
	end
	return AvatarConfig.GetPresetNameForTeam(typeof(teamAttr) == "string" and teamAttr or nil)
end

function AvatarConfig.BuildDescription(presetName: string?): HumanoidDescription
	local name = presetName or DEFAULT_PRESET
	if not Presets[name] then
		name = DEFAULT_PRESET
	end
	return buildFromPreset(name)
end

function AvatarConfig.BuildDescriptionForPlayer(player: Player): HumanoidDescription
	return buildFromPreset(AvatarConfig.GetPresetNameForPlayer(player))
end

function AvatarConfig.GetPresets()
	return Presets
end

return AvatarConfig
