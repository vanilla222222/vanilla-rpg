-- Small engine adapter drives the real node controller. Not a Roblox simulation.
return function(test,equal)
    local function fixture(resourceId)
        resourceId=resourceId or 'oak'
        local definition=dofile('src/shared/ResourceDefinitions.lua')[resourceId]
        assert(definition,'Missing fixture resource definition')
        local now=100
        local function signal()
            local callbacks={};local event={}
            function event:Connect(fn)
                local connection={connected=true}
                function connection:Disconnect()self.connected=false end
                table.insert(callbacks,{fn=fn,connection=connection});return connection
            end
            function event:Fire(...)
                for _,entry in ipairs(callbacks)do if entry.connection.connected then entry.fn(...)end end
            end
            return event
        end
        local function object(kind,name,parent)
            local value={kind=kind,Name=name,Parent=parent,Anchored=true,children={},DescendantAdded=signal(),AncestryChanged=signal()}
            if parent then table.insert(parent.children,value)end
            function value:IsA(k)return self.kind==k or (k=='BasePart'and self.kind=='Part')end
            function value:IsDescendantOf(ancestor)
                local node=self.Parent;while node do if node==ancestor then return true end;node=node.Parent end;return false
            end
            function value:FindFirstChild(name,recursive)
                for _,child in ipairs(self.children)do if child.Name==name then return child end end
                if recursive then for _,child in ipairs(self.children)do local found=child:FindFirstChild(name,true);if found then return found end end end
            end
            function value:FindFirstChildWhichIsA(k,recursive)
                for _,child in ipairs(self.children)do if child:IsA(k)then return child end end
                if recursive then for _,child in ipairs(self.children)do local found=child:FindFirstChildWhichIsA(k,true);if found then return found end end end
            end
            function value:FindFirstChildOfClass(k)return self:FindFirstChildWhichIsA(k)end
            function value:GetDescendants()
                local result={};for _,child in ipairs(self.children)do table.insert(result,child);for _,descendant in ipairs(child:GetDescendants())do table.insert(result,descendant)end end;return result
            end
            function value:Destroy()self.destroyed=true;self.Parent=nil end
            return value
        end
        local vector={};vector.__index=vector
        function vector.__sub(a,b)return {Magnitude=math.abs(a.x-b.x)}end
        local function position(x)return setmetatable({x=x},vector)end
        local root=object('Folder','ResourceInteractions')
        local foraging=object('Folder','foraging',root);local oak=object('Folder',definition.path[2],foraging)
        local tree=object('Model','Tree',oak);local trunk=object('Part','InteractionPart',tree);trunk.Position=position(4)
        local crown=object('Model','Crown',tree);object('Part','Leaf',crown).Position=position(5)
        local branches=object('Folder','Branches',tree)
        object('Part','Branch',branches).Position=position(5)
        local character=object('Model','Character')
        local humanoid=object('Humanoid','Humanoid',character);humanoid.Health=100
        local body=object('Part','HumanoidRootPart',character);body.Position=position(0)
        local player={UserId=1,Character=character}
        local players={PlayerRemoving=signal()}
        local world={};function world:Raycast()return self.hit end
        local prompts={};local service={active=function()return true end};local harvests=0;local problem
        function service.harvestResource()
            if problem then error(problem)end
            harvests=harvests+1;return {xp=definition.baseXP,loot={{itemId=definition.loot[1].itemId,quantity=1}}}
        end
        local messages={};local remote={FireClient=function(_,p,ok,message)table.insert(messages,{p=p,ok=ok,message=message})end}
        local env=setmetatable({game={GetService=function(_,id)if id=='Players'then return players else return world end end},
            Random={new=function()return {NextNumber=function()return .5 end}end},
            Instance={new=function(k)local p=object(k,k);p.PromptButtonHoldBegan=signal();p.Triggered=signal();table.insert(prompts,p);return p end},
            RaycastParams={new=function()return {}end},Enum={RaycastFilterType={Exclude=1},KeyCode={E='E'}},
            task={defer=function(fn,...)fn(...)end},os={clock=function()return now end},warn=function()end},{__index=_G})
        local nodes=assert(loadfile('src/server/ResourceNodes.lua','t',env))()
        nodes.start(root,service,{[resourceId]=definition},remote,{get=function()return {name=resourceId=='raspberry'and 'Raspberry' or 'Oak Wood'}end})
        return {prompts=prompts,player=player,players=players,body=body,humanoid=humanoid,world=world,tree=tree,trunk=trunk,oak=oak,messages=messages,
            object=object,position=position,step=function(seconds)now=now+seconds end,count=function()return harvests end,
            fail=function(value)problem=value end}
    end
    test('placed models bind once including nested models and live additions',function()
        local f=fixture();equal(#f.prompts,1);equal(f.prompts[1].Parent,f.trunk)
        local model=f.object('Model','New tree',f.oak);f.oak.DescendantAdded:Fire(model)
        equal(#f.prompts,1)
        local part=f.object('Part','Trunk',model);part.Position=f.position(4);f.oak.DescendantAdded:Fire(part)
        equal(#f.prompts,2);f.oak.DescendantAdded:Fire(part);equal(#f.prompts,2)
        model.Parent=f.tree;model.AncestryChanged:Fire();assert(f.prompts[2].destroyed)
        equal(#f.prompts,2) -- Regrouping does not leave a separate inner-tree node.
        f.tree.Parent=nil;f.tree.AncestryChanged:Fire();assert(f.prompts[1].destroyed)
    end)
    test('server rejects instant, distant, dead and obstructed tree interactions',function()
        local f=fixture();local p=f.prompts[1]
        p.Triggered:Fire(f.player);equal(f.count(),0)
        p.PromptButtonHoldBegan:Fire(f.player);p.Triggered:Fire(f.player);equal(f.count(),0)
        f.body.Position=f.position(40);p.PromptButtonHoldBegan:Fire(f.player);f.step(1);p.Triggered:Fire(f.player);equal(f.count(),0)
        f.body.Position=f.position(0);f.humanoid.Health=0;p.PromptButtonHoldBegan:Fire(f.player);f.step(1);p.Triggered:Fire(f.player);equal(f.count(),0)
        f.humanoid.Health=100;f.world.hit={Instance=f.object('Part','Wall')}
        p.PromptButtonHoldBegan:Fire(f.player);f.step(1);p.Triggered:Fire(f.player);equal(f.count(),0)
        f.world.hit=nil;f.trunk.Anchored=false;p.PromptButtonHoldBegan:Fire(f.player);f.step(1);p.Triggered:Fire(f.player);equal(f.count(),0)
        f.trunk.Anchored=true;f.world.hit={Instance=f.trunk};p.PromptButtonHoldBegan:Fire(f.player);f.step(1);p.Triggered:Fire(f.player)
        equal(f.count(),1);assert(f.messages[1].ok)
    end)
    test('successful harvest cooldown is per player and cleared on leaving',function()
        local f=fixture();local p=f.prompts[1]
        local function harvest(player)p.PromptButtonHoldBegan:Fire(player);f.step(1);p.Triggered:Fire(player)end
        harvest(f.player);harvest(f.player);equal(f.count(),1);assert(not f.messages[2].ok)
        harvest({UserId=2,Character=f.player.Character});equal(f.count(),2)
        f.step(10);harvest(f.player);equal(f.count(),3)
        f.players.PlayerRemoving:Fire(f.player);harvest(f.player);equal(f.count(),4)
    end)
    test('failed full-bag harvest reports an error without starting cooldown',function()
        local f=fixture();local p=f.prompts[1]
        f.fail('Inventory is full');p.PromptButtonHoldBegan:Fire(f.player);f.step(1);p.Triggered:Fire(f.player)
        equal(f.count(),0);assert(not f.messages[1].ok);assert(f.messages[1].message:find('room'))
        f.fail(nil);p.PromptButtonHoldBegan:Fire(f.player);f.step(1);p.Triggered:Fire(f.player);equal(f.count(),1)
    end)
    test('quick-press raspberry bush harvest needs no hold and regenerates after cooldown',function()
        local f=fixture('raspberry');local p=f.prompts[1]
        equal(p.HoldDuration,0);equal(p.KeyboardKeyCode,'E');equal(p.ActionText,'Pick')
        p.Triggered:Fire(f.player);equal(f.count(),1);assert(f.messages[1].ok)
        -- A rapid repeated keypress cannot create another harvest.
        p.Triggered:Fire(f.player);equal(f.count(),1)
        f.step(.25);p.Triggered:Fire(f.player);equal(f.count(),1)
        assert(not f.messages[2].ok);assert(f.messages[2].message:find('Raspberry Bush is regrowing',1,true))
        f.step(14.5);p.Triggered:Fire(f.player);equal(f.count(),1)
        f.step(.25);p.Triggered:Fire(f.player);equal(f.count(),2);assert(f.messages[#f.messages].ok)
    end)
    test('quick-press bushes retain server distance, health, anchoring and visibility checks',function()
        local f=fixture('raspberry');local p=f.prompts[1]
        f.body.Position=f.position(40);p.Triggered:Fire(f.player);equal(f.count(),0)
        f.body.Position=f.position(0);f.humanoid.Health=0;p.Triggered:Fire(f.player);equal(f.count(),0)
        f.humanoid.Health=100;f.trunk.Anchored=false;p.Triggered:Fire(f.player);equal(f.count(),0)
        f.trunk.Anchored=true;f.world.hit={Instance=f.object('Part','Wall')}
        p.Triggered:Fire(f.player);equal(f.count(),0)
        f.world.hit=nil;p.Triggered:Fire(f.player);equal(f.count(),1)
    end)

end
