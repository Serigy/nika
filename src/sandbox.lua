local M = {}

local has_audit, audit = pcall(require, "nika_audit")
local loadstring_fn = rawget(_G, "loadstring")
local setfenv_fn = rawget(_G, "setfenv")
local escape_context = require("escape_context")

local FORBIDDEN = {
    _G = true,
    require = true,
    os = true,
    io = true,
    package = true,
    debug = true,
    load = true,
    loadfile = true,
    dofile = true,
    loadstring = true
}

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

local function add_api(env, api)
    if type(api) ~= "table" then
        return
    end

    for k, v in pairs(api) do
        if FORBIDDEN[k] then
            log_security("Tentativa de expor simbolo proibido no sandbox", { symbol = tostring(k) })
        else
            env[k] = v
        end
    end
end

function M.build_env(req, res, escape_fn, api)
    if type(escape_fn) ~= "function" then
        return nil, "Sandbox invalido: escape_fn ausente"
    end

    local env = {
        Request = req,
        Response = res,
        escape = escape_fn,
        __nika_escape_by_context = escape_context.escape_by_context,
        assert = assert,
        pairs = pairs,
        ipairs = ipairs,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        table = {
            insert = table.insert,
            concat = table.concat
        }
    }

    add_api(env, api)

    return setmetatable(env, {
        __index = function(_, key)
            error("Acesso negado no sandbox: " .. tostring(key), 2)
        end,
        __newindex = function(_, key)
            error("Sandbox e somente leitura: " .. tostring(key), 2)
        end
    })
end

function M.render_template(compiled_lua_code, req, res, opts)
    if type(compiled_lua_code) ~= "string" then
        return nil, "Template compilado invalido"
    end

    opts = opts or {}

    local env, env_err = M.build_env(req, res, opts.escape, opts.api)
    if not env then
        log_error("Falha ao construir sandbox", { error = env_err })
        return nil, "Erro interno"
    end

    local chunk, load_err
    if _VERSION == "Lua 5.1" and type(loadstring_fn) == "function" and type(setfenv_fn) == "function" then
        chunk, load_err = loadstring_fn(compiled_lua_code, "nika-template")
        if chunk then
            setfenv_fn(chunk, env)
        end
    else
        chunk, load_err = load(compiled_lua_code, "nika-template", "t", env)
    end

    if not chunk then
        log_error("Falha de sintaxe ao carregar template", { error = tostring(load_err) })
        return nil, "Erro interno"
    end

    local ok, result_or_err = pcall(chunk)
    if not ok then
        local err_msg = tostring(result_or_err)
        if err_msg:find("blocked_context:", 1, true) then
            log_security("Contexto de template bloqueado", { error = err_msg })
        else
            log_error("Falha na execucao do template", { error = err_msg })
        end
        return nil, "Erro interno"
    end

    return tostring(result_or_err)
end

return M
