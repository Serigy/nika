local M = {}

local has_audit, audit = pcall(require, "nika_audit")

local function log_security(message, context)
    if has_audit and audit and type(audit.log_security) == "function" then
        audit.log_security(message, context)
    end
end

local function extract_client_ip(req)
    local headers = req.headers or {}
    local forwarded = headers["x-forwarded-for"] or headers["X-Forwarded-For"]
    if type(forwarded) == "string" and forwarded ~= "" then
        local ip = forwarded:match("^%s*([^,%s]+)")
        if ip and ip ~= "" then
            return ip
        end
    end

    local real_ip = headers["x-real-ip"] or headers["X-Real-Ip"]
    if type(real_ip) == "string" and real_ip ~= "" then
        return real_ip
    end

    if type(req.remote_addr) == "string" and req.remote_addr ~= "" then
        return req.remote_addr
    end

    return "unknown"
end

local function error_payload(code, message, retryable)
    return string.format('{"code":"%s","message":"%s","retryable":%s}', code, message, retryable and "true" or "false")
end

function M.create(opts)
    opts = opts or {}

    local window_seconds = tonumber(opts.window_seconds) or 60
    local max_requests = tonumber(opts.max_requests) or 100
    local bucket = {}

    return function(req, res, context)
        local now = os.time()
        local ip = extract_client_ip(req)

        local entry = bucket[ip]
        if entry == nil or now >= entry.reset_at then
            entry = {
                count = 0,
                reset_at = now + window_seconds
            }
            bucket[ip] = entry
        end

        entry.count = entry.count + 1

        if entry.count > max_requests then
            local retry_after = math.max(1, entry.reset_at - now)

            res.status = 429
            res.headers = res.headers or {}
            res.headers["Content-Type"] = "application/json; charset=utf-8"
            res.headers["Retry-After"] = tostring(retry_after)
            res.body = error_payload("rate_limit_exceeded", "Too many requests", true)

            log_security("rate_limit_exceeded", {
                ip = ip,
                retry_after = retry_after,
                count = entry.count
            })

            return true
        end

        return false
    end
end

return M
