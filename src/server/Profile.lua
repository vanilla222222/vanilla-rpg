-- Portable core: Roblox dependencies are injected by Bootstrap.
local Profile = {}
Profile.VERSION = 2
Profile.MAX_INTEGER = 9007199254740991 -- Largest exactly representable integer.
Profile.EQUIPMENT_SLOTS = {"helmet", "chestplate", "gloves", "leggings", "boots",
    "brooch", "artifact", "ring", "bracelet", "necklace", "hoe", "pickaxe", "axe",
    "fishingRod", "weapon1", "weapon2", "weapon3", "weapon4"}
function Profile.new(now)
    local equipment = {}
    for _, slot in ipairs(Profile.EQUIPMENT_SLOTS) do equipment[slot] = false end
    local skills = {}
    for _, id in ipairs({"farming", "foraging", "mining", "fishing"}) do skills[id] = {level = 1, xp = 0} end
    skills.combat = {}
    for _, id in ipairs({"heavyMelee", "lightMelee", "magic", "ranged"}) do skills.combat[id] = {level = 1, xp = 0} end
    return {
        schemaVersion = Profile.VERSION, createdAt = now, updatedAt = now,
        coins = 0, bank = 0, gameXP = 0, skills = skills,
        inventory = {capacity = 30, slots = {}}, equipment = equipment,
        talismans = {}, museum = {}, quests = {}, collections = {},
        storage = {stacks = {}, unique = {}}, unlocks = {}, legacy = {},
    }
end
function Profile.create(util)
    local api = {}
    local function checkJSON(value, depth)
        assert(depth < 20, "Profile nesting limit exceeded")
        local kind = type(value)
        assert(kind == "table" or kind == "string" or kind == "number" or kind == "boolean", "Unsupported profile value")
        if kind == "number" then assert(util.finite(value), "Non-finite profile value") end
        if kind == "table" then
            for key, child in pairs(value) do
                assert(type(key) == "string", "Profile maps require string keys")
                checkJSON(child, depth + 1)
            end
        end
    end
    local function reconcile(data, defaults)
        for key, default in pairs(defaults) do
            if data[key] == nil then data[key] = util.copy(default)
            else
                if default == false then
                    assert(data[key] == false or (type(data[key]) == "string" and #data[key] > 0), "Invalid equipment reference: " .. key)
                else assert(type(data[key]) == type(default), "Invalid profile field: " .. key) end
                if type(default) == "table" then reconcile(data[key], default) end
            end
        end
    end
    local function counts(map)
        for key, value in pairs(map) do
            assert(type(key) == "string" and util.integer(value, 0, Profile.MAX_INTEGER), "Invalid count: " .. tostring(key))
        end
    end
    function api.prepare(raw, now)
        if raw == nil then return Profile.new(now) end
        assert(type(raw) == "table", "Profile is not a table")
        assert(raw.schemaVersion == 1 or raw.schemaVersion == Profile.VERSION, "Unsupported profile version; migration required")
        checkJSON(raw, 0)
        local data = util.copy(raw)
        -- Explicit deprecated fields only; unknown extension data is retained.
        -- Conflicts are archived rather than merged into balances or multiplied into skills.
        data.legacy = data.legacy or {}
        assert(type(data.legacy) == "table", "Invalid legacy archive")
        if data.currencies ~= nil then
            assert(type(data.currencies) == "table", "Invalid deprecated currencies")
            counts(data.currencies)
            if data.coins == nil then data.coins = data.currencies.coins or 0 end
            data.legacy.currencies = data.legacy.currencies or util.copy(data.currencies)
            data.currencies = nil
        end
        if data.skills and data.skills.combat and (data.skills.combat.xp ~= nil or data.skills.combat.level ~= nil) then
            local combat = data.skills.combat
            assert(type(combat) == "table", "Invalid combat skills")
            if combat.xp ~= nil then assert(util.integer(combat.xp, 0, Profile.MAX_INTEGER), "Invalid legacy combat XP") end
            if combat.level ~= nil then assert(util.integer(combat.level, 1, Profile.MAX_INTEGER), "Invalid legacy combat level") end
            data.legacy.combat = data.legacy.combat or {xp = combat.xp or 0, level = combat.level or 1}
            combat.xp, combat.level = nil, nil
        end
        data.schemaVersion = Profile.VERSION
        reconcile(data, Profile.new(now))
        assert(util.integer(data.createdAt, 0, Profile.MAX_INTEGER), "Invalid creation time")
        assert(util.integer(data.updatedAt, 0, Profile.MAX_INTEGER), "Invalid update time")
        for _, id in ipairs({"coins", "bank", "gameXP"}) do
            assert(util.integer(data[id], 0, Profile.MAX_INTEGER), "Invalid balance or XP: " .. id)
        end
        local function skill(value)
            assert(type(value) == "table" and util.integer(value.xp, 0, Profile.MAX_INTEGER)
                and util.integer(value.level, 1, Profile.MAX_INTEGER), "Invalid skill level or XP")
        end
        for _, id in ipairs({"farming", "foraging", "mining", "fishing"}) do skill(data.skills[id]) end
        for _, id in ipairs({"heavyMelee", "lightMelee", "magic", "ranged"}) do skill(data.skills.combat[id]) end
        assert(util.integer(data.inventory.capacity, 1, 1000), "Invalid inventory capacity")
        counts(data.collections); counts(data.storage.stacks)
        -- Equipment/unique item validation belongs to the inventory milestone.
        return data
    end
    function api.addCoins(data, amount)
        assert(util.integer(amount, 1, Profile.MAX_INTEGER), "Reward must be a positive safe integer")
        local current = data.coins
        assert(util.integer(current, 0, Profile.MAX_INTEGER) and amount <= Profile.MAX_INTEGER - current, "Coin overflow")
        data.coins = current + amount
    end
    function api.spendCoins(data, amount)
        assert(util.integer(amount, 1, Profile.MAX_INTEGER), "Cost must be a positive safe integer")
        if data.coins < amount then return false end
        data.coins = data.coins - amount
        return true
    end
    return api
end
return Profile
