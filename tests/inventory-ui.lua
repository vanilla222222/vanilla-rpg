-- Real InventoryUI controller driven by GUI/remote adapters, not a Roblox renderer.
return function(test,equal,rejects)
    test('inventory clicks equip/unequip through server and hover exposes item data',function()
        local util=dofile('src/shared/TableUtil.lua')
        local definitions=dofile('src/shared/StatDefinitions.lua')
        local types=dofile('src/shared/ItemTypes.lua')
        local catalog=dofile('src/shared/ItemCatalog.lua').create(dofile('src/shared/ItemDefinitions.lua'),types,definitions,util)
        local originals={};local names={'Enum','Color3','ColorSequence','ColorSequenceKeypoint','UDim','UDim2','Vector2','game','script','require'}
        for _,name in ipairs(names)do originals[name]=_G[name]end
        local oldClamp,oldAtan=math.clamp,math.atan2
        local ok,problem=pcall(function()
            math.clamp=function(x,a,b)return math.max(a,math.min(b,x))end
            math.atan2=math.atan2 or function(y,x)return math.atan(y,x)end
            local function event()
                local callbacks={}
                return {Connect=function(_,fn)table.insert(callbacks,fn)end,Fire=function(_,...)for _,fn in ipairs(callbacks)do fn(...)end end}
            end
            Enum=setmetatable({},{__index=function(_,key)return setmetatable({},{__index=function(_,id)return key..'.'..id end})end})
            local function tint(r,g,b)return {R=r,G=g,B=b,Lerp=function(self,other,t)return tint(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t)end}end
            Color3={fromRGB=tint}
            ColorSequence={new=function(value)return value end};ColorSequenceKeypoint={new=function(a,b)return {a,b}end}
            UDim={new=function(a,b)return {a,b}end}
            UDim2={new=function(...)return {...}end,fromOffset=function(x,y)return {x,y}end,fromScale=function(x,y)return {x,y}end}
            Vector2={new=function(x,y)return {X=x,Y=y}end}
            game={GetService=function(_,name)assert(name=='HttpService');return {JSONEncode=function(_,data)return tostring(data)end}end}
            script={Parent={ItemIcons='icons',ItemTooltip='tooltip'}}
            local hover={}
            local tooltip={show=function(button,item,rarity,action)hover={button=button,item=item,rarity=rarity,action=action}end,
                hide=function(button)if not button or hover.button==button then hover={}end end}
            local icons=dofile('src/client/ItemIcons.lua')
            require=function(path)if path=='icons'then return icons elseif path=='tooltip'then return {mount=function()return tooltip end}end;error('Unexpected dependency')end
            local objects={}
            local function make(kind,props,parent)
                local obj={ClassName=kind,children={},attributes={},AbsoluteSize={X=1080,Y=550},Parent=parent}
                for key,value in pairs(props)do obj[key]=value end
                for _,id in ipairs({'Activated','MouseEnter','MouseLeave','SelectionGained','SelectionLost'})do obj[id]=event()end
                function obj:GetChildren()return self.children end
                function obj:GetPropertyChangedSignal()return event()end
                function obj:SetAttribute(key,value)self.attributes[key]=value end
                function obj:Destroy()self.destroyed=true;self.Parent=nil end
                if parent then table.insert(parent.children,obj)end
                table.insert(objects,obj);return obj
            end
            local function text(parent,value,size,position,fontSize,color)return make('TextLabel',{Text=value,Size=size,Position=position,TextSize=fontSize,TextColor3=color},parent)end
            local color={panel=tint(19,27,39),card=tint(29,40,55),line=tint(58,76,97),text=tint(234,241,249),muted=tint(153,173,195),accent=tint(92,220,190)}
            local content=make('ScrollingFrame',{},make('Frame',{Visible=true}))
            local render
            local profile=dofile('src/server/Profile.lua').create(util)
            local service
            local holder={}
            service=dofile('src/server/PlayerService.lua').new(profile,dofile('src/server/Stats.lua'),definitions,util,function()return 100 end,
                function()if render then render(holder.service.snapshot(1))end end,dofile('src/server/Resources.lua'),dofile('src/server/Equipment.lua').create(catalog,util))
            holder.service=service
            local data=profile.prepare(nil,100);dofile('src/server/StarterItems.lua').grant(data,1)
            service.attach(1,{data=data,expiresAt=1000})
            local result=event();local remotes={EquipmentResult={OnClientEvent=result}}
            remotes.Equipment={FireServer=function(_,action,slot,target)
                local success,reason=pcall(service.changeEquipment,1,action,slot,target)
                result:Fire(success,success and 'Equipment updated' or tostring(reason))
                assert(success,tostring(reason))
            end}
            render=dofile('src/client/InventoryUI.lua').mount(content,make,text,function()end,color,catalog.all(),types,remotes)
            render(service.snapshot(1))
            local function find(parent,name)
                for _,o in ipairs(objects)do if o.Name==name and (not parent or o.Parent==parent)then return o end end
                error('Missing '..name)
            end
            local bag=find(nil,'Inventory');local slot=find(bag,'Slot 1')
            slot.MouseEnter:Fire();equal(hover.item.name,'Starter Axe');assert(#hover.item.description>0)
            equal(hover.item.stats.Sweep.flat,1);equal(hover.rarity.label,'Common');equal(slot.attributes.Rarity,'common')
            assert(slot.BackgroundColor3.R~=color.panel.R)
            slot.MouseLeave:Fire();equal(hover.item,nil)
            slot.Activated:Fire();equal(service.snapshot(1).stats.Sweep,1)
            local equipped=find(nil,'Equipment');local axe=find(equipped,'Axe')
            axe.MouseEnter:Fire();equal(hover.item.name,'Starter Axe');equal(hover.action,'Click to unequip')
            axe.Activated:Fire();equal(service.snapshot(1).stats.Sweep,0)
            for i=1,5 do find(bag,'Slot '..i).Activated:Fire()end
            equal(service.snapshot(1).stats.MiningSpeed,10);equal(service.snapshot(1).stats.FarmingFortune,105)
            assert(service.snapshot(1).equipment.weapon1)
            local iconCount=0
            for _,o in ipairs(objects)do if o.Name=='ItemIcon' and not o.destroyed then iconCount=iconCount+1 end end
            assert(iconCount>=5,'Starter icons must render through the actual icon module')
        end)
        for _,name in ipairs(names)do _G[name]=originals[name]end
        math.clamp,math.atan2=oldClamp,oldAtan
        assert(ok,problem)
    end)
    test('hover stat formatting includes item damage and modifier operations',function()
        local p=dofile('src/shared/ItemPresentation.lua')
        local text=p.stats({baseDamage=5,stats={MiningSpeed={flat=10},MiningFortune={percent=.25,multiplier=2}}})
        assert(text:find('Damage  5',1,true));assert(text:find('Mining Speed  +10',1,true))
        assert(text:find('+25%',1,true));assert(text:find('×2',1,true))
        equal(p.stats({stats={}}),'No stat bonuses')
    end)
end
