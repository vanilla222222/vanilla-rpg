-- Inventory and equipment controls; crafting remains a visual placeholder.
local InventoryUI = {}
function InventoryUI.mount(content, make, text, round, color, items, itemTypes, remotes, textures)
    textures=textures or {}
    for _,child in ipairs(content:GetChildren()) do child:Destroy() end
    content.AutomaticCanvasSize=Enum.AutomaticSize.None
    content.ScrollingDirection=Enum.ScrollingDirection.XY
    local root=make("Frame",{Name="InventoryLayout",Size=UDim2.fromOffset(1000,500),BackgroundTransparency=1},content)
    local scale=make("UIScale",{Scale=1},root)
    local function resize()
        local factor=math.clamp(content.AbsoluteSize.X/1000,.7,1)
        scale.Scale=factor
        root.Position=UDim2.fromOffset(math.max(0,(content.AbsoluteSize.X-1000*factor)/2),0)
        content.CanvasSize=UDim2.fromOffset(1000*factor,500*factor)
    end
    content:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
    local function panel(name,x,width)
        local p=make("Frame",{Name=name,Position=UDim2.fromOffset(x,0),Size=UDim2.fromOffset(width,456),BackgroundColor3=color.card},root)
        round(p,10)
        local title=text(p,string.upper(name),UDim2.new(1,-24,0,30),UDim2.fromOffset(12,10),13,color.accent)
        title.Font=Enum.Font.GothamBold
        return p
    end
    local crafting=panel("Crafting",0,210)
    local bag=panel("Inventory",222,422)
    local equipment=panel("Equipment",656,344)
    local status=text(root,"Click an item to equip it. Click equipped gear to unequip. Hover for details.",UDim2.fromOffset(984,36),UDim2.fromOffset(8,462),12,color.muted)
    status.TextWrapped=true
    local selectedBag,selectedEquipment
    local mode,page,picked,latest='equip',1,nil,nil
    local render,lastKey
    remotes.InventoryResult.OnClientEvent:Connect(function(ok,message)
        picked=nil;status.Text=message
    end)
    remotes.EquipmentResult.OnClientEvent:Connect(function(ok,message)
        status.Text=message
        if ok then selectedBag,selectedEquipment=nil,nil end
    end)
    local Images=require(script.Parent.ItemImages)
    local tooltip=require(script.Parent.ItemTooltip).mount(content,make,text,round,color)
    local function slot(parent,name,x,y,size,caption,selection)
        local b=make("TextButton",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),Text="",
            BackgroundColor3=color.panel,AutoButtonColor=true},parent)
        round(b,7);local border=make("UIStroke",{Color=color.line,Transparency=.25},b)
        local label=text(b,caption or "—",UDim2.new(1,-8,1,-8),UDim2.fromOffset(4,4),11,color.muted)
        label.TextWrapped=true;label.TextXAlignment=Enum.TextXAlignment.Center
        local quantity=text(b,"",UDim2.new(1,-8,0,14),UDim2.new(0,4,1,-17),10,color.accent)
        quantity.TextXAlignment=Enum.TextXAlignment.Right
        local detail=name.." · Empty"
        local hoverItem,hoverRarity
        local function showTooltip()
            local canEquip=hoverItem and not hoverItem.stackable and hoverItem.kind~="talisman"
            local action=parent==bag and mode~="equip" and "Select source, then destination" or parent==bag and canEquip and "Click to equip" or parent==equipment and "Click to unequip" or "Inspect item"
            tooltip.show(b,hoverItem,hoverRarity,action)
        end
        b.MouseEnter:Connect(showTooltip)
        b.MouseLeave:Connect(function()tooltip.hide(b)end)
        b.SelectionGained:Connect(showTooltip)
        b.SelectionLost:Connect(function()tooltip.hide(b)end)
        b.Activated:Connect(function()
            status.Text=detail
            if selection and selection()then tooltip.hide(b);return end
            tooltip.hide(b)
            if hoverItem and parent==bag and not hoverItem.stackable and hoverItem.kind~="talisman" then
                remotes.Equipment:FireServer("equip",selectedBag,nil,latest and latest.inventory.revision)
            elseif hoverItem and parent==equipment then
                remotes.Equipment:FireServer("unequip",selectedEquipment,nil,latest and latest.inventory.revision)
            end
        end)
        local icon
        return function(item,empty)
            tooltip.hide(b)
            local id=type(item)=="table" and (item.itemId or item.id) or item
            local title=id and (items[id] and items[id].name or tostring(id)) or nil
            if icon then icon:Destroy();icon=nil end
            if id then icon=Images.draw(b,textures[id],make)end
            if icon then
                label.Position=UDim2.new(0,4,1,-20);label.Size=UDim2.new(1,-8,0,18)
                label.TextSize=9;label.Text=title
            else
                label.Position=UDim2.fromOffset(4,4);label.Size=UDim2.new(1,-8,1,-8)
                label.TextSize=11;label.Text=title or empty or "—"
            end
            local definition=id and items[id]
            local rarity=definition and itemTypes.rarities[definition.rarity]
            local tint=rarity and Color3.fromRGB(table.unpack(rarity.color)) or color.line
            hoverItem,hoverRarity=definition,rarity
            border.Color=tint
            border.Transparency=rarity and 0 or .25
            border.Thickness=rarity and 2 or 1
            b.BackgroundColor3=rarity and color.panel:Lerp(tint,.24) or color.panel
            b:SetAttribute("Rarity",definition and definition.rarity or "empty")
            label.TextColor3=title and (rarity and tint or color.text) or color.muted
            quantity.Text=type(item)=="table" and type(item.quantity)=="number" and item.quantity>1 and ("×"..tostring(item.quantity)) or ""
            detail=name.." · "..(title or "Empty")
            if definition then
                detail=detail.." · "..rarity.label.." · "..definition.kind
                if definition.baseDamage then detail=detail.." · Damage "..definition.baseDamage end
                local bonuses={}
                for stat,change in pairs(definition.stats)do
                    local parts={}
                    if change.flat then table.insert(parts,string.format("%+g",change.flat))end
                    if change.percent then table.insert(parts,string.format("%+g%%",100*change.percent))end
                    if change.multiplier then table.insert(parts,"×"..change.multiplier)end
                    table.insert(bonuses,stat.." "..table.concat(parts," "))
                end
                table.sort(bonuses)
                if #bonuses>0 then detail=detail.." · "..table.concat(bonuses,", ")end
                if #definition.description>0 then detail=detail.." — "..definition.description end
            end
        end
    end
    local modeButtons={}
    for i,entry in ipairs({{'equip','Equip'},{'move','Move / Swap'},{'split','Split half'},{'merge','Merge'}})do
        local id,label=entry[1],entry[2]
        local button=make('TextButton',{Name='Mode_'..id,Text=label,Position=UDim2.fromOffset(16+(i-1)*100,44),Size=UDim2.fromOffset(90,26),
            Font=Enum.Font.GothamBold,TextSize=11,TextColor3=color.text,BackgroundColor3=color.panel},bag);round(button,5)
        modeButtons[id]=button
        button.Activated:Connect(function()
            mode,picked=id,nil
            for key,control in pairs(modeButtons)do control.BackgroundColor3=key==mode and color.panel:Lerp(color.accent,.35) or color.panel end
            status.Text=mode=='equip' and 'Click bag gear to equip; click equipped gear to unequip.' or 'Select a source item, then a destination slot.'
        end)
    end
    modeButtons.equip.BackgroundColor3=color.panel:Lerp(color.accent,.35)
    local previous=make('TextButton',{Name='PreviousPage',Text='‹',Position=UDim2.fromOffset(242,10),Size=UDim2.fromOffset(32,28),BackgroundColor3=color.panel,TextColor3=color.text,TextSize=20},bag)
    local pageLabel=text(bag,'1 / 1',UDim2.fromOffset(92,28),UDim2.fromOffset(278,10),11,color.muted)
    local nextPage=make('TextButton',{Name='NextPage',Text='›',Position=UDim2.fromOffset(374,10),Size=UDim2.fromOffset(32,28),BackgroundColor3=color.panel,TextColor3=color.text,TextSize=20},bag)
    round(previous,5);round(nextPage,5)
    local function changePage(delta)
        if not latest then return end
        page=math.clamp(page+delta,1,math.ceil(latest.inventory.capacity/30))
        lastKey=nil;render(latest)
    end
    previous.Activated:Connect(function()changePage(-1)end)
    nextPage.Activated:Connect(function()changePage(1)end)
    local bagSlots,slotNumbers={},{}
    for i=1,30 do
        local x,y=(i-1)%6,math.floor((i-1)/6)
        bagSlots[i]=slot(bag,"Slot "..i,16+x*66,84+y*66,60,nil,function()
            local key=tostring((page-1)*30+i)
            if not latest or tonumber(key)>latest.inventory.capacity then return true end
            selectedBag=key;selectedEquipment=nil
            if mode=='equip'then return false end
            if not picked then
                local item=latest.inventory.slots[key]
                if not item then status.Text='Choose a non-empty source slot.';return true end
                if mode=='split' and (type(item)~='table' or type(item.quantity)~='number' or item.quantity<2)then status.Text='Choose a stack containing at least two items.';return true end
                picked={slot=key,revision=latest.inventory.revision}
                status.Text='Source slot '..key..' selected. Choose the destination, including on another page.'
            elseif picked.slot==key then picked=nil;status.Text='Selection cancelled.'
            else
                local source=picked;local amount
                if mode=='split'then
                    local item=latest.inventory.slots[source.slot]
                    if type(item)~='table' or type(item.quantity)~='number' then picked=nil;status.Text='Inventory changed. Select the item again.';return true end
                    amount=math.floor(item.quantity/2)
                end
                picked=nil
                remotes.Inventory:FireServer(mode,source.slot,key,amount,source.revision)
            end
            return true
        end)
        -- The slot buttons themselves are stable across pages; only their records change.
        slotNumbers[i]=text(bag,tostring(i),UDim2.fromOffset(28,12),UDim2.fromOffset(20+x*66,87+y*66),9,color.muted)
        slotNumbers[i].ZIndex=2
    end
    local count=text(bag,"0 / 30 slots occupied",UDim2.fromOffset(390,24),UDim2.fromOffset(16,420),12,color.muted)
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
        for col,id in ipairs(group[2]) do equipped[id]=slot(equipment,pretty(id),14+(col-1)*64,y+24,56,pretty(id),function()selectedEquipment=id end) end
    end
    render=function(data)
        latest=data
        if picked and picked.revision~=data.inventory.revision then picked=nil;status.Text='Inventory changed. Select the source again.'end
        local pages=math.ceil(data.inventory.capacity/30);page=math.clamp(page,1,pages)
        local key=tostring(page)..':'..game:GetService("HttpService"):JSONEncode({data.inventory,data.equipment,data.equipmentItems})
        if lastKey==key then return end;lastKey=key
        local occupied=0
        for _ in pairs(data.inventory.slots)do occupied=occupied+1 end
        for i=1,30 do
            local index=(page-1)*30+i
            local item=index<=data.inventory.capacity and data.inventory.slots[tostring(index)] or nil
            bagSlots[i](item,index>data.inventory.capacity and 'Locked' or nil)
            slotNumbers[i].Text=tostring(index)
        end
        pageLabel.Text=page..' / '..pages
        count.Text=occupied..' / '..data.inventory.capacity..' slots occupied'

        for id,update in pairs(equipped)do update(data.equipment[id] and data.equipmentItems[data.equipment[id]] or nil,pretty(id)) end
    end
    return render
end
return InventoryUI
