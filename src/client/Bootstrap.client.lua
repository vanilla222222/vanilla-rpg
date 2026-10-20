local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RPGRemotes")
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "FoundationHUD", false
local frame = Instance.new("Frame")
frame.Size, frame.Position = UDim2.new(0.92, 0, 0.72, 0), UDim2.new(0.04, 0, 0.08, 0)
frame.BackgroundColor3, frame.Parent = Color3.fromRGB(22, 28, 35), gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize, constraint.Parent = Vector2.new(440, 580), frame
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
padding.PaddingTop, padding.PaddingBottom, padding.Parent = UDim.new(0, 16), UDim.new(0, 16), frame
local label = Instance.new("TextLabel")
label.Size, label.BackgroundTransparency = UDim2.new(1, 0, 0, 80), 1
label.Font, label.TextSize = Enum.Font.Gotham, 16
label.TextColor3, label.TextWrapped = Color3.fromRGB(235, 241, 247), true
label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
label.Text, label.Parent = "VANILLA RPG\nLoading your profile…", frame
local scroll = Instance.new("ScrollingFrame")
scroll.Position, scroll.Size = UDim2.new(0, 0, 0, 90), UDim2.new(1, 0, 1, -146)
scroll.BackgroundTransparency, scroll.BorderSizePixel = 1, 0
scroll.AutomaticCanvasSize, scroll.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
scroll.ScrollBarThickness, scroll.Parent = 6, frame
local statsLabel = label:Clone()
statsLabel.Text, statsLabel.Size = "", UDim2.new(1, -8, 0, 0)
statsLabel.AutomaticSize, statsLabel.Parent = Enum.AutomaticSize.Y, scroll
local button = Instance.new("TextButton")
button.Position, button.Size = UDim2.new(0, 0, 1, -44), UDim2.new(1, 0, 0, 44)
button.Text, button.TextSize, button.Font = "Studio test: +10 coins", 16, Enum.Font.GothamBold
button.BackgroundColor3, button.TextColor3 = Color3.fromRGB(63, 117, 96), Color3.new(1, 1, 1)
button.Visible, button.Parent = false, frame
button.Activated:Connect(function()
    local remote = remotes:FindFirstChild("StudioGrantCoins")
    if remote then remote:FireServer() end
end)
remotes.Snapshot.OnClientEvent:Connect(function(data)
    label.Text = "VANILLA RPG · FOUNDATION\nCoins: " .. tostring(data.coins) .. "\n" .. data.persistence
    local keys, lines = {}, {"PLAYER STATS"}
    for key in pairs(data.stats) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do table.insert(lines, key .. ": " .. tostring(data.stats[key])) end
    table.insert(lines, "\nSKILLS · TOTAL XP")
    local skills = {}
    for key in pairs(data.skills) do table.insert(skills, key) end
    table.sort(skills)
    for _, key in ipairs(skills) do table.insert(lines, key .. ": " .. data.skills[key].xp) end
    statsLabel.Text = table.concat(lines, "\n")
    button.Visible = data.studio
end)
gui.Parent = player:WaitForChild("PlayerGui")
-- Subscribe before requesting: avoids a load/snapshot listener race.
remotes.RequestSnapshot:FireServer()
