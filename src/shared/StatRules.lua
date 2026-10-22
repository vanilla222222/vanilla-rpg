-- Shared probability helpers; outcomes are applied only by server activity systems.
local Rules = {}
local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function positive(value) assert(finite(value) and value >= 0, "Expected nonnegative finite number") end
function Rules.fortuneChance(baseChancePercent, fortune)
    positive(baseChancePercent); positive(fortune)
    -- Compare before multiplying so the 500% cap also handles very large inputs.
    if fortune == 0 then return 0 end
    if baseChancePercent >= 50000 / fortune then return 500 end
    return baseChancePercent * fortune / 100
end
function Rules.rollCount(chancePercent, maximum, random)
    positive(chancePercent); positive(maximum)
    local chance = math.min(chancePercent, maximum)
    local count = math.floor(chance / 100)
    local remainder = (chance % 100) / 100
    if remainder > 0 then
        local roll = random()
        assert(finite(roll) and roll >= 0 and roll < 1, "Random sample must be in [0, 1)")
        if roll < remainder then count = count + 1 end
    end
    return count
end
function Rules.fortuneDrops(baseChancePercent, fortune, random)
    return Rules.rollCount(Rules.fortuneChance(baseChancePercent, fortune), 500, random)
end
function Rules.miningBlocks(spread, random) return Rules.rollCount(spread, 2500, random) end
function Rules.wisdomMultiplier(wisdom) positive(wisdom); return math.min(wisdom, 500) / 100 end
function Rules.critMultiplier(critDamage) positive(critDamage); return critDamage / 100 end
function Rules.abilityMultiplier(abilityDamage) positive(abilityDamage); return abilityDamage / 100 end
return Rules
