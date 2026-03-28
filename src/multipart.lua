local M = {}

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_content_type(content_type)
    local ct = tostring(content_type or "")
    local mime = trim(ct:match("^([^;]+)"))
    local boundary = ct:match("boundary=([^;]+)")

    if boundary then
        boundary = trim(boundary)
        if boundary:sub(1, 1) == '"' and boundary:sub(-1) == '"' then
            boundary = boundary:sub(2, -2)
        end
    end

    return mime, boundary
end

function M.is_multipart(content_type)
    local mime = parse_content_type(content_type)
    return string.lower(mime or "") == "multipart/form-data"
end

local function parse_headers_block(block)
    local headers = {}
    for line in block:gmatch("([^\r\n]+)") do
        local k, v = line:match("^([^:]+):%s*(.*)$")
        if k and v then
            headers[string.lower(trim(k))] = trim(v)
        end
    end
    return headers
end

local function parse_content_disposition(value)
    local out = {}
    if type(value) ~= "string" then
        return out
    end

    out.type = trim(value:match("^([^;]+)"))
    out.name = value:match('name="([^"]+)"')
    out.filename = value:match('filename="([^"]*)"')

    return out
end

function M.parse(body, content_type)
    if type(body) ~= "string" then
        return nil, "invalid_body"
    end

    local mime, boundary = parse_content_type(content_type)
    if string.lower(mime or "") ~= "multipart/form-data" then
        return nil, "not_multipart"
    end

    if not boundary or boundary == "" then
        return nil, "boundary_missing"
    end

    local delimiter = "--" .. boundary
    local close_delimiter = delimiter .. "--"

    local form_data = {}
    local files = {}

    local cursor = 1
    local first = body:find(delimiter, cursor, true)
    if not first then
        return nil, "boundary_not_found"
    end

    cursor = first
    while true do
        local start_idx = body:find(delimiter, cursor, true)
        if not start_idx then
            break
        end

        local after = start_idx + #delimiter
        if body:sub(after, after + 1) == "--" then
            break
        end

        if body:sub(after, after + 1) == "\r\n" then
            after = after + 2
        end

        local next_idx = body:find("\r\n" .. delimiter, after, true)
        if not next_idx then
            next_idx = body:find(close_delimiter, after, true)
            if not next_idx then
                break
            end
        end

        local part = body:sub(after, next_idx - 1)
        local headers_block, payload = part:match("^(.-)\r\n\r\n(.*)$")
        if headers_block and payload then
            local headers = parse_headers_block(headers_block)
            local disp = parse_content_disposition(headers["content-disposition"])

            if disp.name and disp.filename and disp.filename ~= "" then
                files[#files + 1] = {
                    field = disp.name,
                    filename = disp.filename,
                    content_type = headers["content-type"] or "application/octet-stream",
                    data = payload,
                    size = #payload
                }
            elseif disp.name then
                form_data[disp.name] = payload
            end
        end

        cursor = next_idx + 2
    end

    return {
        form_data = form_data,
        files = files,
        boundary = boundary
    }, nil
end

return M
