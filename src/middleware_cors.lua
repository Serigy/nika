local M = {}

local has_audit, audit = pcall(require, "nika_audit")

local function log_security(message, context)
    if has_audit and audit and type(audit.log_security) == "function" then
        audit.log_security(message, context)
    end
end

local function set_header(headers, key, value)
    if headers[key] == nil then
        headers[key] = value
    end
end

local function parse_allowed_origins(origins)
    local out = {}
    if type(origins) ~= "table" then
        return out
    end
    for i = 1, #origins do
        local value = tostring(origins[i] or "")
        if value ~= "" then
            out[value] = true
        end
    end
    return out
end

local function error_payload(code, message)
    return string.format('{"code":"%s","message":"%s","retryable":false}', code, message)
end

function M.create(opts)
    opts = opts or {}

    local allowed_origins = parse_allowed_origins(opts.allowed_origins)
    local allow_methods = table.concat(opts.allowed_methods or { "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS" },
        ",")
    local allow_headers = table.concat(opts.allowed_headers or { "Content-Type", "Authorization", "X-CSRF-Token" }, ",")
    local allow_credentials = opts.allow_credentials == true

    return function(req, res, context)
        local headers = res.headers or {}
        res.headers = headers

        local origin = (req.headers and (req.headers["origin"] or req.headers["Origin"])) or nil

        if origin and next(allowed_origins) ~= nil and not allowed_origins[origin] then
            res.status = 403
            headers["Content-Type"] = "application/json; charset=utf-8"
            res.body = error_payload("cors_origin_not_allowed", "Origin not allowed")
            log_security("cors_origin_blocked", { origin = origin })
            return true
        end

        if origin then
            headers["Access-Control-Allow-Origin"] = origin
            set_header(headers, "Vary", "Origin")
        end

        headers["Access-Control-Allow-Methods"] = allow_methods
        headers["Access-Control-Allow-Headers"] = allow_headers
        if allow_credentials then
            headers["Access-Control-Allow-Credentials"] = "true"
        end

        local method = string.upper(tostring(req.method or "GET"))
        if method == "OPTIONS" then
            res.status = 204
            res.body = ""
            return true
        end

        return false
    end
end

return M
