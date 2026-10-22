-- Server-only API. No client may choose reward amounts or write profiles.
local PlayerService = {}
function PlayerService.new(profile, Stats, definitions, util, clock, changed, Resources, Equipment, Inventory, Gathering)
    local entries = {}
    local api = {}
    function api.attach(userId, session)
        assert(not entries[userId], "Player already attached")
        local stats = Stats.new(definitions, util)
        local modifiers=Equipment and Equipment.modifiers(session.data) or {}
        for id,change in pairs(modifiers)do stats.set(id,change)end
        local values=stats.calculate()
        entries[userId] = {session = session, stats = stats, modifiers=modifiers, values = values, closing = false, busy = false}
        entries[userId].resources = Resources.new(definitions, util, entries[userId].values)
        return entries[userId]
    end
    function api.get(userId) return entries[userId] end -- Internal persistence use only.
    function api.detach(userId) entries[userId] = nil end
    function api.active(userId)
        local entry = entries[userId]
        return entry ~= nil and not entry.closing and clock() < entry.session.expiresAt
    end
    function api.snapshot(userId)
        if not api.active(userId) then return nil end
        local entry = entries[userId]
        return {schemaVersion = 3, coins = entry.session.data.coins, bank = entry.session.data.bank,
            gameXP = entry.session.data.gameXP, gameLevel = 1 + entry.session.data.gameXP / 100,
            inventory = util.copy(entry.session.data.inventory), equipment = util.copy(entry.session.data.equipment), equipmentItems = util.copy(entry.session.data.equipmentItems),
            collections = util.copy(entry.session.data.collections), talismans = util.copy(entry.session.data.talismans),
            skills = util.copy(entry.session.data.skills), stats = util.copy(entry.values), resources = entry.resources.snapshot(), sprinting = entry.sprinting or false}
    end
    function api.grantCoins(userId, amount)
        assert(api.active(userId), "Profile is not active")
        profile.addCoins(entries[userId].session.data, amount)
        changed(userId)
    end
    function api.spendCoins(userId, amount)
        assert(api.active(userId), "Profile is not active")
        local spent = profile.spendCoins(entries[userId].session.data, amount)
        if spent then changed(userId) end
        return spent
    end
    function api.setModifier(userId, source, modifier)
        assert(api.active(userId), "Profile is not active")
        assert(type(source)=="string" and not source:match("^equipment:") and not source:match("^talisman:"),"Equipment and talisman modifier sources are reserved")
        -- Validate on a fresh calculator first, then full composition. Roll back on overflow.
        local previous = entries[userId].modifiers or {}
        local candidate = util.copy(previous); candidate[source] = modifier
        local calculator = Stats.new(definitions, util)
        for id, change in pairs(candidate) do calculator.set(id, change) end
        local values = calculator.calculate()
        entries[userId].stats, entries[userId].modifiers = calculator, util.copy(candidate)
        entries[userId].values = values
        entries[userId].resources.reconcile(values)
        changed(userId, "stats")
    end
    function api.removeModifier(userId, source)
        assert(type(source)=="string" and not source:match("^equipment:") and not source:match("^talisman:"),"Equipment and talisman modifier sources are reserved")
        assert(api.active(userId), "Profile is not active")
        local candidate = util.copy(entries[userId].modifiers or {})
        candidate[source] = nil
        local calculator = Stats.new(definitions, util)
        for id, change in pairs(candidate) do calculator.set(id, change) end
        local values = calculator.calculate()
        entries[userId].stats, entries[userId].modifiers = calculator, candidate
        entries[userId].values = values
        entries[userId].resources.reconcile(values)
        changed(userId, "stats")
    end
    function api.changeEquipment(userId,action,slot,target,expected)
        assert(api.active(userId) and Equipment,"Equipment unavailable")
        local entry=entries[userId]
        local data
        if action=="equip" then data=Equipment.equip(entry.session.data,slot,target,expected)
        elseif action=="unequip" then data=Equipment.unequip(entry.session.data,slot,expected)
        else error("Unknown equipment action")end
        local modifiers={}
        for id,change in pairs(entry.modifiers or {})do if not id:match("^equipment:") and not id:match("^talisman:")then modifiers[id]=change end end
        for id,change in pairs(Equipment.modifiers(data))do modifiers[id]=change end
        local calculator=Stats.new(definitions,util)
        for id,change in pairs(modifiers)do calculator.set(id,change)end
        local values=calculator.calculate() -- No profile or stat mutation until all checks pass.
        entry.session.data,entry.modifiers,entry.stats,entry.values=data,modifiers,calculator,values
        entry.resources.reconcile(values)
        changed(userId,"stats")
    end
    function api.changeInventory(userId,action,from,to,amount,expected)
        assert(api.active(userId) and Inventory,"Inventory unavailable")
        local entry=entries[userId]
        entry.session.data=Inventory.change(entry.session.data,action,from,to,amount,expected)
        changed(userId,"inventory")
    end
    function api.grantStack(userId,itemId,quantity)
        assert(api.active(userId) and Inventory,"Inventory unavailable")
        local entry=entries[userId]
        entry.session.data=Inventory.grantStack(entry.session.data,itemId,quantity)
        changed(userId,"inventory")
    end
    function api.removeStack(userId,itemId,quantity)
        assert(api.active(userId) and Inventory,"Inventory unavailable")
        local entry=entries[userId]
        entry.session.data=Inventory.removeStack(entry.session.data,itemId,quantity)
        changed(userId,"inventory")
    end
    function api.grantGameXP(userId,amount)
        assert(api.active(userId),"Profile is not active")
        assert(util.integer(amount,1,9007199254740991),"Invalid game XP reward")
        local entry=entries[userId];local data=util.copy(entry.session.data)
        assert(amount<=9007199254740991-data.gameXP,"Game XP overflow")
        data.gameXP=data.gameXP+amount
        entry.session.data=profile.prepare(data,clock())
        changed(userId,"progression")
    end
    function api.harvestResource(userId,resourceId,random)
        assert(api.active(userId) and Gathering,"Gathering unavailable")
        local entry=entries[userId]
        local data,reward=Gathering.harvest(entry.session.data,entry.values,resourceId,random)
        local modifiers={}
        for id,change in pairs(entry.modifiers or {})do
            if not id:match("^equipment:") and not id:match("^talisman:")then modifiers[id]=change end
        end
        for id,change in pairs(Equipment.modifiers(data))do modifiers[id]=change end
        local calculator=Stats.new(definitions,util)
        for id,change in pairs(modifiers)do calculator.set(id,change)end
        local values=calculator.calculate()
        entry.session.data,entry.modifiers,entry.stats,entry.values=data,modifiers,calculator,values
        entry.resources.reconcile(values)
        changed(userId,"stats")
        return reward
    end
    function api.setResource(userId, id, value, silent)
        assert(api.active(userId), "Profile is not active")
        local entry = entries[userId]
        local updated = entry.resources.set(id, value, entry.values)
        if updated and not silent then changed(userId, id == "Health" and "health" or "resources") end
    end
    function api.consumeResource(userId, id, amount)
        assert(api.active(userId), "Profile is not active")
        local consumed = entries[userId].resources.consume(id, amount)
        if consumed then changed(userId, id == "Health" and "health" or "resources") end
        return consumed
    end
    function api.setSprinting(userId, enabled)
        assert(api.active(userId) and type(enabled) == "boolean", "Invalid sprint state")
        local entry = entries[userId]
        if entry.sprinting == enabled then return end
        entry.sprinting = enabled
        changed(userId, "movement")
    end
    function api.resetResources(userId)
        assert(api.active(userId), "Profile is not active")
        entries[userId].sprinting = false
        entries[userId].resources.reset(entries[userId].values)
        changed(userId, "respawn")
    end
    function api.advanceResources(userId, dt)
        if not api.active(userId) then return end
        local entry = entries[userId]
        if entry.resources.advance(entry.values, dt) then changed(userId, "health") end
    end
    return api
end
return PlayerService
