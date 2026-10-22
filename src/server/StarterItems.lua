-- Pure, deterministic join-time grant; safe when UpdateAsync repeats its callback.
local StarterItems = {}
StarterItems.ids = {"starter_axe", "starter_pickaxe", "starter_sword", "starter_hoe", "starter_fishing_rod"}
function StarterItems.grant(data, userId)
    assert(data.unlocks.starterKitV1 == nil or type(data.unlocks.starterKitV1) == "boolean", "Invalid starter-kit receipt")
    if data.unlocks.starterKitV1 then return false end
    local free = {}
    for index = 1, data.inventory.capacity do
        if data.inventory.slots[tostring(index)] == nil then
            table.insert(free, tostring(index))
            if #free==#StarterItems.ids then break end
        end
    end
    -- Defer the entire kit if full; never replace items or leave a partial receipt.
    if #free < #StarterItems.ids then return false end
    for index, itemId in ipairs(StarterItems.ids) do
        data.inventory.slots[free[index]] = {
            itemId = itemId, quantity = 1,
            instanceId = "starter:v1:" .. tostring(userId) .. ":" .. itemId,
        }
    end
    data.unlocks.starterKitV1 = true
    return true
end
return StarterItems
