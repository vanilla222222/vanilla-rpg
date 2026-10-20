-- Server-only API. No client may choose reward amounts or write profiles.
local PlayerService = {}
function PlayerService.new(profile, Stats, definitions, util, clock, changed)
    local entries = {}
    local api = {}
    function api.attach(userId, session)
        assert(not entries[userId], "Player already attached")
        entries[userId] = {session = session, stats = Stats.new(definitions, util), closing = false, busy = false}
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
        return {schemaVersion = 1, coins = entry.session.data.currencies.coins,
            skills = util.copy(entry.session.data.skills), stats = entry.stats.calculate()}
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
        calculator.calculate()
        entries[userId].stats, entries[userId].modifiers = calculator, util.copy(candidate)
        changed(userId)
    end
    function api.removeModifier(userId, source)
        assert(api.active(userId), "Profile is not active")
        local candidate = util.copy(entries[userId].modifiers or {})
        candidate[source] = nil
        local calculator = Stats.new(definitions, util)
        for id, change in pairs(candidate) do calculator.set(id, change) end
        calculator.calculate()
        entries[userId].stats, entries[userId].modifiers = calculator, candidate
        changed(userId)
    end
    return api
end
return PlayerService
