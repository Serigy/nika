local nika = require("nika")
local multipart = require("multipart")
local file_manager = require("file_manager")

local has_audit, audit = pcall(require, "nika_audit")

local M = {}

local function generate_request_id()
    local seed = tostring(os.time()) .. tostring(math.random(100000, 999999))
    return "req-" .. seed
end

local function log_error(message, context)
    if has_audit and audit and type(audit.log_error) == "function" then
        audit.log_error(message, context)
    end
end

local function urldecode(value)
    if type(value) ~= "string" then
        return ""
    end

    local decoded = value:gsub("+", " ")
    decoded = decoded:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return decoded
end

local function parse_query(query_string)
    local out = {}
    if type(query_string) ~= "string" or query_string == "" then
        return out
    end

    for pair in string.gmatch(query_string, "[^&]+") do
        local eq = string.find(pair, "=", 1, true)
        local key
        local value

        if eq then
            key = string.sub(pair, 1, eq - 1)
            value = string.sub(pair, eq + 1)
        else
            key = pair
            value = ""
        end

        key = urldecode(key)
        value = urldecode(value)

        if key ~= "" then
            out[key] = value
        end
    end

    return out
end

local function parse_headers(env)
    local headers = {}

    for k, v in pairs(env) do
        if type(k) == "string" and k:sub(1, 5) == "HTTP_" then
            local name = k:sub(6):gsub("_", "-")
            headers[name] = tostring(v)
        end
    end

    if env.CONTENT_TYPE then
        headers["Content-Type"] = tostring(env.CONTENT_TYPE)
    end

    if env.CONTENT_LENGTH then
        headers["Content-Length"] = tostring(env.CONTENT_LENGTH)
    end

    return headers
end

local function read_body(env, stdin_reader)
    local content_length = tonumber(env.CONTENT_LENGTH) or 0
    if content_length <= 0 then
        return ""
    end

    local ok, body_or_err = pcall(function()
        return stdin_reader(content_length)
    end)

    if not ok then
        log_error("Falha ao ler body no adapter CGI", { error = tostring(body_or_err) })
        return ""
    end

    if type(body_or_err) ~= "string" then
        return ""
    end

    return body_or_err
end

function M.request_from_cgi(env, stdin_reader)
    env = env or {}
    stdin_reader = stdin_reader or function(len)
        return io.read(len)
    end

    local method = env.REQUEST_METHOD or "GET"
    local path = env.PATH_INFO or env.REQUEST_URI or "/"
    if type(path) == "string" then
        path = path:match("^[^?]*") or "/"
    else
        path = "/"
    end

    local headers = parse_headers(env)
    local context_id = env.HTTP_X_REQUEST_ID or env.REQUEST_ID or env.UNIQUE_ID or generate_request_id()
    local query = parse_query(env.QUERY_STRING or "")
    local body = read_body(env, stdin_reader)

    local form_data = {}
    local files = {}
    local body_table = nil
    local upload_error = nil

    local content_type = headers["Content-Type"]
    if multipart.is_multipart(content_type) then
        local parsed, parse_err = multipart.parse(body, content_type)
        if not parsed then
            upload_error = parse_err
        else
            form_data = parsed.form_data or {}
            body_table = form_data

            local stored, store_err = file_manager.process_files(parsed.files or {}, {
                request_id = context_id
            })
            if not stored then
                upload_error = store_err
            else
                files = stored
            end
        end
    elseif type(content_type) == "string" and string.lower(content_type):find("application/x%-www%-form%-urlencoded", 1, false) then
        form_data = parse_query(body)
        body_table = form_data
    end

    return {
        method = method,
        path = path,
        query = query,
        body = body,
        headers = headers,
        form_data = form_data,
        files = files,
        body_table = body_table,
        context_id = context_id,
        upload_error = upload_error
    }
end

local function status_text(status)
    local map = {
        [200] = "OK",
        [400] = "Bad Request",
        [401] = "Unauthorized",
        [403] = "Forbidden",
        [404] = "Not Found",
        [500] = "Internal Server Error"
    }
    return map[status] or "OK"
end

function M.response_to_cgi(res, stdout_writer)
    stdout_writer = stdout_writer or function(chunk)
        io.write(chunk)
    end

    local safe = res or {}
    local status = tonumber(safe.status) or 200
    local headers = type(safe.headers) == "table" and safe.headers or {}
    local body = safe.body == nil and "" or tostring(safe.body)

    if headers["Content-Type"] == nil then
        headers["Content-Type"] = "text/html; charset=utf-8"
    end

    headers["Content-Length"] = tostring(#body)

    stdout_writer("Status: " .. tostring(status) .. " " .. status_text(status) .. "\r\n")
    for k, v in pairs(headers) do
        stdout_writer(tostring(k) .. ": " .. tostring(v) .. "\r\n")
    end
    stdout_writer("\r\n")
    stdout_writer(body)
end

function M.run_cgi(opts)
    opts = opts or {}

    local req = M.request_from_cgi(opts.env or _G, opts.stdin_reader)
    local res = nika.handle_request(req, opts.nika_options)
    M.response_to_cgi(res, opts.stdout_writer)
    return true
end

return M
