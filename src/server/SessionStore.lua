-- Dependency-injected atomic lease protocol; no Roblox globals in this module.
local SessionStore = {}
function SessionStore.new(store, profile, util, options)
    local ttl, clock, sleep = options.ttl, options.clock, options.sleep
    assert(ttl >= 120, "Lease too short")
    local api = {}
    local function update(key, callback)
        local last
        for attempt = 1, 3 do
            local ok, value = pcall(function() return store:UpdateAsync(key, callback) end)
            if ok then return value end
            last = value
            if attempt < 3 then sleep(2 ^ (attempt - 1)) end
        end
        error("DataStore request failed: " .. tostring(last))
    end
    function api.open(userId, token)
        local denial
        local result = update("player_" .. userId, function(old, info)
            denial = nil -- UpdateAsync may repeat this callback.
            local now = clock()
            if old ~= nil then
                if type(old) ~= "table" or old.formatVersion ~= 1 then denial = "Unsupported stored envelope"; return nil end
                if type(old.data) ~= "table" then denial = "Stored profile is missing"; return nil end
                if old.session ~= nil then
                    local lock = old.session
                    if type(lock) ~= "table" or type(lock.id) ~= "string" or not util.finite(lock.expiresAt) then denial = "Invalid stored lease"; return nil end
                    if lock.id ~= token and lock.expiresAt > now then denial = "Profile is already active on another server; try again shortly"; return nil end
                end
            end
            local valid, data = pcall(function()
                local prepared = profile.prepare(old and old.data, now)
                if options.onLoad then options.onLoad(prepared, userId) end
                return prepared
            end)
            if not valid then denial = tostring(data); return nil end
            local nextValue = util.copy(old or {})
            nextValue.formatVersion, nextValue.data = 1, data
            nextValue.session = {id = token, expiresAt = now + ttl}
            return nextValue, {userId}, info and info:GetMetadata() or {}
        end)
        if not result or denial then error(denial or "Profile load cancelled") end
        return {data = util.copy(result.data), token = token, userId = userId, expiresAt = result.session.expiresAt}
    end
    function api.save(session, release)
        local data = profile.prepare(session.data, clock())
        data.updatedAt = clock()
        local denial
        local result = update("player_" .. session.userId, function(old, info)
            denial = nil
            local now = clock()
            if type(old) ~= "table" or old.formatVersion ~= 1 or type(old.session) ~= "table"
                or old.session.id ~= session.token or not util.finite(old.session.expiresAt) or old.session.expiresAt <= now then
                denial = "Session lease lost or expired"; return nil
            end
            local nextValue = util.copy(old)
            nextValue.data = util.copy(data)
            if release then nextValue.session = nil
            else nextValue.session = {id = session.token, expiresAt = now + ttl} end
            return nextValue, {session.userId}, info and info:GetMetadata() or {}
        end)
        if not result or denial then error(denial or "Save cancelled") end
        if not release then session.expiresAt = result.session.expiresAt end
        return true
    end
    return api
end
return SessionStore
