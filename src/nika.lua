local io_factory = require("nika_io")
local router = require("router")
local parser = require("parser")
local sandbox = require("sandbox")
local hooks = require("hooks")

-- Phase 10: Novos módulos para Gin-style routing
local context_store = require("context_store")
local middleware_chain = require("middleware_chain")
local router_v2 = require("router_v2")
local route_group = require("route_group")

local has_audit, audit = pcall(require, "nika_audit")

local M = {}

local function log_error(message, context)
    if has_audit and audit and type(audit.log_error) == "function" then
        audit.log_error(message, context)
    end
end

local function safe_read_file(path)
    local ok, result_or_err = pcall(function()
        local fh = assert(io.open(path, "r"))
        local content = fh:read("*a")
        fh:close()
        return content
    end)

    if not ok then
        return nil, result_or_err
    end

    return result_or_err
end

function M.escape_html(value)
    local str = tostring(value or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")
    return str
end

function M.handle_request(raw_req, opts)
    opts = opts or {}

    local req = io_factory.new_request(raw_req)
    local res = io_factory.new_response(opts.base_response)

    if opts.auto_register_default_hooks ~= false then
        local ok_defaults, defaults_err = hooks.register_default_hooks({
            security_headers_path = opts.security_headers_path
        })
        if not ok_defaults then
            log_error("Falha ao registrar hooks padrao", { error = tostring(defaults_err) })
            res.status = 500
            res.body = "Erro interno."
            return res
        end
    end

    local stop_before_request = hooks.run_stage("before_request", req, res, { phase = "before_request" })
    if stop_before_request == true then
        return res
    end

    local template_path, route_err = router.resolve_or_404(req, res, {
        templates_root = opts.templates_root
    })

    if not template_path then
        return res
    end

    local template_source, read_err = safe_read_file(template_path)
    if not template_source then
        log_error("Falha ao ler template", {
            path = template_path,
            error = tostring(read_err)
        })
        res.status = 500
        res.body = "Erro interno."
        return res
    end

    local stop_before_render = hooks.run_stage("before_render", req, res, {
        phase = "before_render",
        template_path = template_path
    })
    if stop_before_render == true then
        return res
    end

    local compiled_lua, compile_err = parser.compile(template_source)
    if not compiled_lua then
        log_error("Falha ao compilar template", {
            path = template_path,
            error = tostring(compile_err)
        })
        res.status = 500
        res.body = "Erro interno."
        return res
    end

    local rendered_body, render_err = sandbox.render_template(compiled_lua, req, res, {
        escape = opts.escape or M.escape_html,
        api = opts.template_api,
        template_functions = opts.template_functions,
        template_partials = opts.template_partials,
        template_mode = opts.template_mode
    })

    if not rendered_body then
        log_error("Falha ao renderizar template", {
            path = template_path,
            error = tostring(render_err)
        })
        res.status = 500
        res.body = "Erro interno."
        return res
    end

    res.body = rendered_body

    local stop_after_request = hooks.run_stage("after_request", req, res, {
        phase = "after_request",
        template_path = template_path
    })
    if stop_after_request == true then
        return res
    end

    return res
end

-- Phase 10: API para Gin-style routing
-- Cria novo router explícito (Fase 10)
function M.router()
    return router_v2
end

-- Cria novo grupo de rotas (Fase 10)
function M.group(prefix)
    return route_group.new(prefix, router_v2, middleware_chain)
end

-- Registra middleware global (Fase 10)
function M.use(middleware_fn, name, priority)
    return middleware_chain.use("before_request", middleware_fn, name, priority)
end

-- Cria novo contexto request-scoped (Fase 10)
function M.create_context(request_id)
    return context_store.create_context(request_id)
end

-- Limpa contextos pendentes (Fase 10)
function M.cleanup_contexts()
    return context_store.cleanup_all_pending()
end

-- Debug: retorna informações do router
function M.debug_routes()
    return router_v2.debug_routes()
end

-- Debug: retorna informações de middlewares
function M.debug_middlewares()
    local result = {}
    for _, stage in ipairs({ "before_request", "before_render", "after_request" }) do
        result[stage] = middleware_chain.get_middleware_list(stage)
    end
    return result
end

return M
