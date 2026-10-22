-- Binds placed Studio models to server-authoritative gathering. No client reward payloads.
local ResourceNodes={}
function ResourceNodes.start(root,service,definitions,resultEvent,catalog)
    local Players=game:GetService('Players')
    local world=game:GetService('Workspace')
    local random=Random.new()
    local registered,attempts={},{}
    local function message(player,ok,value)resultEvent:FireClient(player,ok,value)end
    for id,definition in pairs(definitions)do
        local folder=root
        for _,name in ipairs(definition.path)do folder=folder and folder:FindFirstChild(name)end
        if not folder then warn('Resource folder missing: '..table.concat(definition.path,'/'))
        else
            -- Models are single nodes; folders may organize multiple models or individual parts.
            local function nodeFor(object)
                local node=object
                while node and node.Parent~=folder do
                    if not node.Parent then return nil end
                    if node.Parent:IsA('Model')then node=node.Parent
                    elseif node.Parent:IsA('Folder')then
                        if node:IsA('Model') or node:IsA('BasePart')then return node end
                        return nil
                    else node=node.Parent end
                end
                if node and (node:IsA('Model')or node:IsA('BasePart'))then return node end
            end
            local function bind(object)
                local node=nodeFor(object)
                if not node or registered[node]then return end
                local part=node:IsA('BasePart')and node or node:FindFirstChild('InteractionPart',true)
                if part and not part:IsA('BasePart')then part=nil end
                part=part or node.PrimaryPart or node:FindFirstChildWhichIsA('BasePart',true)
                if not part then return end -- A later descendant event retries empty models.
                local prompt=Instance.new('ProximityPrompt')
                prompt.Name='ResourcePrompt';prompt.ActionText='Harvest';prompt.ObjectText=definition.name
                prompt.HoldDuration=definition.holdSeconds;prompt.MaxActivationDistance=definition.distance
                prompt.RequiresLineOfSight=true
                local holds,cooldowns,connections={},{},{}
                registered[node]=connections
                local function valid(player)
                    if not service.active(player.UserId)or not folder:IsDescendantOf(root)or not part.Anchored or not node:IsDescendantOf(folder)or not part:IsDescendantOf(node==part and folder or node)then return false end
                    local character=player.Character
                    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
                    local body=character and character:FindFirstChild('HumanoidRootPart')
                    if not humanoid or humanoid.Health<=0 or not body or not body:IsA('BasePart')then return false end
                    local offset=part.Position-body.Position
                    if offset.Magnitude>definition.distance+1 then return false end
                    local parameters=RaycastParams.new();parameters.FilterType=Enum.RaycastFilterType.Exclude
                    parameters.FilterDescendantsInstances={character}
                    local hit=world:Raycast(body.Position,offset,parameters)
                    return not hit or hit.Instance==node or hit.Instance:IsDescendantOf(node)
                end
                connections[#connections+1]=prompt.PromptButtonHoldBegan:Connect(function(player)
                    holds[player]=nil
                    if valid(player)then holds[player]=os.clock()end
                end)
                connections[#connections+1]=prompt.Triggered:Connect(function(player)
                    local now=os.clock();local began=holds[player];holds[player]=nil
                    if not began or now-began<definition.holdSeconds-.1 or now-began>definition.holdSeconds+3 or not valid(player)then return end
                    if now-(attempts[player]or -math.huge)<.25 then return end
                    attempts[player]=now
                    if now<(cooldowns[player]or 0)then
                        message(player,false,'This tree is recovering. Try again in '..math.ceil(cooldowns[player]-now)..'s.');return
                    end
                    local ok,reward=pcall(service.harvestResource,player.UserId,id,function()return random:NextNumber()end)
                    if ok then
                        cooldowns[player]=now+definition.cooldownSeconds
                        local drops={}
                        for _,drop in ipairs(reward.loot)do table.insert(drops,drop.quantity..' '..catalog.get(drop.itemId).name)end
                        message(player,true,table.concat(drops,', ')..'  ·  +'..reward.xp..' '..definition.skill..' XP')
                    else
                        local raw=tostring(reward)
                        if raw:find('Inventory is full',1,true)then message(player,false,'Make room for all possible oak drops before harvesting.')
                        elseif raw:find('required tool',1,true)then message(player,false,'Equip an axe in your inventory first.')
                        elseif raw:find('cannot harvest',1,true)then message(player,false,'Your axe is not strong enough for this tree.')
                        else warn('Resource harvest failed: '..raw);message(player,false,'Harvest could not complete safely. Try again.')end
                    end
                end)
                connections[#connections+1]=Players.PlayerRemoving:Connect(function(player)holds[player]=nil;cooldowns[player]=nil end)
                local function clean()
                    for _,connection in ipairs(connections)do connection:Disconnect()end
                    registered[node]=nil;prompt:Destroy()
                end
                connections[#connections+1]=node.AncestryChanged:Connect(function()
                    if not node:IsDescendantOf(folder)then clean()end
                end)
                connections[#connections+1]=part.AncestryChanged:Connect(function()
                    if node~=part and not part:IsDescendantOf(node)then clean();task.defer(bind,node)end
                end)
                prompt.Parent=part
            end
            folder.DescendantAdded:Connect(function(object)
                if object:IsA('Model')or object:IsA('BasePart')then task.defer(bind,object)end
            end)
            for _,object in ipairs(folder:GetDescendants())do bind(object)end
        end
    end
    Players.PlayerRemoving:Connect(function(player)attempts[player]=nil end)
end
return ResourceNodes
