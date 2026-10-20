local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local definitions = require(ReplicatedStorage:WaitForChild("Shared").StatDefinitions)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RPGRemotes")
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "FoundationHUD", false
local frame = Instance.new("Frame")
frame.Size, frame.Position = UDim2.new(0.92, 0, 0.88, 0), UDim2.new(0.04, 0, 0.06, 0)
frame.BackgroundColor3, frame.Parent = Color3.fromRGB(22, 28, 35), gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize, constraint.Parent = Vector2.new(460, 760), frame
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
padding.PaddingTop, padding.PaddingBottom, padding.Parent = UDim.new(0, 16), UDim.new(0, 16), frame
local label = Instance.new("TextLabel")
label.Size, label.BackgroundTransparency = UDim2.new(1, 0, 0, 80), 1
label.Font, label.TextSize = Enum.Font.Gotham, 16
label.TextColor3, label.TextWrapped = Color3.fromRGB(235, 241, 247), true
label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
label.Text, label.Parent = "VANILLA RPG\nLoading your profile…", frame
local resources = label:Clone()
resources.Position, resources.Size, resources.Text, resources.Parent = UDim2.new(0, 0, 0, 88), UDim2.new(1, 0, 0, 88), "", frame
local scroll = Instance.new("ScrollingFrame")
scroll.Position, scroll.Size = UDim2.new(0, 0, 0, 184), UDim2.new(1, 0, 1, -324)
scroll.BackgroundTransparency, scroll.BorderSizePixel = 1, 0
scroll.AutomaticCanvasSize, scroll.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
scroll.ScrollBarThickness, scroll.Parent = 6, frame
local statsLabel = label:Clone()
statsLabel.Text, statsLabel.Size = "", UDim2.new(1, -8, 0, 0)
statsLabel.AutomaticSize, statsLabel.Parent = Enum.AutomaticSize.Y, scroll
local function button(text, offset)
    local b = Instance.new("TextButton")
    b.Position, b.Size = UDim2.new(0, 0, 1, offset), UDim2.new(1, 0, 0, 40)
    b.Text, b.TextSize, b.Font = text, 15, Enum.Font.GothamBold
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(63, 117, 96), Color3.new(1, 1, 1)
    b.Parent = frame
    return b
end
local sprintButton = button("Sprint: OFF · Shift or tap", -132)
local drainButton = button("Studio test: drain 25 health / stamina / mana", -88)
local rewardButton = button("Studio test: +10 coins", -44)
drainButton.Visible, rewardButton.Visible = false, false
local sprinting = false
local function sprint(value) sprinting = value; remotes.SetSprinting:FireServer(value) end
sprintButton.Activated:Connect(function() sprint(not sprinting) end)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) then sprint(true) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then sprint(false) end
end)
UserInputService.WindowFocusReleased:Connect(function() sprint(false) end)
rewardButton.Activated:Connect(function()
    local remote = remotes:FindFirstChild("StudioGrantCoins")
    if remote then remote:FireServer() end
end)
drainButton.Activated:Connect(function()
    local remote = remotes:FindFirstChild("StudioDrainResources")
    if remote then remote:FireServer() end
end)
local function number(value) return string.format("%.2f", value):gsub("%.?0+$", "") end
local function heading(id) return id:gsub("(%l)(%u)", "%1 %2") end
remotes.Snapshot.OnClientEvent:Connect(function(data)
    label.Text = "VANILLA RPG · FOUNDATION\nCoins: " .. tostring(data.coins) .. "\n" .. data.persistence
    local resourceLines = {"DYNAMIC RESOURCES"}
    for _, id in ipairs({"Health", "Stamina", "Mana"}) do
        table.insert(resourceLines, id .. ": " .. number(data.resources[id]) .. " / " .. number(data.stats[definitions.dynamic[id].maximum]))
    end
    resources.Text = table.concat(resourceLines, "\n")
    local lines = {}
    for _, group in ipairs({"definitive", "defined"}) do
        table.insert(lines, string.upper(group) .. " STATS")
        local keys = {}
        for key in pairs(definitions[group]) do table.insert(keys, key) end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local unit = definitions[group][key].unit
            table.insert(lines, heading(key) .. ": " .. number(data.stats[key]) .. (unit and (" " .. unit) or ""))
        end
        table.insert(lines, "")
    end
    table.insert(lines, "SKILLS · TOTAL XP")
    local skills = {}
    for key in pairs(data.skills) do table.insert(skills, key) end
    table.sort(skills)
    for _, key in ipairs(skills) do table.insert(lines, key .. ": " .. data.skills[key].xp) end
    statsLabel.Text = table.concat(lines, "\n")
    sprinting = data.sprinting
    sprintButton.Text = "Sprint: " .. (sprinting and "ON" or "OFF") .. " · Shift or tap"
    drainButton.Visible, rewardButton.Visible = data.studio, data.studio
end)
gui.Parent = player:WaitForChild("PlayerGui")
remotes.RequestSnapshot:FireServer()
