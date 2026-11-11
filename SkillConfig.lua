-- ModuleScript named "SkillConfig"
-- Put it in: ReplicatedStorage
-- To add a new skill later (Water, Ice...), add its name to Order and a block to Skills.

local SkillConfig = {}

-- Order of the skill bar (left to right)
SkillConfig.Order = { "Fire", "Thunder" }

SkillConfig.Skills = {
	Fire = {
		Icon = "🔥",
		Key = Enum.KeyCode.One,
		KeyLabel = "1",
		Color = Color3.fromRGB(255, 110, 30),
		Cooldown = 1.2,  -- seconds
		Damage = 25,
		Speed = 90,      -- fireball speed (studs/sec)
		Radius = 8,      -- explosion radius
	},
	Thunder = {
		Icon = "⚡",
		Key = Enum.KeyCode.Two,
		KeyLabel = "2",
		Color = Color3.fromRGB(90, 170, 255),
		Cooldown = 4,
		Damage = 40,
		Radius = 12,     -- strike radius
		Range = 150,     -- max cast distance
	},
}

return SkillConfig