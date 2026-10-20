-- Deterministic, source-keyed modifiers. Re-equipping the same source replaces it.
local Stats = {}
function Stats.new(definitions, util)
    local modifiers = {}
    local api = {}
    function api.set(source, changes)
        assert(type(source) == "string" and #source > 0, "Modifier needs a source ID")
        assert(type(changes) == "table", "Invalid modifier")
        for stat, change in pairs(changes) do
            assert(definitions.definitive[stat] and type(change) == "table", "Unknown stat or invalid modifier")
            for key, value in pairs(change) do
                assert(key == "flat" or key == "percent" or key == "multiplier", "Unknown modifier operation")
                assert(util.finite(value), "Modifier must be finite")
                if key == "multiplier" then assert(value >= 0, "Negative multiplier") end
            end
        end
        modifiers[source] = util.copy(changes)
    end
    function api.remove(source) modifiers[source] = nil end
    function api.calculate()
        local ids = {}
        for source in pairs(modifiers) do table.insert(ids, source) end
        table.sort(ids)
        local result = {}
        for stat, definition in pairs(definitions.definitive) do
            local flat, percent, multiplier = 0, 0, 1
            for _, source in ipairs(ids) do
                local change = modifiers[source][stat]
                if change then
                    flat = flat + (change.flat or 0)
                    percent = percent + (change.percent or 0)
                    multiplier = multiplier * (change.multiplier or 1)
                end
            end
            local value = (definition.base + flat) * (1 + percent) * multiplier
            assert(util.finite(value), "Stat overflow: " .. stat)
            result[stat] = math.max(definition.min, math.min(definition.max, value))
        end
        local visiting = {}
        local function resolve(id)
            if result[id] ~= nil then return result[id] end
            assert(not visiting[id], "Circular defined stat: " .. id)
            local definition = definitions.defined[id]
            assert(definition, "Unknown stat dependency: " .. id)
            visiting[id] = true
            local inputs = {}
            for _, dependency in ipairs(definition.dependencies) do inputs[dependency] = resolve(dependency) end
            local value = definition.calculate(inputs)
            assert(util.finite(value) and value >= 0, "Invalid defined stat: " .. id)
            result[id], visiting[id] = value, nil
            return value
        end
        for id in pairs(definitions.defined) do resolve(id) end
        return result
    end
    return api
end
return Stats
