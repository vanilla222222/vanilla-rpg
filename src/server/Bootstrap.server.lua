local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.TableUtil)
local Definitions = require(Shared.StatDefinitions)
local ItemCatalog = require(Shared.ItemCatalog).create(require(Shared.ItemDefinitions),require(Shared.ItemTypes),Definitions,Util)
local Profile = require(script.Parent.Profile).create(Util)
local Config = require(script.Parent.Config)
local temporary = RunService:IsStudio() and not Config.PersistStudio
local store
if temporary then
    local records = {}
    store = {UpdateAsync = function(_, key, transform)
        local result = transform(Util.copy(records[key]), nil)
        if result ~= nil then records[key] = Util.copy(result) end
        return Util.copy(result)
    end}
else
    assert(Config.StudioStore ~= Config.ProductionStore, "Studio and production must use separate stores")
    local name = RunService:IsStudio() and Config.StudioStore or Config.ProductionStore
    store = DataStoreService:GetDataStore(name)
end
local persistence = require(script.Parent.SessionStore).new(store, Profile, Util, {
    ttl = Config.LeaseSeconds, clock = os.time, sleep = task.wait,
})
local remotes = Instance.new("Folder")
remotes.Name = "RPGRemotes"
local snapshotEvent = Instance.new("RemoteEvent")
snapshotEvent.Name, snapshotEvent.Parent = "Snapshot", remotes
local requestEvent = Instance.new("RemoteEvent")
requestEvent.Name, requestEvent.Parent = "RequestSnapshot", remotes
local sprintEvent = Instance.new("RemoteEvent")
sprintEvent.Name, sprintEvent.Parent = "SetSprinting", remotes
remotes.Parent = ReplicatedStorage -- Publish only once all endpoints exist.
local closing, loading, saving = false, 0, 0
local requestTimes, sprintTimes = {}, {}
local healthConnections, writingHealth = {}, {}
local service
local function publish(userId, reason)
    local player = Players:GetPlayerByUserId(userId)
    if not player or not service.active(userId) then return end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    -- Preserve damage already applied by the engine, even if its signal is deferred.
    if humanoid and reason ~= "health" and reason ~= "respawn" then
        service.setResource(userId, "Health", humanoid.Health, true)
    end
    local snapshot = service.snapshot(userId)
    snapshot.persistence = temporary and "Temporary Studio session — resets when the server stops" or "DataStore persistence enabled"
    snapshot.studio = RunService:IsStudio()
    snapshot.temporary = temporary
    if humanoid then
        writingHealth[userId] = true
        humanoid.MaxHealth = snapshot.stats.MaxHealth
        humanoid.WalkSpeed = snapshot.sprinting and snapshot.stats.SprintSpeed or snapshot.stats.Speed
        if humanoid.Health > 0 then humanoid.Health = snapshot.resources.Health end
        writingHealth[userId] = nil
    end
    snapshotEvent:FireClient(player, snapshot)
end
service = require(script.Parent.PlayerService).new(Profile, require(script.Parent.Stats), Definitions, Util, os.time, publish, require(script.Parent.Resources))

local function save(player, release)
    local entry = service.get(player.UserId)
    if not entry then return end
    if release then
        if entry.closing then return end
        entry.closing = true -- Stop mutations before waiting for an earlier autosave.
    elseif entry.closing or entry.busy then return end
    local deadline = os.clock() + 25
    while entry.busy and os.clock() < deadline do task.wait(0.05) end
    if entry.busy then warn("Final save could not acquire local queue for " .. player.UserId); return end
    entry.busy = true
    saving = saving + 1
    local ok, problem = pcall(persistence.save, entry.session, release)
    entry.busy = false
    if not ok then
        warn("Profile save failed for " .. player.UserId .. ": " .. tostring(problem))
        if not release and os.time() >= entry.session.expiresAt then
            entry.closing = true
            player:Kick("Your data session expired. Rejoin to protect your progress.")
        end
    end
    if release then service.detach(player.UserId) end
    saving = saving - 1
end
local function joined(player)
    if closing then player:Kick("Server is closing; please rejoin."); return end
    loading = loading + 1
    local ok, result = pcall(persistence.open, player.UserId, HttpService:GenerateGUID(false))
    if ok then
        if closing or player.Parent ~= Players then
            local released, problem = pcall(persistence.save, result, true)
            if not released then warn("Late load release failed: " .. tostring(problem)) end
        else
            service.attach(player.UserId, result)
            player:SetAttribute("ProfileLoaded", true)
            publish(player.UserId)
        end
    else
        warn("Profile load failed for " .. player.UserId .. ": " .. tostring(result))
        player:Kick("Your profile could not load safely. Please try again shortly.")
    end
    loading = loading - 1
end
requestEvent.OnServerEvent:Connect(function(player)
    local now = os.clock()
    if now - (requestTimes[player] or -math.huge) < 1 then return end
    requestTimes[player] = now
    publish(player.UserId)
end)
local function bindCharacter(player, character)
    local userId = player.UserId
    if healthConnections[userId] then healthConnections[userId]:Disconnect(); healthConnections[userId] = nil end
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid or player.Character ~= character then return end
    healthConnections[userId] = humanoid.HealthChanged:Connect(function()
        if player.Character == character and service.active(userId) and not writingHealth[userId] then
            service.setResource(userId, "Health", humanoid.Health)
        end
    end)
    if service.active(userId) then service.resetResources(userId) end
end
sprintEvent.OnServerEvent:Connect(function(player, enabled)
    if type(enabled) ~= "boolean" or not service.active(player.UserId) then return end
    local now = os.clock()
    -- Always accept release so a throttled button release cannot stick sprint on.
    if enabled and now - (sprintTimes[player] or -math.huge) < 0.1 then return end
    sprintTimes[player] = now
    service.setSprinting(player.UserId, enabled)
end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    if closing then return end
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    local step = elapsed; elapsed = 0
    for _, player in ipairs(Players:GetPlayers()) do
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and service.active(player.UserId) then
            service.setResource(player.UserId, "Health", humanoid.Health, true)
            service.advanceResources(player.UserId, step)
        end
    end
end)
local function connectPlayer(player)
    player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
    if player.Character then task.spawn(bindCharacter, player, player.Character) end
    task.spawn(joined, player)
end
Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player)
    requestTimes[player], sprintTimes[player] = nil, nil
    if healthConnections[player.UserId] then healthConnections[player.UserId]:Disconnect(); healthConnections[player.UserId] = nil end
    writingHealth[player.UserId] = nil
    save(player, true)
end)
for _, player in ipairs(Players:GetPlayers()) do connectPlayer(player) end
-- Short watchdog prevents continued progression after an unrenewed lease expires.
task.spawn(function()
    while not closing do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            local entry = service.get(player.UserId)
            if entry and not entry.closing and os.time() >= entry.session.expiresAt then
                entry.closing = true
                player:Kick("Your data session expired. Rejoin to protect your progress.")
            end
        end
    end
end)
task.spawn(function()
    while not closing do
        task.wait(Config.AutosaveSeconds)
        if closing then break end
        for _, player in ipairs(Players:GetPlayers()) do task.spawn(save, player, false) end
    end
end)
game:BindToClose(function()
    closing = true
    local pending = 0
    for _, player in ipairs(Players:GetPlayers()) do
        pending = pending + 1
        task.spawn(function() save(player, true); pending = pending - 1 end)
    end
    local deadline = os.clock() + 27
    while (pending > 0 or loading > 0 or saving > 0) and os.clock() < deadline do task.wait(0.05) end
    if pending > 0 or loading > 0 or saving > 0 then warn("Shutdown ended with pending profile operations") end
end)
print("Vanilla RPG foundation ready; " .. (temporary and "temporary Studio data" or "DataStore enabled"))
