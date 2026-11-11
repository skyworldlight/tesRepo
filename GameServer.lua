-- Script (normal Script, NOT LocalScript) named "GameServer"
-- Put it in: ServerScriptService
--
-- Does: creates remotes, builds a test arena (orbs + dummies) if you have none,
-- handles orb pickup, and runs the Fire / Thunder skills.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))

-- ===== SETTINGS =====
local PVP = false              -- true = skills can hurt other players
local LIGHT_ORB_ENERGY = 25    -- flight energy from one light orb (max is 100 on the client)
local ORB_RESPAWN_TIME = 10    -- seconds until a collected orb comes back

-- ===== REMOTES =====
local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local CastSkill = makeRemote("CastSkill")         -- client -> server
local OrbCollected = makeRemote("OrbCollected")   -- server -> client

-- ===== HELPERS =====
local function showDamage(part, amount)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 100, 0, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "-" .. amount
	label.TextColor3 = Color3.fromRGB(255, 70, 70)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 28
	label.Parent = gui
	gui.Parent = part

	TweenService:Create(gui, TweenInfo.new(0.8), { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

local function damageInRadius(position, radius, damage, caster)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster.Character }

	local alreadyHit = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not alreadyHit[humanoid] then
			local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
			if PVP or not isPlayer then
				alreadyHit[humanoid] = true
				humanoid:TakeDamage(damage)
				showDamage(model:FindFirstChild("HumanoidRootPart") or part, damage)
			end
		end
	end
end

-- ===== ORBS =====
local ORB_COLORS = {
	Light = Color3.fromRGB(255, 225, 80),
	Fire = Color3.fromRGB(255, 110, 30),
	Thunder = Color3.fromRGB(90, 170, 255),
}

local orbFolder = workspace:FindFirstChild("Orbs")
local floatingOrbs = {} -- light-figure models that float and spin

local function setupOrb(orb)
	local orbType = orb:GetAttribute("OrbType")
	if not orbType then return end

	local hitbox = orb
	if orb:IsA("Model") then
		hitbox = orb.PrimaryPart
		table.insert(floatingOrbs, { model = orb, base = orb:GetPivot(), phase = math.random() * 6.28 })
	elseif orb.Anchored then
		-- simple floating animation for ball orbs
		TweenService:Create(
			orb,
			TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = orb.Position + Vector3.new(0, 1.5, 0) }
		):Play()
	end
	if not hitbox then return end

	hitbox.Touched:Connect(function(hit)
		if orb:GetAttribute("Taken") then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		orb:SetAttribute("Taken", true)
		local parent = orb.Parent

		if orbType == "Light" then
			OrbCollected:FireClient(player, "Light", LIGHT_ORB_ENERGY)
		else
			player:SetAttribute("Skill_" .. orbType, true) -- unlocks the skill
			OrbCollected:FireClient(player, orbType, 0)
		end

		orb.Parent = nil -- hide it
		task.delay(ORB_RESPAWN_TIME, function()
			orb:SetAttribute("Taken", false)
			orb.Parent = parent
		end)
	end)
end

-- make the light figures float up and down and spin
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, info in ipairs(floatingOrbs) do
		if info.model.Parent then
			info.model:PivotTo(
				info.base
					* CFrame.new(0, math.sin(t * 2 + info.phase) * 0.8, 0)
					* CFrame.Angles(0, t * 1.2 + info.phase, 0)
			)
		end
	end
end)

if not orbFolder then
	-- No "Orbs" folder found: build a test arena automatically.
	orbFolder = Instance.new("Folder")
	orbFolder.Name = "Orbs"
	orbFolder.Parent = workspace

	-- The light orb: a glowing, see-through yellow Roblox-style character
	local function makeLightFigure(position)
		local model = Instance.new("Model")
		model.Name = "LightOrb"
		model:SetAttribute("OrbType", "Light")

		local scale = 1.2
		local function piece(name, size, localCF, shape)
			local part = Instance.new("Part")
			part.Name = name
			part.Size = size * scale
			if shape then part.Shape = shape end
			part.Material = Enum.Material.Neon
			part.Color = ORB_COLORS.Light
			part.Transparency = 0.45
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CFrame = CFrame.new(position) * (localCF + localCF.Position * (scale - 1))
			part.Parent = model
			return part
		end

		local torso = piece("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0))
		piece("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 1.7, 0), Enum.PartType.Ball)
		piece("LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.6, 0.2, 0) * CFrame.Angles(0, 0, math.rad(20)))
		piece("RightArm", Vector3.new(1, 2, 1), CFrame.new(1.6, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-20)))
		piece("LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0))
		piece("RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0))

		local light = Instance.new("PointLight")
		light.Color = ORB_COLORS.Light
		light.Range = 22
		light.Brightness = 3
		light.Parent = torso

		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = ORB_COLORS.Light
		sparkles.Parent = torso

		-- invisible box that detects the player touching it
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Size = Vector3.new(5, 8, 5)
		hitbox.CFrame = CFrame.new(position)
		hitbox.Transparency = 1
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.CanQuery = false
		hitbox.Parent = model
		model.PrimaryPart = hitbox

		model.Parent = orbFolder
	end

	local function makeOrb(position, orbType)
		if orbType == "Light" then
			makeLightFigure(position)
			return
		end

		local orb = Instance.new("Part")
		orb.Name = orbType .. "Orb"
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(3, 3, 3)
		orb.Material = Enum.Material.Neon
		orb.Color = ORB_COLORS[orbType]
		orb.Anchored = true
		orb.CanCollide = false
		orb.Position = position
		orb:SetAttribute("OrbType", orbType)

		local light = Instance.new("PointLight")
		light.Color = ORB_COLORS[orbType]
		light.Range = 16
		light.Brightness = 2
		light.Parent = orb

		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = ORB_COLORS[orbType]
		sparkles.Parent = orb

		orb.Parent = orbFolder
	end

	-- ring of light figures near the ground
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		makeOrb(Vector3.new(math.cos(angle) * 20, 7, math.sin(angle) * 20), "Light")
	end
	-- a few light figures up high (reward for flying)
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		makeOrb(Vector3.new(math.cos(angle) * 15, 45, math.sin(angle) * 15), "Light")
	end
	-- skill orbs
	makeOrb(Vector3.new(35, 6, 0), "Fire")
	makeOrb(Vector3.new(-35, 6, 0), "Thunder")
end

for _, orb in ipairs(orbFolder:GetChildren()) do
	setupOrb(orb)
end

-- ===== TRAINING DUMMIES =====
if not workspace:FindFirstChild("Dummies") then
	local dummyFolder = Instance.new("Folder")
	dummyFolder.Name = "Dummies"
	dummyFolder.Parent = workspace

	local function createDummy(position)
		local model = Instance.new("Model")
		model.Name = "Dummy"

		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(4, 6, 2)
		root.Color = Color3.fromRGB(200, 60, 60)
		root.Anchored = true
		root.Position = position
		root.Parent = model
		model.PrimaryPart = root

		local humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.Parent = model

		model.Parent = dummyFolder

		humanoid.Died:Connect(function()
			task.wait(0.3)
			model:Destroy()
			task.delay(4, function()
				createDummy(position)
			end)
		end)
	end

	createDummy(Vector3.new(0, 3, -60))
	createDummy(Vector3.new(25, 3, -60))
	createDummy(Vector3.new(-25, 3, -60))
end

-- ===== SKILLS =====
local function castFire(player, root, targetPos)
	local cfg = SkillConfig.Skills.Fire
	local character = player.Character

	local direction = targetPos - root.Position
	if direction.Magnitude < 1 then return end
	direction = direction.Unit

	local ball = Instance.new("Part")
	ball.Name = "Fireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.5, 2.5, 2.5)
	ball.Material = Enum.Material.Neon
	ball.Color = cfg.Color
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CFrame = CFrame.new(root.Position + direction * 4)

	local light = Instance.new("PointLight")
	light.Color = cfg.Color
	light.Range = 18
	light.Brightness = 3
	light.Parent = ball

	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 0
	fire.Parent = ball

	local attachment = Instance.new("Attachment")
	attachment.Parent = ball

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = direction * cfg.Speed
	velocity.Parent = ball

	ball.Parent = workspace
	ball:SetNetworkOwner(nil)
	Debris:AddItem(ball, 5)

	local exploded = false
	ball.Touched:Connect(function(hit)
		if exploded then return end
		if hit:IsDescendantOf(character) or not hit.CanCollide then return end
		exploded = true

		local explosion = Instance.new("Explosion")
		explosion.Position = ball.Position
		explosion.BlastRadius = cfg.Radius
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Parent = workspace

		damageInRadius(ball.Position, cfg.Radius, cfg.Damage, player)
		ball:Destroy()
	end)
end

local function castThunder(player, root, targetPos)
	local cfg = SkillConfig.Skills.Thunder

	-- keep the target within range
	local offset = targetPos - root.Position
	if offset.Magnitude > cfg.Range then
		targetPos = root.Position + offset.Unit * cfg.Range
	end

	-- snap to the ground below the target
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(targetPos + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), params)
	if result then
		targetPos = result.Position
	end

	-- warning circle on the ground
	local warning = Instance.new("Part")
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(0.3, cfg.Radius * 2, cfg.Radius * 2)
	warning.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	warning.Material = Enum.Material.Neon
	warning.Color = cfg.Color
	warning.Transparency = 0.5
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanQuery = false
	warning.CanTouch = false
	warning.Parent = workspace
	Debris:AddItem(warning, 0.6)

	task.delay(0.5, function()
		-- the lightning bolt
		local bolt = Instance.new("Part")
		bolt.Size = Vector3.new(3, 150, 3)
		bolt.CFrame = CFrame.new(targetPos + Vector3.new(0, 75, 0))
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(200, 230, 255)
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false

		local light = Instance.new("PointLight")
		light.Color = cfg.Color
		light.Range = 40
		light.Brightness = 10
		light.Parent = bolt

		bolt.Parent = workspace
		TweenService:Create(bolt, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		Debris:AddItem(bolt, 0.5)

		damageInRadius(targetPos, cfg.Radius, cfg.Damage, player)
	end)
end

local Casters = {
	Fire = castFire,
	Thunder = castThunder,
}

-- ===== CAST REQUESTS FROM CLIENTS =====
local cooldowns = {} -- [player] = { [skillName] = time when ready }

CastSkill.OnServerEvent:Connect(function(player, skillName, targetPos)
	-- never trust the client: validate everything
	if typeof(skillName) ~= "string" or typeof(targetPos) ~= "Vector3" then return end
	local cfg = SkillConfig.Skills[skillName]
	local caster = Casters[skillName]
	if not cfg or not caster then return end
	if not player:GetAttribute("Skill_" .. skillName) then return end -- not unlocked

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end

	cooldowns[player] = cooldowns[player] or {}
	local now = os.clock()
	if now < (cooldowns[player][skillName] or 0) then return end
	cooldowns[player][skillName] = now + cfg.Cooldown * 0.9 -- small tolerance for lag

	caster(player, root, targetPos)
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)