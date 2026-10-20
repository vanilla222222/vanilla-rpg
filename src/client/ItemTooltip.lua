local Tooltip={}
function Tooltip.mount(content,make,text,round,color)
    local Players=game:GetService('Players')
    local Input=game:GetService('UserInputService')
    local RunService=game:GetService('RunService')
    local presentation=require(game:GetService('ReplicatedStorage').Shared.ItemPresentation)
    local overlay=make('ScreenGui',{Name='ItemHover',ResetOnSpawn=false,DisplayOrder=100,IgnoreGuiInset=true},Players.LocalPlayer:WaitForChild('PlayerGui'))
    local frame=make('Frame',{Name='Tooltip',Visible=false,Size=UDim2.fromOffset(288,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=color.panel,BorderSizePixel=0,Active=false},overlay)
    round(frame,10)
    local stroke=make('UIStroke',{Color=color.line,Thickness=1.5},frame)
    make('UIPadding',{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},frame)
    make('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},frame)
    local function line(order,size,tint)
        local label=text(frame,'',UDim2.new(1,0,0,0),UDim2.new(),size,tint)
        label.LayoutOrder=order;label.TextWrapped=true;label.AutomaticSize=Enum.AutomaticSize.Y
        label.TextYAlignment=Enum.TextYAlignment.Top
        return label
    end
    local title=line(1,17,color.text);title.Font=Enum.Font.GothamBold
    local kind=line(2,11,color.muted)
    local description=line(3,13,color.text)
    local stats=line(4,13,color.accent)
    local hint=line(5,11,color.muted)
    local owner
    local api={}
    function api.hide(button)
        if button==nil or owner==button then owner=nil;frame.Visible=false end
    end
    function api.show(button,item,rarity,action)
        if not item then api.hide();return end
        owner=button;frame.Visible=true
        local tint=Color3.fromRGB(table.unpack(rarity.color))
        title.Text,title.TextColor3=item.name,tint;stroke.Color=tint
        kind.Text=string.upper(rarity.label)..'  /  '..presentation.pretty(item.kind)
        description.Text=#item.description>0 and item.description or 'No description available.'
        stats.Text=presentation.stats(item)
        hint.Text=action or 'Inspect item'
    end
    RunService.RenderStepped:Connect(function()
        if not owner then return end
        if not content.Parent.Visible or not owner.Parent then api.hide();return end
        local camera=workspace.CurrentCamera;if not camera then return end
        local view=camera.ViewportSize
        frame.Size=UDim2.fromOffset(math.min(288,math.max(160,view.X-24)),0)
        local position=Input:GetMouseLocation()
        local x,y=position.X+18,position.Y+16
        if x+frame.AbsoluteSize.X>view.X-12 then x=position.X-frame.AbsoluteSize.X-18 end
        frame.Position=UDim2.fromOffset(math.max(12,math.min(x,view.X-frame.AbsoluteSize.X-12)),math.max(12,math.min(y,view.Y-frame.AbsoluteSize.Y-12)))
    end)
    return api
end
return Tooltip
