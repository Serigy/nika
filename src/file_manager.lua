local file_storage = require("file_storage")
local file_validator = require("file_validator")

local has_audit, audit = pcall(require, "nika_audit")

local M = {}

local request_index = {}

local default_registry = file_storage.new_registry(file_storage.new_local({
    root_dir = "uploads"
}))

local function log_security(message, context)
    if has_audit and audit and type(audit.log_security) == "function" then
        audit.log_security(message, context)
    end
end

local function log_error(message, context)
    if has_audit and audit and type(audit.log_error) == "function" then
        audit.log_error(message, context)
    end
end

function M.set_registry(registry)
    if type(registry) ~= "table" then
        return nil, "invalid_registry"
    end
    default_registry = registry
    return true
end

function M.get_registry()
    return default_registry
end

function M.process_files(files, opts)
    local safe_files = files or {}
    local safe_opts = opts or {}
    local ok, err = file_validator.validate_payload(safe_files, safe_opts)
    if not ok then
        log_security("file_upload_blocked", { reason = err })
        return nil, err
    end

    local stored = {}
    for i = 1, #safe_files do
        local file = safe_files[i]
        local id, meta = default_registry:put(file)
        if not id then
            log_error("file_store_failed", { reason = meta })
            return nil, meta
        end

        stored[#stored + 1] = {
            id = id,
            field = file.field,
            filename = meta.filename,
            original_filename = file.filename,
            content_type = meta.content_type,
            size = meta.size,
            path = meta.path
        }
    end

    if safe_opts.request_id ~= nil and safe_opts.request_id ~= "" then
        local request_id = tostring(safe_opts.request_id)
        request_index[request_id] = request_index[request_id] or {}
        for i = 1, #stored do
            request_index[request_id][#request_index[request_id] + 1] = stored[i].id
        end
    end

    return stored, nil
end

function M.cleanup(files)
    local list = files or {}
    for i = 1, #list do
        local file = list[i]
        local id = file and file.id
        if id then
            default_registry:delete(id)
        end
    end
    return true
end

function M.cleanup_request(request_id)
    if request_id == nil or request_id == "" then
        return true
    end

    local key = tostring(request_id)
    local ids = request_index[key]
    if type(ids) ~= "table" then
        return true
    end

    for i = 1, #ids do
        default_registry:delete(ids[i])
    end

    request_index[key] = nil
    return true
end

function M.reset_request_index()
    request_index = {}
    return true
end

return M
