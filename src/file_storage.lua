local M = {}

local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

local function ensure_dir(path)
    if is_windows() then
        os.execute('mkdir "' .. path .. '" >NUL 2>NUL')
    else
        os.execute('mkdir -p "' .. path .. '" >/dev/null 2>&1')
    end
end

local function random_id()
    local template = "xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx"
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

local function safe_name(name)
    local n = tostring(name or "file.bin")
    n = n:gsub("[^a-zA-Z0-9%._%-]", "_")
    if n == "" then
        n = "file.bin"
    end
    return n
end

function M.new_local(config)
    local cfg = config or {}
    local root_dir = cfg.root_dir or "uploads"
    ensure_dir(root_dir)

    local index = {}

    local provider = {}

    function provider:put(file)
        if type(file) ~= "table" then
            return nil, "invalid_file"
        end

        local id = random_id()
        local filename = safe_name(file.filename)
        local path = root_dir .. "/" .. id .. "_" .. filename

        local fh, open_err = io.open(path, "wb")
        if not fh then
            return nil, "storage_open_failed:" .. tostring(open_err)
        end

        local data = file.data
        if type(data) ~= "string" then
            data = tostring(data or "")
        end

        local ok, write_err = pcall(function()
            fh:write(data)
            fh:close()
        end)

        if not ok then
            return nil, "storage_write_failed:" .. tostring(write_err)
        end

        index[id] = {
            id = id,
            filename = filename,
            content_type = file.content_type,
            size = #data,
            path = path
        }

        return id, index[id]
    end

    function provider:get(id)
        return index[id]
    end

    function provider:delete(id)
        local meta = index[id]
        if not meta then
            return nil, "not_found"
        end

        local ok, err = os.remove(meta.path)
        if not ok then
            return nil, tostring(err)
        end

        index[id] = nil
        return true
    end

    function provider:clear()
        for id, _ in pairs(index) do
            provider:delete(id)
        end
        return true
    end

    return provider
end

function M.new_registry(default_provider)
    local providers = {}
    local active = "default"

    if default_provider then
        providers.default = default_provider
    end

    local registry = {}

    function registry:set_provider(name, provider)
        if type(name) ~= "string" or name == "" then
            return nil, "invalid_provider_name"
        end
        if type(provider) ~= "table" then
            return nil, "invalid_provider"
        end
        providers[name] = provider
        return true
    end

    function registry:use(name)
        if not providers[name] then
            return nil, "provider_not_found"
        end
        active = name
        return true
    end

    function registry:active()
        return providers[active]
    end

    function registry:put(file)
        local provider = providers[active]
        if not provider then
            return nil, "no_active_provider"
        end
        return provider:put(file)
    end

    function registry:get(id)
        local provider = providers[active]
        if not provider then
            return nil, "no_active_provider"
        end
        return provider:get(id)
    end

    function registry:delete(id)
        local provider = providers[active]
        if not provider then
            return nil, "no_active_provider"
        end
        return provider:delete(id)
    end

    return registry
end

return M
