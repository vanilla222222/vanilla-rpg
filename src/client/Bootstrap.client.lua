local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local definitions = require(ReplicatedStorage:WaitForChild("Shared").StatDefinitions)
local Shared=ReplicatedStorage.Shared
local itemTypes=require(Shared.ItemTypes)
local itemCatalog=require(Shared.ItemCatalog).create(require(Shared.ItemDefinitions),itemTypes,definitions,require(Shared.TableUtil))
local items=itemCatalog.all()
local collectionDefinitions=require(Shared.CollectionDefinitions)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RPGRemotes")
local color = {panel=Color3.fromRGB(19,27,39), card=Color3.fromRGB(29,40,55), line=Color3.fromRGB(58,76,97),
    text=Color3.fromRGB(234,241,249), muted=Color3.fromRGB(153,173,195), accent=Color3.fromRGB(92,220,190)}
local function make(kind, properties, parent)
    local object = Instance.new(kind)
    for key,value in pairs(properties) do object[key]=value end
    object.Parent=parent;return object
end
local function round(object,radius)
    make("UICorner",{CornerRadius=UDim.new(0,radius or 10)},object)
end
local function text(parent,value,size,position,fontSize,tint)
    return make("TextLabel",{Text=value,Size=size,Position=position,BackgroundTransparency=1,
        Font=Enum.Font.Gotham,TextSize=fontSize or 14,TextColor3=tint or color.text,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},parent)
end
local function button(parent,value,size,position)
    local b=make("TextButton",{Text=value,Size=size,Position=position,BackgroundColor3=color.card,
        TextColor3=color.text,Font=Enum.Font.GothamBold,TextSize=14,AutoButtonColor=true},parent)
    round(b,8);return b
end
local function pretty(id)return id:gsub("(%l)(%u)","%1 %2"):gsub("^%l",string.upper)end
local function number(value)return string.format("%.2f",value):gsub("%.?0+$","")end
local gui=make("ScreenGui",{Name="VanillaHUD",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
local hud=make("Frame",{Name="Resources",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-18),
    Size=UDim2.new(0.9,0,0,178),BackgroundColor3=color.panel,BackgroundTransparency=.06},gui)
make("UISizeConstraint",{MaxSize=Vector2.new(340,178)},hud);round(hud,12)
make("UIStroke",{Color=color.line,Transparency=.35},hud)
local level=text(hud,"VANILLA RPG  /  LEVEL 1.00",UDim2.new(1,-28,0,24),UDim2.fromOffset(14,8),12,color.accent)
level.Font=Enum.Font.GothamBold
local wallet=text(hud,"Loading profile…",UDim2.new(1,-28,0,20),UDim2.fromOffset(14,31),12,color.muted)
local bars={}
for i,entry in ipairs({{"Health",Color3.fromRGB(235,104,120)},{"Stamina",Color3.fromRGB(231,192,95)},{"Mana",Color3.fromRGB(104,166,244)}})do
    local id,tint=entry[1],entry[2]
    local track=make("Frame",{Position=UDim2.new(0,14,0,55+(i-1)*29),Size=UDim2.new(1,-28,0,23),BackgroundColor3=color.card,ClipsDescendants=true},hud);round(track,6)
    local fill=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=tint,BackgroundTransparency=.63,BorderSizePixel=0},track);round(fill,6)
    local label=text(track,id.." —",UDim2.new(1,-16,1,0),UDim2.fromOffset(8,0),12)
    bars[id]={fill=fill,label=label}
end
local defense=text(hud,"DEFENSE  0",UDim2.new(.58,-14,0,22),UDim2.fromOffset(14,148),11,color.muted)
local sprint=button(hud,"SPRINT OFF",UDim2.new(.42,-14,0,22),UDim2.new(.58,0,0,148));sprint.TextSize=10
local inventoryButton=button(hud,"Inventory  [I]",UDim2.new(.5,-5,0,36),UDim2.new(0,0,0,-46))
local statsButton=button(hud,"Stats  [C]",UDim2.new(.5,-5,0,36),UDim2.new(.5,5,0,-46))
local collectionsButton=button(hud,"Collections",UDim2.new(1,0,0,32),UDim2.new(0,0,0,-86))
local shade=make("TextButton",{Name="Backdrop",Text="",Visible=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.4,AutoButtonColor=false,ZIndex=5},gui)
local windows={}
local function window(id,title,subtitle)
    local panel=make("Frame",{Name=id,Visible=false,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.46),Size=UDim2.fromScale(.92,.78),BackgroundColor3=color.panel,ZIndex=6},gui)
    make("UISizeConstraint",{MaxSize=Vector2.new(800,650)},panel);round(panel,14)
    make("UIStroke",{Color=color.line},panel)
    local heading=text(panel,title,UDim2.new(1,-86,0,30),UDim2.fromOffset(20,14),22);heading.Font=Enum.Font.GothamBold
    text(panel,subtitle,UDim2.new(1,-40,0,24),UDim2.fromOffset(20,46),12,color.muted)
    local close=button(panel,"×",UDim2.fromOffset(34,34),UDim2.new(1,-48,0,14));close.TextSize=24
    local content=make("ScrollingFrame",{Position=UDim2.fromOffset(20,82),Size=UDim2.new(1,-40,1,-102),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,ScrollBarImageColor3=color.accent},panel)
    make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},content)
    windows[id]={panel=panel,content=content}
    close.Activated:Connect(function()panel.Visible=false;shade.Visible=false end)
    return content
end
local inventoryContent=window("Inventory","INVENTORY","Crafting  /  Expandable inventory  /  Equipment")
local statsContent=window("Stats","PLAYER STATS","Definitive sources → defined values → dynamic resources")
local collectionsContent=window("Collections","COLLECTIONS & TALISMANS","Harvest totals / crafting and inventory transfers do not add collection credit")
local function show(id)
    local opening=not windows[id].panel.Visible
    for _,w in pairs(windows)do w.panel.Visible=false end
    windows[id].panel.Visible=opening;shade.Visible=opening
end
shade.Activated:Connect(function()for _,w in pairs(windows)do w.panel.Visible=false end;shade.Visible=false end)
inventoryButton.Activated:Connect(function()show("Inventory")end)
statsButton.Activated:Connect(function()show("Stats")end)
collectionsButton.Activated:Connect(function()show("Collections")end)
local function row(parent,left,right,order,tint)
    local card=make("Frame",{LayoutOrder=order,Size=UDim2.new(1,-8,0,36),BackgroundColor3=color.card},parent);round(card,7)
    text(card,left,UDim2.new(.64,-20,1,0),UDim2.fromOffset(12,0),13,tint)
    local value=text(card,right,UDim2.new(.36,-16,1,0),UDim2.new(.64,0,0,0),13,color.muted);value.TextXAlignment=Enum.TextXAlignment.Right
    return value
end
local function section(parent,title,order)
    local label=text(parent,title,UDim2.new(1,-8,0,28),UDim2.new(),12,color.accent)
    label.LayoutOrder=order;label.Font=Enum.Font.GothamBold
end
local collectionLabels={}
local collectionIds={};for id in pairs(collectionDefinitions)do table.insert(collectionIds,id)end;table.sort(collectionIds)
for i,id in ipairs(collectionIds)do
    collectionLabels[id]=row(collectionsContent,collectionDefinitions[id].name,"0 harvested",i)
end
local foragingXP=row(collectionsContent,"Foraging XP","0",10)
section(collectionsContent,"TALISMAN BAG — PASSIVE BONUSES",11)
local oakTalisman=row(collectionsContent,"Oak Talisman","Not collected",12)
local notification=text(gui,"",UDim2.new(.9,0,0,72),UDim2.new(.05,0,0,22),16,color.accent)
notification.TextWrapped=true;notification.TextXAlignment=Enum.TextXAlignment.Center
notification.BackgroundColor3=color.panel;notification.BackgroundTransparency=.1
notification.Visible=false;round(notification,10)
local notificationId=0
remotes.ResourceResult.OnClientEvent:Connect(function(ok,message)
    notificationId=notificationId+1;local id=notificationId
    notification.Text=message;notification.TextColor3=ok and color.accent or Color3.fromRGB(245,181,115)
    notification.Visible=true
    task.delay(5,function()if notificationId==id then notification.Visible=false end end)
end)
local statLabels={};local order=0
for _,group in ipairs({"definitive","defined","dynamic"})do
    order=order+1;section(statsContent,string.upper(group).." STATS",order)
    local keys={};for id in pairs(definitions[group])do table.insert(keys,id)end;table.sort(keys)
    for _,id in ipairs(keys)do order=order+1;statLabels[id]=row(statsContent,pretty(id),"—",order)end
end
windows.Inventory.panel:FindFirstChildOfClass("UISizeConstraint").MaxSize=Vector2.new(1120,650)
local weaponLabels={}
order=order+1;section(statsContent,"EQUIPPED WEAPON PROPERTIES",order)
for i=1,4 do order=order+1;weaponLabels[i]=row(statsContent,"Weapon "..i,"Empty",order)end
local renderInventory=require(script.Parent.InventoryUI).mount(inventoryContent,make,text,round,color,items,itemTypes,remotes)
local sprinting=false
local function setSprint(enabled)sprinting=enabled;remotes.SetSprinting:FireServer(enabled)end
sprint.Activated:Connect(function()setSprint(not sprinting)end)
UserInputService.InputBegan:Connect(function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.I then show("Inventory")
    elseif input.KeyCode==Enum.KeyCode.C then show("Stats")
    elseif input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then setSprint(true)
    elseif input.KeyCode==Enum.KeyCode.Escape then for _,w in pairs(windows)do w.panel.Visible=false end;shade.Visible=false end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then setSprint(false)end
end)
UserInputService.WindowFocusReleased:Connect(function()setSprint(false)end)
remotes.Snapshot.OnClientEvent:Connect(function(data)
    level.Text="VANILLA RPG  /  LEVEL "..string.format("%.2f",data.gameLevel)
    wallet.Text="Coins "..number(data.coins).."   ·   Bank "..number(data.bank)..(data.temporary and "   ·   TEST DATA" or "")
    defense.Text="DEFENSE  "..number(data.stats.Defense)
    for id,bar in pairs(bars)do
        local current,maximum=data.resources[id],data.stats[definitions.dynamic[id].maximum]
        bar.label.Text=string.upper(id).."   "..number(current).." / "..number(maximum)
        bar.fill.Size=UDim2.fromScale(maximum>0 and math.clamp(current/maximum,0,1) or 0,1)
    end
    for id,label in pairs(statLabels)do
        local definition=definitions.dynamic[id]
        if definition then label.Text=number(data.resources[id]).." / "..number(data.stats[definition.maximum])
        else label.Text=number(data.stats[id])..(definitions.definitive[id] and (" "..definitions.definitive[id].unit) or "")end
    end
    sprinting=data.sprinting;sprint.Text=sprinting and "SPRINT ON" or "SPRINT OFF"
    for i,label in ipairs(weaponLabels)do
        local instanceId=data.equipment['weapon'..i]
        local item=instanceId and data.equipmentItems[instanceId]
        local definition=item and items[item.itemId]
        label.Text=definition and (tostring(definition.baseDamage).." damage") or "Empty"
    end
    for id,label in pairs(collectionLabels)do label.Text=tostring((data.collections or {})[id]or 0).." harvested"end
    foragingXP.Text=tostring(data.skills.foraging.xp)
    local owned=(data.talismans or {}).oak_talisman
    local count=owned==true and 1 or (type(owned)=="table"and owned.count or 0)
    oakTalisman.Text=count>0 and (tostring(count).." owned · +5 fortune once")or "Not collected"
    renderInventory(data)
end)
remotes.RequestSnapshot:FireServer()
