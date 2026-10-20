-- Read-only inventory layout. Crafting/equipping actions are intentionally deferred.
local InventoryUI = {}
function InventoryUI.mount(content, make, text, round, color, items, itemTypes)
    for _,child in ipairs(content:GetChildren()) do child:Destroy() end
    content.AutomaticCanvasSize=Enum.AutomaticSize.None
    content.ScrollingDirection=Enum.ScrollingDirection.XY
    local root=make("Frame",{Name="InventoryLayout",Size=UDim2.fromOffset(1000,474),BackgroundTransparency=1},content)
    local scale=make("UIScale",{Scale=1},root)
    local function resize()
        local factor=math.clamp(content.AbsoluteSize.X/1000,.7,1)
        scale.Scale=factor
        root.Position=UDim2.fromOffset(math.max(0,(content.AbsoluteSize.X-1000*factor)/2),0)
        content.CanvasSize=UDim2.fromOffset(1000*factor,474*factor)
    end
    content:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
    local function panel(name,x,width)
        local p=make("Frame",{Name=name,Position=UDim2.fromOffset(x,0),Size=UDim2.fromOffset(width,430),BackgroundColor3=color.card},root)
        round(p,10)
        local title=text(p,string.upper(name),UDim2.new(1,-24,0,30),UDim2.fromOffset(12,10),13,color.accent)
        title.Font=Enum.Font.GothamBold
        return p
    end
    local crafting=panel("Crafting",0,210)
    local bag=panel("Inventory",222,422)
    local equipment=panel("Equipment",656,344)
    local status=text(root,"Select a slot to inspect it. Crafting and equipment actions are not enabled yet.",UDim2.fromOffset(984,36),UDim2.fromOffset(8,436),12,color.muted)
    status.TextWrapped=true
    local function slot(parent,name,x,y,size,caption)
        local b=make("TextButton",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),Text="",
            BackgroundColor3=color.panel,AutoButtonColor=true},parent)
        round(b,7);local border=make("UIStroke",{Color=color.line,Transparency=.25},b)
        local label=text(b,caption or "—",UDim2.new(1,-8,1,-8),UDim2.fromOffset(4,4),11,color.muted)
        label.TextWrapped=true;label.TextXAlignment=Enum.TextXAlignment.Center
        local quantity=text(b,"",UDim2.new(1,-8,0,14),UDim2.new(0,4,1,-17),10,color.accent)
        quantity.TextXAlignment=Enum.TextXAlignment.Right
        local detail=name.." · Empty"
        b.Activated:Connect(function()status.Text=detail end)
        return function(item,empty)
            local id=type(item)=="table" and (item.itemId or item.id) or item
            local title=id and (items[id] and items[id].name or tostring(id)) or nil
            label.Text=title or empty or "—"
            local definition=id and items[id]
            local rarity=definition and itemTypes.rarities[definition.rarity]
            local tint=rarity and Color3.fromRGB(table.unpack(rarity.color)) or color.line
            border.Color=tint
            label.TextColor3=title and (rarity and tint or color.text) or color.muted
            quantity.Text=type(item)=="table" and item.quantity and ("×"..tostring(item.quantity)) or ""
            detail=name.." · "..(title or "Empty")
            if definition then
                detail=detail.." · "..rarity.label.." · "..definition.kind
                if #definition.description>0 then detail=detail.." — "..definition.description end
            end
        end
    end
    local bagSlots={}
    for i=1,30 do
        local x,y=(i-1)%6,math.floor((i-1)/6)
        bagSlots[i]=slot(bag,"Slot "..i,16+x*66,52+y*66,60)
        local number=text(bag,tostring(i),UDim2.fromOffset(18,12),UDim2.fromOffset(20+x*66,55+y*66),9,color.muted)
        number.ZIndex=2
    end
    local count=text(bag,"0 / 30 slots occupied",UDim2.fromOffset(390,24),UDim2.fromOffset(16,390),12,color.muted)
    for i=1,9 do slot(crafting,"Crafting slot "..i,17+((i-1)%3)*60,64+math.floor((i-1)/3)*60,54) end
    text(crafting,"OUTPUT",UDim2.fromOffset(176,24),UDim2.fromOffset(17,258),11,color.muted)
    slot(crafting,"Crafting output",78,292,54,"Result")
    local hint=text(crafting,"3 × 3 recipe grid\nCrafting coming later",UDim2.fromOffset(176,48),UDim2.fromOffset(17,365),11,color.muted)
    hint.TextWrapped=true
    local groups={
        {"ARMOR",{"helmet","chestplate","gloves","leggings","boots"}},
        {"ACCESSORIES",{"brooch","artifact","ring","bracelet","necklace"}},
        {"TOOLS",{"hoe","pickaxe","axe","fishingRod"}},
        {"WEAPONS",{"weapon1","weapon2","weapon3","weapon4"}},
    }
    local equipped={}
    local function pretty(id)return id:gsub("(%l)(%u)","%1 %2"):gsub("(%a)(%d)","%1 %2"):gsub("^%l",string.upper)end
    for row,group in ipairs(groups) do
        local y=45+(row-1)*92
        text(equipment,group[1],UDim2.fromOffset(316,18),UDim2.fromOffset(14,y),10,color.muted)
        for col,id in ipairs(group[2]) do equipped[id]=slot(equipment,pretty(id),14+(col-1)*64,y+24,56,pretty(id)) end
    end
    local lastKey
    return function(data)
        local key=game:GetService("HttpService"):JSONEncode({data.inventory,data.equipment})
        if lastKey==key then return end;lastKey=key
        local occupied=0
        for i=1,30 do local item=data.inventory.slots[tostring(i)];bagSlots[i](item);if item then occupied=occupied+1 end end
        count.Text=occupied.." / 30 slots occupied"
        for id,update in pairs(equipped)do update(data.equipment[id],pretty(id)) end
    end
end
return InventoryUI
