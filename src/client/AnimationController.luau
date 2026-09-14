-- AnimationController.luau  (LocalScript — StarterPlayerScripts)
-- R15 3-Layer System + Aim Offset (Waist/Neck)
--   Layer 1 Locomotion (Movement)  — ขา/การเคลื่อนที่
--   Layer 2 WeaponPose (Action)    — แขนถือปืน (ทับท่อนบน)
--   Layer 3 Action (Action2/3)     — ยิง/reload/equip
-------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local ContentProvider   = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local AnimDB             = require(ReplicatedStorage:WaitForChild("AnimationDatabase"))
local EquipUpdateEvent   = ReplicatedStorage:WaitForChild("EquipUpdate")
local StartGameplayEvent = ReplicatedStorage:WaitForChild("StartGameplay")

local FADE     = 0.18
local RUN_AT   = 20
local MOVE_EPS = 0.1
local VEL_EPS  = 1.25
local CLEAN_INTERVAL = 2.0

local humanoid, animator, character, rootPart, boundAnimator
local trackCache     = {}   -- [Animator] = { [animId] = track }
local ownedTracks    = setmetatable({}, { __mode = "k" })
local locoTrack, locoId, locoMotion, locoStance
local poseTrack, poseId
local actionTracks   = {}
local weaponSet
local stance         = "Stand"
local lastForceClean = 0

-- ═══════════════════════════════════════════════
--  ANIMATE STRIP + ANIMATOR CLEANUP
-- ═══════════════════════════════════════════════
local function stripAnimate(char)
	local existing = char:FindFirstChild("Animate")
	if existing then
		existing:Destroy()
	end

	local conn
	conn = char.ChildAdded:Connect(function(child)
		if child.Name == "Animate" then
			child:Destroy()
			if conn.Connected then conn:Disconnect() end
		end
	end)

	task.delay(8, function()
		if conn and conn.Connected then conn:Disconnect() end
	end)
end

local function isOwnedTrack(track)
	return track and ownedTracks[track] == true
end

local function registerTrack(track)
	if track then
		ownedTracks[track] = true
	end
end

local function getLayerFade(layerName)
	return AnimDB.GetLayerFadeTime(layerName)
end

-- หยุดแทร็กแปลกปลอมที่ไม่ใช่ของเรา (ACS, debug, Animate ค้าง)
local function forceCleanAnimator(anim, preserve)
	if not anim then return 0 end

	local keep = {}
	if preserve then
		for _, track in ipairs(preserve) do
			keep[track] = true
		end
	end

	local stopped = 0
	for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
		if not keep[track] and not isOwnedTrack(track) then
			track:Stop(0)
			stopped += 1
		end
	end
	return stopped
end

local function getAnimatorCache(anim)
	local cache = trackCache[anim]
	if not cache then
		cache = {}
		trackCache[anim] = cache
	end
	return cache
end

local function clearAnimatorState(anim)
	if anim and trackCache[anim] then
		trackCache[anim] = nil
	end
end

-- ═══════════════════════════════════════════════
--  TRACK HELPERS
-- ═══════════════════════════════════════════════
local function getTrack(id, layerName, loopedOverride)
	if not id or id == "" or not animator then return nil end

	local layer = AnimDB.GetLayer(layerName)
	local priority = layer and layer.Priority or Enum.AnimationPriority.Movement
	local looped = loopedOverride
	if looped == nil and layer then
		looped = layer.Looped
	end
	if looped == nil then
		looped = true
	end

	local cache = getAnimatorCache(animator)
	if cache[id] then
		local cached = cache[id]
		cached.Priority = priority
		return cached
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = id

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[Anim] โหลดไม่ได้:", id)
		return nil
	end

	track.Priority = priority
	track.Looped   = looped
	registerTrack(track)
	cache[id] = track
	return track
end

local function collectOwnedPlaying()
	local list = {}
	if locoTrack and locoTrack.IsPlaying then table.insert(list, locoTrack) end
	if poseTrack and poseTrack.IsPlaying then table.insert(list, poseTrack) end
	for _, t in pairs(actionTracks) do
		if t and t.IsPlaying then table.insert(list, t) end
	end
	return list
end

local function stopOwnedTracks()
	if locoTrack then locoTrack:Stop(0) end
	if poseTrack then poseTrack:Stop(0) end
	for _, t in pairs(actionTracks) do t:Stop(0) end
	locoTrack, locoId, locoMotion, locoStance = nil, nil, nil, nil
	poseTrack, poseId = nil, nil
	actionTracks = {}
end

local function maintainLocomotion(id, motion, speed, currentStance)
	if not id then return end

	local fade   = getLayerFade("Locomotion")
	local weight = AnimDB.GetLayerWeight("Locomotion")
	local stanceChanged = currentStance and currentStance ~= locoStance

	if id ~= locoId or stanceChanged then
		local track = getTrack(id, "Locomotion", true)
		if not track then return end

		forceCleanAnimator(animator, collectOwnedPlaying())

		if locoTrack and locoTrack ~= track then
			locoTrack:Stop(fade)
		end

		track.Looped = true
		track.Priority = AnimDB.GetLayerPriority("Locomotion")
		track:Play(fade, weight, speed or 1)
		locoTrack, locoId, locoMotion, locoStance = track, id, motion, currentStance
		return
	end

	if locoTrack then
		locoMotion = motion
		locoStance = currentStance
		locoTrack.Looped = true
		if speed then
			locoTrack:AdjustSpeed(speed)
		end
		if not locoTrack.IsPlaying then
			locoTrack.Priority = AnimDB.GetLayerPriority("Locomotion")
			locoTrack:Play(fade, weight, speed or 1)
		end
	end
end

local function setWeaponPose(setKey)
	if not AnimDB.IsLayerEnabled("WeaponPose") then
		if poseTrack then poseTrack:Stop(getLayerFade("WeaponPose")) end
		poseTrack, poseId = nil, nil
		return
	end

	local fade   = getLayerFade("WeaponPose")
	local weight = AnimDB.GetLayerWeight("WeaponPose")
	local id = setKey and AnimDB.GetWeaponAnim(setKey, "Pose") or nil

	if id == poseId then
		if poseTrack and not poseTrack.IsPlaying then
			poseTrack:Play(fade, weight, 1)
		end
		return
	end

	if poseTrack then poseTrack:Stop(fade) end
	poseTrack, poseId = nil, nil
	if not id then return end

	local track = getTrack(id, "WeaponPose", true)
	if not track then return end
	track.Looped = true
	track.Priority = AnimDB.GetLayerPriority("WeaponPose")
	track:Play(fade, weight, 1)
	poseTrack, poseId = track, id
end

local function playAction(name, speed)
	if not weaponSet then return nil end
	local id = AnimDB.GetWeaponAnim(weaponSet, name)
	if not id then return nil end

	local layerName = (name == "Reload") and "ActionHigh" or "Action"
	local fade = getLayerFade(layerName)
	local track = getTrack(id, layerName, false)
	if not track then return nil end

	if actionTracks[name] then actionTracks[name]:Stop(fade) end
	track.Looped = false
	track.Priority = AnimDB.GetLayerPriority(layerName)
	track:Play(fade, AnimDB.GetLayerWeight(layerName), speed or 1)
	actionTracks[name] = track

	track.Stopped:Once(function()
		if actionTracks[name] == track then actionTracks[name] = nil end
	end)
	return track
end

local function stopAction(name)
	local track = actionTracks[name]
	if track then
		track:Stop(getLayerFade("Action"))
		actionTracks[name] = nil
	end
end

-- ═══════════════════════════════════════════════
--  AIM OFFSET — คูณทับ Transform หลังอนิเมชัน (ไม่สะสมทุกเฟรม)
--  Local: pitch จากกล้องทันที | Remote: AimPitch จาก attribute
-- ═══════════════════════════════════════════════
local CFG   = AnimDB.AimOffset or { WaistRatio = 0.45, NeckRatio = 0.35, MaxAngle = math.rad(35), Smooth = 12 }
local rigs  = setmetatable({}, { __mode = "k" })
local smoothPitch = {}
local lastAimOnMotor = setmetatable({}, { __mode = "k" })

local function getRig(char)
	local cached = rigs[char]
	if cached and cached.waist and cached.waist.Parent then return cached end

	local upper = char:FindFirstChild("UpperTorso")
	local head  = char:FindFirstChild("Head")
	local waist = upper and upper:FindFirstChild("Waist")
	local neck  = head  and head:FindFirstChild("Neck")
	if not waist then return nil end

	local rig = { waist = waist, neck = neck }
	rigs[char] = rig
	return rig
end

local function resetAimOffset(char)
	smoothPitch[char] = 0
	local rig = rigs[char]
	if rig then
		lastAimOnMotor[rig.waist] = nil
		if rig.neck then lastAimOnMotor[rig.neck] = nil end
	end
end

-- pitch จากทิศกล้องเทียบ yaw ของตัวละคร (first person / scriptable camera)
local function pitchFromCameraLook(char)
	local cam = workspace.CurrentCamera
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not cam or not hrp then
		return _G.CameraPitch or 0
	end

	local _, yaw, _ = hrp.CFrame:ToOrientation()
	local look = cam.CFrame.LookVector
	local localLook = CFrame.Angles(0, yaw, 0):VectorToObjectSpace(look)
	if localLook.Magnitude < 1e-4 then
		return 0
	end
	localLook = localLook.Unit
	return math.atan2(-localLook.Y, -localLook.Z)
end

local function applyAimOffsetToMotor(motor: Motor6D, offset: CFrame)
	local prev = lastAimOnMotor[motor] or CFrame.new()
	motor.Transform = motor.Transform * prev:Inverse() * offset
	lastAimOnMotor[motor] = offset
end

local function applyAim(char, targetPitch, dt, instant: boolean?)
	local rig = getRig(char)
	if not rig then return end

	targetPitch = math.clamp(targetPitch or 0, -CFG.MaxAngle, CFG.MaxAngle)

	local cur = smoothPitch[char] or 0
	if instant then
		cur = targetPitch
	else
		local a = math.clamp(CFG.Smooth * dt, 0, 1)
		cur = cur + (targetPitch - cur) * a
	end
	smoothPitch[char] = cur

	local waistAim = CFrame.new()
	local neckAim = CFrame.new()
	if math.abs(cur) >= 0.001 then
		waistAim = CFrame.Angles(cur * CFG.WaistRatio, 0, 0)
		neckAim = CFrame.Angles(cur * CFG.NeckRatio, 0, 0)
	end

	applyAimOffsetToMotor(rig.waist, waistAim)
	if rig.neck then
		applyAimOffsetToMotor(rig.neck, neckAim)
	end
end

-- ═══════════════════════════════════════════════
--  MOVEMENT DETECTION
-- ═══════════════════════════════════════════════
local function isCharacterMoving(hum, hrp)
	if hum.MoveDirection.Magnitude > MOVE_EPS then
		return true
	end
	if hrp then
		local vel = hrp.AssemblyLinearVelocity
		local planar = Vector3.new(vel.X, 0, vel.Z).Magnitude
		return planar > VEL_EPS
	end
	return false
end

local function getCurrentStance()
	return player:GetAttribute("Stance") or stance or "Stand"
end

local function resolveLocomotion()
	local currentStance = getCurrentStance()
	stance = currentStance

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping then
		return AnimDB.Locomotion.Jump, "Jump", 1, currentStance
	elseif state == Enum.HumanoidStateType.Freefall then
		return AnimDB.Locomotion.Fall, "Fall", 1, currentStance
	end

	local moving = isCharacterMoving(humanoid, rootPart)
	local motion

	if currentStance == "Prone" then
		motion = moving and "Walk" or "Idle"
	elseif currentStance == "Crouch" then
		motion = (not moving) and "Idle" or "Walk"
	else
		motion = (not moving) and "Idle"
			or (humanoid.WalkSpeed >= RUN_AT and "Run" or "Walk")
	end

	local id = AnimDB.GetLocomotion(currentStance, motion)

	local speed = 1
	if motion == "Walk" or motion == "Run" then
		local base = (motion == "Run") and 24 or 14
		if currentStance == "Prone" then
			base = 6
		elseif currentStance == "Crouch" then
			base = 10
		end
		speed = math.clamp(humanoid.WalkSpeed / base, 0.4, 2)
	end

	return id, motion, speed, currentStance
end

-- ═══════════════════════════════════════════════
--  SETUP
-- ═══════════════════════════════════════════════
local function setup(char)
	if not char or not char.Parent then return end
	if char:GetAttribute("ClassicAvatar") ~= true then return end

	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum then return end

	local anim = hum:FindFirstChildOfClass("Animator")
	if not anim then
		anim = Instance.new("Animator")
		anim.Parent = hum
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")

	if character == char and boundAnimator == anim and locoTrack and locoTrack.IsPlaying then
		forceCleanAnimator(anim, collectOwnedPlaying())
		return
	end

	if boundAnimator and boundAnimator ~= anim then
		clearAnimatorState(boundAnimator)
	end

	stopOwnedTracks()
	stripAnimate(char)
	forceCleanAnimator(anim)

	character     = char
	humanoid      = hum
	animator      = anim
	rootPart      = hrp
	boundAnimator = anim
	rigs[char]    = nil
	resetAimOffset(char)
	lastForceClean = os.clock()
	stance = getCurrentStance()

	local idleId = AnimDB.GetLocomotion(stance, "Idle")
	if idleId then
		maintainLocomotion(idleId, "Idle", 1, stance)
	end

	setWeaponPose(weaponSet)
	print("[AnimationController] R15 animation bound")
end

local function watchCharacter(char)
	if not char then return end
	task.spawn(function()
		local deadline = os.clock() + 12
		while char.Parent and char:GetAttribute("ClassicAvatar") ~= true and os.clock() < deadline do
			task.wait(0.1)
		end
		if char.Parent and char:GetAttribute("ClassicAvatar") == true then setup(char) end
	end)
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(function(char)
	boundAnimator = nil
	rootPart = nil
	watchCharacter(char)
end)
StartGameplayEvent.OnClientEvent:Connect(function()
	if player.Character then task.defer(setup, player.Character) end
end)

task.spawn(function()
	while task.wait(0.25) do
		local char = player.Character
		if char and char ~= character and char:GetAttribute("ClassicAvatar") == true then
			setup(char)
		end
	end
end)

-- ═══════════════════════════════════════════════
--  HOOKS
-- ═══════════════════════════════════════════════
EquipUpdateEvent.OnClientEvent:Connect(function(_, itemId)
	local newSet = AnimDB.GetSetKey(itemId)
	if newSet == weaponSet then return end
	weaponSet = newSet
	setWeaponPose(weaponSet)
	playAction("Equip")
end)

local function onStanceChanged()
	local newStance = getCurrentStance()
	if newStance == stance and locoStance == newStance then return end
	stance = newStance
	locoId = nil -- บังคับสลับทันที

	if humanoid and animator and humanoid.Health > 0 then
		local id, motion, speed, st = resolveLocomotion()
		if id then
			maintainLocomotion(id, motion, speed, st)
		end
	end
end

player:GetAttributeChangedSignal("Stance"):Connect(onStanceChanged)

player:GetAttributeChangedSignal("Reloading"):Connect(function()
	if player:GetAttribute("Reloading") then playAction("Reload") else stopAction("Reload") end
end)

_G.PlayWeaponAction = function(name, speed)
	if name == "Fire" or name == "Attack" then name = "Shoot" end
	return playAction(name, speed)
end

-- ═══════════════════════════════════════════════
--  RENDER LOOP
-- ═══════════════════════════════════════════════
RunService:BindToRenderStep("WarZAnimation", Enum.RenderPriority.Character.Value + 1, function(dt)
	if humanoid and humanoid.Health > 0 and character and character.Parent and animator then
		local now = os.clock()
		if now - lastForceClean >= CLEAN_INTERVAL then
			local removed = forceCleanAnimator(animator, collectOwnedPlaying())
			if removed > 0 then
				warn("[Anim] Force-cleaned", removed, "foreign track(s)")
			end
			lastForceClean = now
		end

		local id, motion, speed, currentStance = resolveLocomotion()
		if id then
			maintainLocomotion(id, motion, speed, currentStance)
		end
	end

	-- Aim offset — local ใช้ pitch จากกล้องทันที, remote ใช้ AimPitch
	if character and weaponSet and AnimDB.IsLayerEnabled("WeaponPose") then
		local pitch = pitchFromCameraLook(character)
		applyAim(character, pitch, dt, true)
	end

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local oc = other.Character
			if oc and oc:GetAttribute("ClassicAvatar") then
				local pitch = oc:GetAttribute("AimPitch") or 0
				applyAim(oc, pitch, dt, false)
			end
		end
	end
end)

-- ═══════════════════════════════════════════════
--  PRELOAD
-- ═══════════════════════════════════════════════
task.spawn(function()
	local assets = {}
	for _, id in ipairs(AnimDB.GetAllIds()) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		table.insert(assets, a)
	end
	pcall(function() ContentProvider:PreloadAsync(assets) end)
	print("[Anim] Preloaded", #assets)
end)

print("[AnimationController] Ready (R15)")