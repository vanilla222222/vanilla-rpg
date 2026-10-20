-- Definitive values receive source modifiers; defined values are formula-only.
-- Chance stats use percentage points; modifier.percent uses fractions (0.1 = 10%).
local definitive = {}
local function add(id, base, maximum, unit, minimum)
    definitive[id] = {base = base, min = minimum or 0, max = maximum or 1000000000, unit = unit or "value"}
end
for _, activity in ipairs({"Combat", "Farming", "Fishing", "Mining", "Foraging"}) do
    add(activity .. "Fortune", 100, nil, "%") -- Effective chance, not the stat, caps at 500%.
    add(activity .. "Wisdom", 100, 500, "%")
end
add("Vitality", 100, nil, "health", 1)
add("HealthRegen", 5, nil, "/s")
add("Endurance", 100, nil, "stamina")
add("StaminaRegen", 5, nil, "/s")
add("Intelligence", 100, nil, "mana")
add("ManaRegen", 5, nil, "/s")
add("AbilityDamage", 100, nil, "%")
add("Defense", 0)
add("CritDamage", 125, nil, "%")
add("CritChance", 1, 100, "%")
add("Speed", 16, nil, "studs/s")
add("BreakingPower", 0, nil, "tier")
add("MiningSpeed", 0, nil, "damage/s")
add("MiningSpread", 100, 2500, "%")
add("Pristine", 0, 100, "%")
add("Sweep", 0, nil, "blocks")
add("AxeStrength", 0, nil, "tier")
add("MaxSize", 0)
add("MinSize", 0)
add("SeaCreatureChance", 0, 100, "%")
add("DoubleHookChance", 0, 100, "%")
add("TreasureChance", 0, 100, "%")
return {
    definitive = definitive,
    defined = {
        MaxHealth = {dependencies = {"Vitality"}, calculate = function(s) return s.Vitality end},
        MaxStamina = {dependencies = {"Endurance"}, calculate = function(s) return s.Endurance end},
        MaxMana = {dependencies = {"Intelligence"}, calculate = function(s) return s.Intelligence end},
        SprintSpeed = {dependencies = {"Speed"}, calculate = function(s) return s.Speed * 1.5 end},
    },
    dynamic = {
        Health = {maximum = "MaxHealth", regeneration = "HealthRegen"},
        Stamina = {maximum = "MaxStamina", regeneration = "StaminaRegen"},
        Mana = {maximum = "MaxMana", regeneration = "ManaRegen"},
    },
}
