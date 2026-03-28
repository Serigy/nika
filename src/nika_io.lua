local M = {}
local json_util = require("json_util")

local function copy_table(input)
    local out = {}
    if type(input) ~= "table" then
        return out
    end
    for k, v in pairs(input) do
        out[k] = v
    end
    return out
end

local function readonly(table_value)
    local frozen = {}
    for k, v in pairs(table_value) do
        if type(v) == "table" then
            frozen[k] = readonly(copy_table(v))
        else
            frozen[k] = v
        end
    end

    return setmetatable({}, {
        __index = frozen,
        __newindex = function(_, key)
            error("Request e somente leitura: " .. tostring(key), 2)
        end,
        __pairs = function()
            return pairs(frozen)
        end
    })
end

local function normalize_method(method)
    if type(method) ~= "string" or method == "" then
        return "GET"
    end
    return string.upper(method)
end

local function normalize_path(path)
    if type(path) ~= "string" or path == "" then
        return "/"
    end
    return path
end

function M.new_request(raw)
    local source = raw or {}

    local req = {
        method = normalize_method(source.method),
        path = normalize_path(source.path),
        query = copy_table(source.query),
        body = source.body,
        body_table = copy_table(source.body_table),
        headers = copy_table(source.headers),
        form_data = copy_table(source.form_data),
        files = copy_table(source.files),
        params = copy_table(source.params),
        context_id = source.context_id or nil, -- Phase 10: request-scoped context ID
        upload_error = source.upload_error or nil
    }

    return readonly(req)
end

function M.new_response(raw)
    local source = raw or {}

    local res = {
        status = tonumber(source.status) or 200,
        headers = copy_table(source.headers),
        body = source.body == nil and "" or tostring(source.body)
    }

    if res.headers["Content-Type"] == nil then
        res.headers["Content-Type"] = "text/html; charset=utf-8"
    end

    function res.json(payload, status)
        if status ~= nil then
            res.status = tonumber(status) or res.status
        end
        res.headers["Content-Type"] = "application/json; charset=utf-8"
        res.body = json_util.encode(payload)
        return res
    end

    return res
end

return M
