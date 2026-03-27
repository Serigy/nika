local M = {}

local function is_valid_name(name)
    return type(name) == "string" and name:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function emit_security(on_security, message, context)
    if type(on_security) == "function" then
        on_security(message, context)
    end
end

local function is_registry(candidate)
    return type(candidate) == "table" and candidate.__nika_template_partial_registry == true and type(candidate.partials) == "table"
end

local function add_partial(out, name, source, on_security)
    if not is_valid_name(name) then
        emit_security(on_security, "Nome invalido no registry de parciais", { symbol = tostring(name) })
        return
    end

    if type(source) ~= "string" then
        emit_security(on_security, "Parcial ignorada por tipo invalido", { symbol = tostring(name) })
        return
    end

    out[name] = source
end

function M.new(initial_partials)
    local registry = {
        __nika_template_partial_registry = true,
        partials = {}
    }

    if type(initial_partials) == "table" then
        for name, source in pairs(initial_partials) do
            add_partial(registry.partials, name, source)
        end
    end

    return registry
end

function M.register(registry, name, source, on_security)
    if not is_registry(registry) then
        return nil, "registry_invalido"
    end

    add_partial(registry.partials, name, source, on_security)
    return true
end

function M.register_many(registry, partial_map, on_security)
    if not is_registry(registry) then
        return nil, "registry_invalido"
    end

    if type(partial_map) ~= "table" then
        return nil, "partial_map_invalido"
    end

    for name, source in pairs(partial_map) do
        add_partial(registry.partials, name, source, on_security)
    end

    return true
end

function M.resolve_source(input, partial_name, on_security)
    if type(partial_name) ~= "string" then
        return nil, "nome_invalido"
    end

    local source_map
    if input == nil then
        return nil, "partial_nao_configurada"
    end

    if is_registry(input) then
        source_map = input.partials
    elseif type(input) == "table" then
        source_map = input
    else
        return nil, "registry_invalido"
    end

    local source = source_map[partial_name]
    if type(source) ~= "string" then
        emit_security(on_security, "Parcial nao encontrada", { partial = partial_name })
        return nil, "partial_nao_encontrada"
    end

    return source
end

return M
