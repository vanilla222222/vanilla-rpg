-- Server-only API. No client may choose reward amounts or write profiles.
local PlayerService = {}
function PlayerService.new(profile, Stats, definitions, util, clock, changed, Resources)
    local entries = {}
    local api = {}
    function api.attach(userId, session)
        assert(not entries[userId], "Player already attached")
        local stats = Stats.new(definitions, util)
        entries[userId] = {session = session, stats = stats, values = stats.calculate(), closing = false, busy = false}
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
            inventory = util.copy(entry.session.data.inventory), equipment = util.copy(entry.session.data.equipment),
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
