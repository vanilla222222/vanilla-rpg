local TableUtil = {}
function TableUtil.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = TableUtil.copy(child) end
    return result
end
function TableUtil.finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
function TableUtil.integer(value, minimum, maximum)
    return TableUtil.finite(value) and value % 1 == 0 and value >= minimum and value <= maximum
end
return TableUtil
