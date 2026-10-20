-- Portable core: Roblox dependencies are injected by Bootstrap.
local Profile = {}
Profile.VERSION = 1
Profile.MAX_INTEGER = 9007199254740991 -- Largest exactly representable integer.
function Profile.new(now)
    return {
        schemaVersion = Profile.VERSION, createdAt = now, updatedAt = now,
        currencies = {coins = 0},
        skills = {farming = {xp = 0}, foraging = {xp = 0}, mining = {xp = 0}, combat = {xp = 0}, fishing = {xp = 0}},
        inventory = {capacity = 30, slots = {}}, equipment = {}, collections = {},
        storage = {stacks = {}, unique = {}}, unlocks = {},
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
                assert(type(data[key]) == type(default), "Invalid profile field: " .. key)
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
        assert(raw.schemaVersion == Profile.VERSION, "Unsupported profile version; migration required")
        -- Future versions are refused. Add explicit migrations here before advancing VERSION.
        checkJSON(raw, 0)
        local data = util.copy(raw)
        reconcile(data, Profile.new(now))
        assert(util.integer(data.createdAt, 0, Profile.MAX_INTEGER), "Invalid creation time")
        assert(util.integer(data.updatedAt, 0, Profile.MAX_INTEGER), "Invalid update time")
        counts(data.currencies)
        for _, skill in pairs(data.skills) do
            assert(type(skill) == "table" and util.integer(skill.xp, 0, Profile.MAX_INTEGER), "Invalid skill XP")
        end
        assert(util.integer(data.inventory.capacity, 1, 1000), "Invalid inventory capacity")
        counts(data.collections); counts(data.storage.stacks)
        -- Equipment/unique item validation belongs to the inventory milestone.
        return data
    end
    function api.addCoins(data, amount)
        assert(util.integer(amount, 1, Profile.MAX_INTEGER), "Reward must be a positive safe integer")
        local current = data.currencies.coins
        assert(util.integer(current, 0, Profile.MAX_INTEGER) and amount <= Profile.MAX_INTEGER - current, "Coin overflow")
        data.currencies.coins = current + amount
    end
    function api.spendCoins(data, amount)
        assert(util.integer(amount, 1, Profile.MAX_INTEGER), "Cost must be a positive safe integer")
        if data.currencies.coins < amount then return false end
        data.currencies.coins = data.currencies.coins - amount
        return true
    end
    return api
end
return Profile
