local M = {}

local FORBIDDEN_NAMES = {
    _G = true,
    require = true,
    os = true,
    io = true,
    package = true,
    debug = true,
    load = true,
    loadfile = true,
    dofile = true,
    loadstring = true,
    Request = true,
    Response = true,
    escape = true,
    write = true,
    __nika_emit = true,
    __nika_write = true,
    __nika_escape_by_context = true
}

local function is_valid_name(name)
    return type(name) == "string" and name:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function emit_security(on_security, message, context)
    if type(on_security) == "function" then
        on_security(message, context)
    end
end

local function is_registry(candidate)
    return type(candidate) == "table" and candidate.__nika_template_fn_registry == true and type(candidate.functions) == "table"
end

local function add_function(out, name, fn, on_security)
    if not is_valid_name(name) then
        emit_security(on_security, "Nome invalido no registry de funcoes", { symbol = tostring(name) })
        return
    end

    if FORBIDDEN_NAMES[name] then
        emit_security(on_security, "Tentativa de registrar funcao proibida", { symbol = tostring(name) })
        return
    end

    if type(fn) ~= "function" then
        emit_security(on_security, "Registry ignorou entrada nao-funcao", { symbol = tostring(name) })
        return
    end

    out[name] = fn
end

function M.new(initial_functions)
    local registry = {
        __nika_template_fn_registry = true,
        functions = {}
    }

    if type(initial_functions) == "table" then
        for name, fn in pairs(initial_functions) do
            add_function(registry.functions, name, fn)
        end
    end

    return registry
end

function M.register(registry, name, fn, on_security)
    if not is_registry(registry) then
        return nil, "registry_invalido"
    end

    add_function(registry.functions, name, fn, on_security)
    return true
end

function M.register_many(registry, fn_map, on_security)
    if not is_registry(registry) then
        return nil, "registry_invalido"
    end

    if type(fn_map) ~= "table" then
        return nil, "fn_map_invalido"
    end

    for name, fn in pairs(fn_map) do
        add_function(registry.functions, name, fn, on_security)
    end

    return true
end

function M.resolve(template_functions, legacy_api, on_security)
    local merged = {}

    if template_functions ~= nil then
        local source
        if is_registry(template_functions) then
            source = template_functions.functions
        elseif type(template_functions) == "table" then
            source = template_functions
        else
            return nil, "template_functions_invalido"
        end

        for name, fn in pairs(source) do
            add_function(merged, name, fn, on_security)
        end
    end

    if type(legacy_api) == "table" then
        for name, value in pairs(legacy_api) do
            if type(value) == "function" and merged[name] == nil then
                add_function(merged, name, value, on_security)
            end
        end
    end

    return merged
end

return M
