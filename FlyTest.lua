-- LocalScript named "FlyTest"  (same script as Step 1: replace its whole content with this)
-- Put it in: StarterPlayer > StarterPlayerScripts
-- STEP 5: BIRD FLIGHT. Every SPACE press (or FLAP button on mobile) = one flap.
-- A flap throws you up (and a bit forward), then you glide back down.
-- Flight energy = number of flaps. Each light orb gives you some flaps.
-- While in the air, steer with W A S D / thumbstick (relative to the camera).
-- Skills: keys 1 / 2 on PC (aims at the mouse), tap the buttons on mobile (aims at screen center).
-- Collect the orange orb for Fire and the blue orb for Thunder to unlock them.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===== BIRD FLIGHT SETTINGS (tweak these!) =====
local FLAPS_PER_ORB = 3      -- flaps you get from one light orb
local MAX_FLAPS = 12         -- the most flaps you can store
local START_FLAPS = 0        -- start with none: collect light orbs first
local FLAP_POWER = 70        -- how hard a flap throws you up (higher = jumps higher)
local FLAP_FORWARD = 18      -- extra push forward (camera direction) on each flap
local FLAP_COOLDOWN = 0.35   -- seconds between flaps
local FLAP_DURATION = 0.5    -- how long one wing beat animation takes
local AIR_SPEED = 40         -- sideways speed in the air when you hold W A S D
local MAX_FALL_SPEED = 28    -- falling speed limit while gliding (lower = floatier)
local isTouch = UserInputService.TouchEnabled
local flaps = START_FLAPS

local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))
local CastSkill = ReplicatedStorage:WaitForChild("CastSkill", 10)
local cooldownEnd = {}

-- ===== on-screen status + button =====
local gui = Instance.new("ScreenGui")
gui.Name = "FlyTestGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local status = Instance.new("TextLabel")
status.Size = UDim2.new(0, 520, 0, 40)
status.Position = UDim2.new(0.5, -260, 0, 60)
status.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
status.BackgroundTransparency = 0.3
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.GothamBold
status.TextSize = 18
status.Text = "Collect light orbs to get flaps!"
status.Parent = gui

local flyButton = Instance.new("TextButton")
flyButton.Size = UDim2.new(0, 100, 0, 100)
flyButton.AnchorPoint = Vector2.new(1, 1)
flyButton.Position = UDim2.new(1, -30, 1, -200)
flyButton.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
flyButton.TextColor3 = Color3.new(0, 0, 0)
flyButton.Font = Enum.Font.GothamBold
flyButton.TextSize = 26
flyButton.Text = "FLAP"
flyButton.Visible = isTouch -- the button is only for mobile; PC uses SPACE
flyButton.Parent = gui

-- energy bar
local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0)
barBack.Position = UDim2.new(0.5, 0, 0, 110)
barBack.Size = UDim2.new(0, 300, 0, 22)
barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
barBack.Parent = gui
Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 11)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 225, 90)
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 11)

local barText = Instance.new("TextLabel")
barText.Size = UDim2.fromScale(1, 1)
barText.BackgroundTransparency = 1
barText.Text = "FLAPS: 0"
barText.TextColor3 = Color3.new(1, 1, 1)
barText.Font = Enum.Font.GothamBold
barText.TextSize = 13
barText.Parent = barBack

-- skill bar
local skillBar = Instance.new("Frame")
skillBar.AnchorPoint = Vector2.new(0.5, 1)
skillBar.Position = UDim2.new(0.5, 0, 1, -20)
skillBar.Size = UDim2.new(0, #SkillConfig.Order * 80, 0, 70)
skillBar.BackgroundTransparency = 1
skillBar.Parent = gui

local skillLayout = Instance.new("UIListLayout")
skillLayout.FillDirection = Enum.FillDirection.Horizontal
skillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillLayout.Padding = UDim.new(0, 10)
skillLayout.Parent = skillBar

local skillButtons = {}
for _, name in ipairs(SkillConfig.Order) do
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 70, 0, 70)
	button.Text = ""
	button.TextSize = 26
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.Parent = skillBar
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)

	if not isTouch then
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Position = UDim2.new(0, 4, 0, 2)
		keyLabel.Size = UDim2.new(0, 20, 0, 16)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = SkillConfig.Skills[name].KeyLabel
		keyLabel.TextColor3 = Color3.new(1, 1, 1)
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 14
		keyLabel.Parent = button
	end
	skillButtons[name] = button
end

-- ===== movement input (keyboard + mobile thumbstick) =====
local controls
pcall(function()
	local playerScripts = player:WaitForChild("PlayerScripts", 5)
	local module = playerScripts and playerScripts:WaitForChild("PlayerModule", 5)
	if module then
		controls = require(module):GetControls()
	end
end)

local function getMoveInput()
	if controls then
		local v = controls:GetMoveVector()
		return -v.Z, v.X
	end
	-- fallback: plain keyboard
	local forward, right = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then forward += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then forward -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then right += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then right -= 1 end
	return forward, right
end

-- ===== flying state =====
local flapT = 99          -- seconds since the last flap (big number = no flap animation)
local lastFlapTime = 0
local inFlight = false    -- true from the first flap until you touch the ground
local grounded = true

local function getParts()
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid, root
end

-- ===== CAPE =====
local CAPE_ONLY_WITH_ENERGY = true  -- true: cape disappears when you have no flaps left and are on the ground

local CAPE_RED = Color3.fromRGB(222, 32, 16)
local CAPE_HEM = Color3.fromRGB(245, 178, 158)
local CAPE_COLLAR = Color3.fromRGB(165, 215, 240)

local CAPE_SEGMENTS = {
	{ width = 1.7, height = 1.4, color = CAPE_RED },
	{ width = 2.0, height = 1.4, color = CAPE_RED },
	{ width = 2.3, height = 0.8, color = CAPE_HEM },
}

local capeFolder = nil
local capeChains = {}
local capeTime = 0
local hasCape = false

local function newCapePart(size, color)
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = capeFolder
	return part
end

local function newWeld(part0, part1, c0, c1)
	local weld = Instance.new("Weld")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = c0
	weld.C1 = c1 or CFrame.new()
	weld.Parent = part1
	return weld
end

local function destroyCape()
	if capeFolder then
		capeFolder:Destroy()
		capeFolder = nil
	end
	capeChains = {}
end

local function buildCape()
	if capeFolder then return end
	local character = player.Character
	if not character then return end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return end

	capeFolder = Instance.new("Folder")
	capeFolder.Name = "Cape"
	capeFolder.Parent = character
	capeChains = {}

	-- light blue collar
	local collar = newCapePart(Vector3.new(1.6, 0.35, 1.1), CAPE_COLLAR)
	newWeld(torso, collar, CFrame.new(0, torso.Size.Y / 2, 0.1))

	local hingeY = torso.Size.Y / 2 - 0.1
	local hingeZ = torso.Size.Z / 2 + 0.1

	-- two halves (left and right), each a chain of 3 hinged pieces
	for _, dir in ipairs({ -1, 1 }) do
		local chain = { dir = dir, joints = {} }
		local parentPart = torso
		local parentSeg = nil
		for _, seg in ipairs(CAPE_SEGMENTS) do
			local part = newCapePart(Vector3.new(seg.width, seg.height, 0.15), seg.color)
			local baseC0
			if parentSeg then
				baseC0 = CFrame.new(-dir * parentSeg.width / 2, -parentSeg.height / 2, 0.04)
			else
				baseC0 = CFrame.new(0, hingeY, hingeZ)
			end
			local c1 = CFrame.new(-dir * seg.width / 2, seg.height / 2, 0)
			local weld = newWeld(parentPart, part, baseC0, c1)
			table.insert(chain.joints, { weld = weld, base = baseC0 })
			parentPart = part
			parentSeg = seg
		end
		table.insert(capeChains, chain)
	end
end

local function updateCape(dt, glideLevel, speedFrac)
	if not capeFolder then return end
	capeTime += dt

	for _, chain in ipairs(capeChains) do
		for i, joint in ipairs(chain.joints) do
			-- one wing beat: wings snap up, then come back down (lower pieces lag = ripple)
			local p = (flapT - (i - 1) * 0.07) / FLAP_DURATION
			local beat = 0
			if p >= 0 and p <= 1 then
				beat = math.sin(p * math.pi)
			end
			local sway = math.sin(capeTime * 2 + i) * 0.03 -- tiny idle movement
			local open = math.max(glideLevel + sway, beat) -- 0 = hanging, 1 = fully spread

			local rollDeg
			if i == 1 then
				rollDeg = 5 + open * 42
			else
				rollDeg = 2 + open * 10
			end
			local pitchDeg = 3 + 6 * speedFrac + open * 6
			joint.weld.C0 = joint.base * CFrame.Angles(-math.rad(pitchDeg), 0, math.rad(rollDeg) * chain.dir)
		end
	end
end

local function flatten(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then return Vector3.zero end
	return f.Unit
end

local function doFlap()
	if os.clock() - lastFlapTime < FLAP_COOLDOWN then return end
	local humanoid, root = getParts()
	if not humanoid or not root or humanoid.Health <= 0 then return end
	if flaps < 1 then
		status.Text = "No flaps left! Collect light orbs."
		return
	end

	flaps -= 1
	lastFlapTime = os.clock()
	flapT = 0
	inFlight = true
	grounded = false

	-- throw the character up, and a bit forward where the camera looks
	local push = flatten(camera.CFrame.LookVector) * FLAP_FORWARD
	local v = root.AssemblyLinearVelocity
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = Vector3.new(v.X + push.X, FLAP_POWER, v.Z + push.Z)

	status.Text = "Flap! " .. flaps .. " flaps left"
end

RunService.RenderStepped:Connect(function(dt)
	-- flap counter bar
	barFill.Size = UDim2.new(math.clamp(flaps / MAX_FLAPS, 0, 1), 0, 1, 0)
	barText.Text = "FLAPS: " .. flaps

	-- skill buttons: locked / cooldown / ready
	for _, name in ipairs(SkillConfig.Order) do
		local button = skillButtons[name]
		local cfg = SkillConfig.Skills[name]
		local remaining = (cooldownEnd[name] or 0) - os.clock()
		if not player:GetAttribute("Skill_" .. name) then
			button.Text = "🔒"
			button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		elseif remaining > 0 then
			button.Text = string.format("%.1f", remaining)
			button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		else
			button.Text = cfg.Icon
			button.BackgroundColor3 = cfg.Color
		end
	end

	flapT += dt

	local humanoid, root = getParts()
	grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air

	-- landed?
	if inFlight and grounded and flapT > 0.3 then
		inFlight = false
		if flaps > 0 then
			status.Text = "Landed. Press SPACE to flap again!"
		else
			status.Text = "Landed. Collect light orbs to get more flaps."
		end
	end

	local airborneFlight = inFlight and not grounded
	local horizontalSpeed = 0

	-- steering + gliding while in the air
	if airborneFlight and humanoid and root and humanoid.Health > 0 then
		local forward, right = getMoveInput()
		local camCF = camera.CFrame
		local wanted = flatten(camCF.LookVector) * forward + flatten(camCF.RightVector) * right
		if wanted.Magnitude > 1 then
			wanted = wanted.Unit
		end

		local v = root.AssemblyLinearVelocity
		local horiz = Vector3.new(v.X, 0, v.Z)
		local rate = 0.8 -- slow drag when no keys are held (keeps gliding forward)
		if wanted.Magnitude > 0.1 then
			rate = 4
		end
		horiz = horiz:Lerp(wanted * AIR_SPEED, math.clamp(dt * rate, 0, 1))
		horizontalSpeed = horiz.Magnitude

		local vy = math.max(v.Y, -MAX_FALL_SPEED) -- glide: limit falling speed
		root.AssemblyLinearVelocity = Vector3.new(horiz.X, vy, horiz.Z)
	end

	-- cape: appears when you have flaps (or are still in the air), flaps with you
	if flaps > 0 or inFlight or (not CAPE_ONLY_WITH_ENERGY and hasCape) then
		buildCape()
	else
		destroyCape()
	end
	local glideLevel = airborneFlight and 0.5 or 0.08
	updateCape(dt, glideLevel, math.clamp(horizontalSpeed / AIR_SPEED, 0, 1))
end)

-- ===== inputs =====
flyButton.Activated:Connect(doFlap)

ContextActionService:BindActionAtPriority("BirdFlap", function(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if flaps >= 1 or inFlight then
		doFlap()
		return Enum.ContextActionResult.Sink -- no normal jump while you can flap
	end
	return Enum.ContextActionResult.Pass -- no flaps: SPACE is a normal jump
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)

player.CharacterAdded:Connect(function()
	inFlight = false
	flapT = 99
	capeFolder = nil
	capeChains = {}
end)

-- ===== SKILLS =====
local function getAimPosition()
	local screenPoint
	if isTouch then
		screenPoint = camera.ViewportSize / 2 -- center of the screen
	else
		screenPoint = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * 200
end

local function cast(name)
	if not CastSkill then
		status.Text = "Skill system not found (GameServer?)"
		return
	end
	if not player:GetAttribute("Skill_" .. name) then
		status.Text = name .. " is locked. Find its orb!"
		return
	end
	if os.clock() < (cooldownEnd[name] or 0) then return end
	local humanoid = getParts()
	if not humanoid or humanoid.Health <= 0 then return end

	cooldownEnd[name] = os.clock() + SkillConfig.Skills[name].Cooldown
	CastSkill:FireServer(name, getAimPosition())
end

for name, button in pairs(skillButtons) do
	button.Activated:Connect(function()
		cast(name)
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	for _, name in ipairs(SkillConfig.Order) do
		if input.KeyCode == SkillConfig.Skills[name].Key then
			cast(name)
		end
	end
end)

-- ===== ORB PICKUPS (messages from GameServer) =====
task.spawn(function()
	local orbEvent = ReplicatedStorage:WaitForChild("OrbCollected", 10)
	if not orbEvent then
		status.Text = "GameServer script not found! (no orbs will work)"
		return
	end
	orbEvent.OnClientEvent:Connect(function(kind, amount)
		if kind == "Light" then
			flaps = math.min(MAX_FLAPS, flaps + FLAPS_PER_ORB)
			hasCape = true
			if isTouch then
				status.Text = "+" .. FLAPS_PER_ORB .. " flaps! Cape equipped. Tap FLAP to fly."
			else
				status.Text = "+" .. FLAPS_PER_ORB .. " flaps! Cape equipped. Press SPACE to flap."
			end
		else
			local cfg = SkillConfig.Skills[kind]
			if cfg then
				local hint = isTouch and "tap its button" or ("press " .. cfg.KeyLabel)
				status.Text = kind .. " power unlocked! " .. hint
			end
		end
	end)
end)