local M = {}

local function escape_json(str)
    local s = tostring(str)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\b", "\\b")
    s = s:gsub("\f", "\\f")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return s
end

local function encode(value, seen)
    local t = type(value)

    if t == "nil" then
        return "null"
    end

    if t == "boolean" or t == "number" then
        return tostring(value)
    end

    if t == "string" then
        return '"' .. escape_json(value) .. '"'
    end

    if t ~= "table" then
        return '"<' .. t .. '>"'
    end

    if seen[value] then
        return '"<cycle>"'
    end
    seen[value] = true

    local is_array = true
    local max_index = 0
    for k, _ in pairs(value) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
            is_array = false
            break
        end
        if k > max_index then
            max_index = k
        end
    end

    local out = {}
    if is_array then
        for i = 1, max_index do
            out[#out + 1] = encode(value[i], seen)
        end
        seen[value] = nil
        return "[" .. table.concat(out, ",") .. "]"
    end

    for k, v in pairs(value) do
        out[#out + 1] = '"' .. escape_json(tostring(k)) .. '":' .. encode(v, seen)
    end

    seen[value] = nil
    return "{" .. table.concat(out, ",") .. "}"
end

function M.encode(value)
    return encode(value, {})
end

return M
