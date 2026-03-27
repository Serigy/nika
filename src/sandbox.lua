local M = {}

local has_audit, audit = pcall(require, "nika_audit")
local loadstring_fn = rawget(_G, "loadstring")
local setfenv_fn = rawget(_G, "setfenv")
local escape_context = require("escape_context")
local template_functions = require("template_functions")
local template_partials = require("template_partials")
local parser = require("parser")

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

local RESERVED_ENV = {
    Request = true,
    Response = true,
    escape = true,
    write = true,
    __nika_emit = true,
    __nika_write = true,
    __nika_escape_by_context = true,
    __nika_partial = true,
    partial = true,
    include = true,
    assert = true,
    pairs = true,
    ipairs = true,
    tonumber = true,
    tostring = true,
    type = true,
    table = true
}

local function clone_table(input)
    local out = {}
    if type(input) ~= "table" then
        return out
    end

    for k, v in pairs(input) do
        out[k] = v
    end
    return out
end

local function build_child_request(req, partial_data)
    local child_req = clone_table(req)
    child_req.query = clone_table(type(req) == "table" and req.query or nil)

    if type(partial_data) == "table" then
        for k, v in pairs(partial_data) do
            child_req.query[k] = v
        end
    end

    return child_req
end

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
        elseif RESERVED_ENV[k] then
            log_security("Tentativa de sobrescrever simbolo reservado no sandbox", { symbol = tostring(k) })
        elseif type(v) == "function" then
            -- Funcoes devem vir do registry explicito (template_functions).
            log_security("Funcao ignorada no template_api legado; use template_functions", { symbol = tostring(k) })
        else
            env[k] = v
        end
    end
end

local function add_template_functions(env, fn_registry, legacy_api)
    local resolved, resolve_err = template_functions.resolve(fn_registry, legacy_api, log_security)
    if not resolved then
        return nil, resolve_err
    end

    for name, fn in pairs(resolved) do
        if RESERVED_ENV[name] or FORBIDDEN[name] then
            log_security("Registry tentou sobrescrever simbolo sensivel", { symbol = tostring(name) })
        else
            env[name] = fn
        end
    end

    return true
end

local function add_partial_renderer(env, req, res, escape_fn, api, fn_registry, partials, opts)
    opts = opts or {}

    local max_depth = tonumber(opts.max_partial_depth) or 5
    local current_depth = tonumber(opts.partial_depth) or 0

    env.__nika_partial = function(partial_name, partial_data)
        if current_depth >= max_depth then
            error("partial_depth_exceeded", 2)
        end

        local source, resolve_err = template_partials.resolve_source(partials, partial_name, log_security)
        if not source then
            error("invalid_partial:" .. tostring(resolve_err), 2)
        end

        local compiled, compile_err = parser.compile(source)
        if not compiled then
            error("partial_compile_error:" .. tostring(compile_err), 2)
        end

        local child_req = build_child_request(req, partial_data)
        local rendered, render_err = M.render_template(compiled, child_req, res, {
            escape = escape_fn,
            api = api,
            template_functions = fn_registry,
            template_partials = partials,
            template_mode = opts.template_mode,
            partial_depth = current_depth + 1,
            max_partial_depth = max_depth
        })

        if not rendered then
            error("partial_render_error:" .. tostring(render_err), 2)
        end

        return rendered
    end

    return true
end

function M.build_env(req, res, escape_fn, api, fn_registry, partials, opts)
    if type(escape_fn) ~= "function" then
        return nil, "Sandbox invalido: escape_fn ausente"
    end

    opts = opts or {}
    local template_mode = opts.template_mode or "html"

    local env = {
        Request = req,
        Response = res,
        escape = escape_fn,
        __nika_escape_by_context = function(context_name, value)
            return escape_context.escape_by_context(context_name, value, {
                mode = template_mode,
                escape_fallback = escape_fn
            })
        end,
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

    local ok_functions, functions_err = add_template_functions(env, fn_registry, api)
    if not ok_functions then
        return nil, "Sandbox invalido: template_functions " .. tostring(functions_err)
    end

    local ok_partials, partials_err = add_partial_renderer(env, req, res, escape_fn, api, fn_registry, partials, opts)
    if not ok_partials then
        return nil, "Sandbox invalido: template_partials " .. tostring(partials_err)
    end

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

    if opts.template_mode ~= nil and opts.template_mode ~= "html" and opts.template_mode ~= "text" then
        log_error("Modo de template invalido", { mode = tostring(opts.template_mode) })
        return nil, "Erro interno"
    end

    local env, env_err = M.build_env(req, res, opts.escape, opts.api, opts.template_functions, opts.template_partials,
        opts)
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
