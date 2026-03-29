local M = {}

local has_audit, audit = pcall(require, "nika_audit")

local function log_security(message, context)
    if has_audit and audit and type(audit.log_security) == "function" then
        audit.log_security(message, context)
    end
end

local UNSAFE_METHODS = {
    POST = true,
    PUT = true,
    PATCH = true,
    DELETE = true
}

local function parse_cookies(cookie_header)
    local out = {}
    local text = tostring(cookie_header or "")

    for pair in text:gmatch("[^;]+") do
        local key, value = pair:match("^%s*([^=]+)=?(.*)$")
        if key then
            out[key] = value
        end
    end

    return out
end

local function safe_equals(a, b)
    a = tostring(a or "")
    b = tostring(b or "")

    if #a ~= #b then
        return false
    end

    local diff = 0
    for i = 1, #a do
        diff = diff + math.abs(string.byte(a, i) - string.byte(b, i))
    end

    return diff == 0
end

local function error_payload(code, message)
    return string.format('{"code":"%s","message":"%s","retryable":false}', code, message)
end

function M.create(opts)
    opts = opts or {}

    local header_name = opts.header_name or "X-CSRF-Token"
    local cookie_name = opts.cookie_name or "nika_csrf_token"
    local min_token_length = tonumber(opts.min_token_length) or 16

    return function(req, res, context)
        local method = string.upper(tostring(req.method or "GET"))
        if not UNSAFE_METHODS[method] then
            return false
        end

        local headers = req.headers or {}
        local token_header = headers[header_name] or headers[string.lower(header_name)]

        local cookie_header = headers["cookie"] or headers["Cookie"]
        local cookies = parse_cookies(cookie_header)
        local token_cookie = cookies[cookie_name]

        local valid = token_header ~= nil and token_cookie ~= nil
            and #tostring(token_header) >= min_token_length
            and #tostring(token_cookie) >= min_token_length
            and safe_equals(token_header, token_cookie)

        if not valid then
            res.status = 403
            res.headers = res.headers or {}
            res.headers["Content-Type"] = "application/json; charset=utf-8"
            res.body = error_payload("csrf_token_invalid", "CSRF token is invalid")
            log_security("csrf_validation_failed", {
                method = method,
                has_header = token_header ~= nil,
                has_cookie = token_cookie ~= nil
            })
            return true
        end

        return false
    end
end

return M
