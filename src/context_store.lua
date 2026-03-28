-- Context Store: Request-scoped storage isolado para middlewares
-- Armazena dados temporários por requisição com cleanup automático
-- Sandbox-safe: contexto é read-only no template via _ENV

local M = {}

local _store = {}         -- { request_id → { key = value } }
local _cleanup_queue = {} -- lista de request_ids para limpeza

-- Gera UUID simples para request_id
local function generate_uuid()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(0x8, 0xb)
        return string.format('%x', v)
    end)
end

-- Cria novo contexto request-scoped
-- Se request_id não fornecido, gera um novo
function M.create_context(request_id)
    if not request_id then
        request_id = generate_uuid()
    end

    -- Se já existe, retorna ID existente
    if _store[request_id] then
        return request_id
    end

    _store[request_id] = {}
    table.insert(_cleanup_queue, request_id)
    return request_id
end

-- Armazena valor no contexto
function M.set(request_id, key, value)
    if not request_id or not _store[request_id] then
        return false, "Context inexistente: " .. tostring(request_id)
    end

    -- Bloqueia chaves reservadas
    if key == "_request_id" or key == "system" or key == "__meta" then
        return false, "Chave reservada: " .. key
    end

    _store[request_id][key] = value
    return true
end

-- Recupera valor do contexto
function M.get(request_id, key)
    if not request_id or not _store[request_id] then
        return nil
    end
    return _store[request_id][key]
end

-- Recupera todo o contexto
function M.get_all(request_id)
    if not request_id or not _store[request_id] then
        return {}
    end

    local ctx = {}
    for k, v in pairs(_store[request_id]) do
        ctx[k] = v
    end
    return ctx
end

-- Remove contexto específico
function M.cleanup(request_id)
    if request_id and _store[request_id] then
        _store[request_id] = nil
    end
end

-- Remove todos os contextos pendentes
function M.cleanup_all_pending()
    for _, req_id in ipairs(_cleanup_queue) do
        M.cleanup(req_id)
    end
    _cleanup_queue = {}
end

-- Cria wrapper read-only para uso em sandbox
-- Template pode ler context.get("key") mas não pode modificar
function M.make_readonly_api(request_id)
    local ctx_data = M.get_all(request_id)

    return setmetatable({}, {
        __index = function(_, key)
            return ctx_data[key]
        end,
        __newindex = function(_, key, value)
            error("Context é read-only no template", 2)
        end,
        __pairs = function()
            return pairs(ctx_data)
        end
    })
end

-- Debug/Info
function M.to_string()
    return string.format("ContextStore: %d contextos ativos",
        #_cleanup_queue)
end

function M.get_store_stats()
    return {
        active_contexts = #_cleanup_queue,
        total_stored = #_cleanup_queue,
        cleanup_pending = #_cleanup_queue
    }
end

return M
