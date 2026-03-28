-- Middleware Chain: Orquestrador de middlewares com prioridade
-- Substitui hooks.lua de forma gradual, mantendo backward compat
-- Stages: before_request, before_render, after_request

local M = {}

local _middlewares = {} -- { stage → { mid_name → middleware_fn } }
local _priorities = {}  -- { stage → { mid_name → priority } }

local STAGES = {
    before_request = 1,
    before_render = 2,
    after_request = 3
}

local DEFAULT_PRIORITY = 50

-- Registra middleware em um estágio
-- priority: higher = first (default 50)
function M.use(stage, middleware_fn, name, priority)
    if not STAGES[stage] then
        error("Stage inválido: " .. tostring(stage) ..
            ". Válidos: before_request, before_render, after_request")
    end

    if type(middleware_fn) ~= "function" then
        error("Middleware deve ser function, recebido: " .. type(middleware_fn))
    end

    name = name or "middleware_" .. math.random(10000, 99999)
    priority = priority or DEFAULT_PRIORITY

    if not _middlewares[stage] then
        _middlewares[stage] = {}
        _priorities[stage] = {}
    end

    _middlewares[stage][name] = middleware_fn
    _priorities[stage][name] = priority

    return name -- retorna nome para possível unregister
end

-- Remove middleware específico
function M.unuse(stage, name)
    if _middlewares[stage] then
        _middlewares[stage][name] = nil
        _priorities[stage][name] = nil
    end
end

-- Limpa middlewares
function M.clear(stage)
    if stage then
        _middlewares[stage] = nil
        _priorities[stage] = nil
    else
        _middlewares = {}
        _priorities = {}
    end
end

-- Retorna middlewares ordenados por prioridade (decrescente)
local function get_sorted_middlewares(stage)
    if not _middlewares[stage] then
        return {}
    end

    local list = {}
    for name, fn in pairs(_middlewares[stage]) do
        table.insert(list, {
            name = name,
            fn = fn,
            priority = _priorities[stage][name] or DEFAULT_PRIORITY
        })
    end

    -- Sort: higher priority first
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.name < b.name -- estável por nome
    end)

    return list
end

-- Executa middlewares de um stage
-- Retorna: (is_shortcircuit, error, context)
function M.run(stage, req, res, context)
    if not STAGES[stage] then
        error("Stage inválido: " .. stage)
    end

    context = context or {}
    local middlewares = get_sorted_middlewares(stage)

    for _, mid in ipairs(middlewares) do
        local ok, result = pcall(mid.fn, req, res, context)

        if not ok then
            -- Middleware error: log via nika_audit if available
            local nika_audit = package.loaded["nika_audit"]
            if nika_audit and nika_audit.log_error then
                nika_audit.log_error("middleware_error", {
                    stage = stage,
                    middleware = mid.name,
                    error = tostring(result)
                })
            end
            return nil, result -- propaga erro
        end

        -- Stages before_request/before_render podem short-circuit (retornar true)
        if stage ~= "after_request" and result == true then
            if nika_audit and nika_audit.log_security then
                nika_audit.log_security("middleware_shortcircuit", {
                    stage = stage,
                    middleware = mid.name
                })
            end
            return true -- short-circuit flag
        end

        -- Se middleware retorna novo context (table), atualiza
        if type(result) == "table" and result ~= context then
            context = result
        end
    end

    return false, nil, context -- no short-circuit
end

-- Retorna lista de middlewares registrados (debug)
function M.get_middleware_list(stage)
    local middlewares = get_sorted_middlewares(stage)
    local result = {}
    for _, mid in ipairs(middlewares) do
        table.insert(result, {
            name = mid.name,
            priority = mid.priority,
            stage = stage
        })
    end
    return result
end

-- Retorna contagem de middlewares
function M.count(stage)
    if stage then
        if not _middlewares[stage] then return 0 end
        local count = 0
        for _ in pairs(_middlewares[stage]) do count = count + 1 end
        return count
    end

    local total = 0
    for s, _ in pairs(STAGES) do
        if _middlewares[s] then
            for _ in pairs(_middlewares[s]) do total = total + 1 end
        end
    end
    return total
end

-- Backward compat: tenta usar hooks.run_stage se middleware_chain não tem middleware
function M.run_legacy(stage, req, res, context)
    local hooks = package.loaded["hooks"]
    if hooks and hooks.run_stage then
        return hooks.run_stage(stage, req, res, context)
    end
    return false
end

return M
