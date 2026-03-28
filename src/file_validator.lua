local M = {}

local DEFAULTS = {
    max_file_size = 25 * 1024 * 1024,
    max_payload = 200 * 1024 * 1024,
    allowed_mime = {
        ["image/jpeg"] = true,
        ["image/png"] = true,
        ["application/pdf"] = true,
        ["text/plain"] = true
    }
}

local function sanitize_filename(filename)
    if type(filename) ~= "string" or filename == "" then
        return nil, "invalid_filename"
    end

    if filename:find("\0", 1, true) then
        return nil, "invalid_filename"
    end

    local normalized = filename:gsub("\\", "/")
    if normalized:find("%.%.", 1, false) then
        return nil, "path_traversal"
    end

    if normalized:sub(1, 1) == "/" then
        return nil, "path_traversal"
    end

    if #normalized > 255 then
        return nil, "filename_too_long"
    end

    if not normalized:match("^[a-zA-Z0-9%._%-%/]+$") then
        return nil, "invalid_filename_chars"
    end

    return normalized
end

function M.validate_file(file, opts)
    opts = opts or {}
    local max_file_size = tonumber(opts.max_file_size) or DEFAULTS.max_file_size
    local allowed_mime = opts.allowed_mime or DEFAULTS.allowed_mime

    if type(file) ~= "table" then
        return nil, "invalid_file"
    end

    local safe_name, name_err = sanitize_filename(file.filename)
    if not safe_name then
        return nil, name_err
    end

    local size = tonumber(file.size)
    if not size or size < 0 then
        return nil, "invalid_file_size"
    end

    if size > max_file_size then
        return nil, "file_too_large"
    end

    local mime = tostring(file.content_type or "")
    if mime == "" or not allowed_mime[mime] then
        return nil, "mime_not_allowed"
    end

    return true
end

function M.validate_payload(files, opts)
    opts = opts or {}
    local max_payload = tonumber(opts.max_payload) or DEFAULTS.max_payload

    local total = 0
    for i = 1, #(files or {}) do
        local file = files[i]
        local ok, err = M.validate_file(file, opts)
        if not ok then
            return nil, err
        end

        total = total + tonumber(file.size)
        if total > max_payload then
            return nil, "payload_too_large"
        end
    end

    return true
end

function M.defaults()
    return {
        max_file_size = DEFAULTS.max_file_size,
        max_payload = DEFAULTS.max_payload,
        allowed_mime = DEFAULTS.allowed_mime
    }
end

return M
