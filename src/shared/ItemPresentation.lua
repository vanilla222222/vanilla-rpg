-- Shared item text formatting; no gameplay authority.
local Presentation={}
function Presentation.pretty(id)return id:gsub('(%l)(%u)','%1 %2'):gsub('^%l',string.upper)end
function Presentation.stats(item)
    local lines={}
    if item.baseDamage then table.insert(lines,'Damage  '..tostring(item.baseDamage))end
    local ids={};for id in pairs(item.stats or {})do table.insert(ids,id)end;table.sort(ids)
    for _,id in ipairs(ids)do
        local change=item.stats[id];local parts={}
        if change.flat then table.insert(parts,string.format('%+g',change.flat))end
        if change.percent then table.insert(parts,string.format('%+g%%',100*change.percent))end
        if change.multiplier then table.insert(parts,'×'..change.multiplier)end
        table.insert(lines,Presentation.pretty(id)..'  '..table.concat(parts,' '))
    end
    return #lines>0 and table.concat(lines,'\n') or 'No stat bonuses'
end
return Presentation
