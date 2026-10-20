local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.TableUtil)
local Definitions = require(Shared.StatDefinitions)
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
local testEvent
if RunService:IsStudio() then
    testEvent = Instance.new("RemoteEvent")
    testEvent.Name, testEvent.Parent = "StudioGrantCoins", remotes
end
remotes.Parent = ReplicatedStorage -- Publish only once all endpoints exist.
local closing, loading, saving = false, 0, 0
local requestTimes, rewardTimes = {}, {}
local service
local function publish(userId)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local snapshot = service.snapshot(userId)
    if not snapshot then return end
    snapshot.persistence = temporary and "Temporary Studio session — resets when the server stops" or "DataStore persistence enabled"
    snapshot.studio = RunService:IsStudio()
    snapshotEvent:FireClient(player, snapshot)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local oldMax = humanoid.MaxHealth
        humanoid.MaxHealth = snapshot.stats.Health
        humanoid.WalkSpeed = snapshot.stats.WalkSpeed
        -- Updating modifiers must not heal or revive a character.
        if humanoid.Health > 0 and oldMax > 0 then
            humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
        end
    end
end
service = require(script.Parent.PlayerService).new(Profile, require(script.Parent.Stats), Definitions, Util, os.time, publish)
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
if testEvent then
    testEvent.OnServerEvent:Connect(function(player)
        local now = os.clock()
        if not service.active(player.UserId) or now - (rewardTimes[player] or -math.huge) < 1 then return end
        rewardTimes[player] = now
        service.grantCoins(player.UserId, 10) -- Amount fixed on server, arguments ignored.
    end)
end
local function connectPlayer(player)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid and service.active(player.UserId) then
            local stats = service.snapshot(player.UserId).stats
            humanoid.MaxHealth, humanoid.Health, humanoid.WalkSpeed = stats.Health, stats.Health, stats.WalkSpeed
        end
    end)
    task.spawn(joined, player)
end
Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player)
    requestTimes[player], rewardTimes[player] = nil, nil
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
