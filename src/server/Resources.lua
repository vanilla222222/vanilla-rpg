-- Current values are session-only. Reconcile maxima without granting free healing.
local Resources = {}
function Resources.new(definitions, util, stats)
    local current = {}
    local api = {}
    function api.reconcile(values)
        local changed = false
        for id, definition in pairs(definitions.dynamic) do
            local maximum = values[definition.maximum]
            assert(util.finite(maximum) and maximum >= 0, "Invalid resource maximum")
            local value = math.min(current[id] or maximum, maximum)
            if value ~= current[id] then changed = true; current[id] = value end
        end
        return changed
    end
    function api.reset(values)
        for id, definition in pairs(definitions.dynamic) do current[id] = values[definition.maximum] end
    end
    function api.snapshot() return util.copy(current) end
    function api.set(id, amount, values)
        assert(definitions.dynamic[id] and util.finite(amount) and amount >= 0, "Invalid resource value")
        local value = math.min(amount, values[definitions.dynamic[id].maximum])
        if current[id] == value then return false end
        current[id] = value; return true
    end
    function api.consume(id, amount)
        assert(definitions.dynamic[id] and util.finite(amount) and amount > 0, "Invalid resource cost")
        if current.Health <= 0 or current[id] < amount then return false end
        current[id] = current[id] - amount; return true
    end
    function api.advance(values, dt)
        assert(util.finite(dt) and dt >= 0, "Invalid elapsed time")
        local changed = api.reconcile(values)
        if current.Health <= 0 then return changed end -- Regeneration cannot resurrect.
        for id, definition in pairs(definitions.dynamic) do
            local maximum, rate = values[definition.maximum], values[definition.regeneration]
            assert(util.finite(rate) and rate >= 0, "Invalid regeneration rate")
            -- Saturate before multiplication to avoid overflow on large elapsed times.
            local missing = maximum - current[id]
            local gain = rate == 0 and 0 or (dt >= missing / rate and missing or rate * dt)
            if gain > 0 then current[id] = current[id] + gain; changed = true end
        end
        return changed
    end
    api.reconcile(stats)
    return api
end
return Resources
