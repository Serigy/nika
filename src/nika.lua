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
local dataware = require("dataware")
local file_manager = require("file_manager")
local error_handler = require("error_handler")

local has_audit, audit = pcall(require, "nika_audit")

local M = {}
local configured_error_handler = error_handler.create_default({
    env = "prod"
})

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

    raw_req = raw_req or {}
    if raw_req.context_id == nil or raw_req.context_id == "" then
        raw_req.context_id = "ctx-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
    end

    local req = io_factory.new_request(raw_req)
    local res = io_factory.new_response(opts.base_response)
    local active_error_handler = opts.error_handler or configured_error_handler

    local function apply_error(err)
        local handled = error_handler.apply(active_error_handler, err, {
            req = req,
            res = res,
            opts = opts
        })

        res.status = tonumber(handled.status) or 500
        res.headers = res.headers or {}

        local headers = handled.headers or {}
        for k, v in pairs(headers) do
            res.headers[k] = v
        end

        res.body = handled.body == nil and "" or tostring(handled.body)
        return res
    end

    local function cleanup_uploads()
        local ok_cleanup, cleanup_err = pcall(function()
            file_manager.cleanup_request(req.context_id)
        end)
        if not ok_cleanup then
            log_error("Falha no cleanup de upload", {
                context_id = req.context_id,
                error = tostring(cleanup_err)
            })
        end
    end

    local function finalize_response(run_after_request, template_path)
        if run_after_request == true then
            local stop_after_request, stop_reason = hooks.run_stage("after_request", req, res, {
                phase = "after_request",
                template_path = template_path
            })
            if stop_reason == "hook_error" then
                apply_error({
                    status = 500,
                    code = "hook_error",
                    message = "Internal Error",
                    details = "after_request"
                })
            end
            if stop_after_request == true then
                cleanup_uploads()
                return res
            end
        end

        cleanup_uploads()
        return res
    end

    local function upload_error_status(upload_err)
        local normalized = tostring(upload_err or "")
        if normalized == "file_too_large" or normalized == "payload_too_large" then
            return 413
        end
        return 400
    end

    local ok_pipeline, pipeline_error = pcall(function()
        if opts.auto_register_default_hooks ~= false then
            local ok_defaults, defaults_err = hooks.register_default_hooks({
                security_headers_path = opts.security_headers_path
            })
            if not ok_defaults then
                log_error("Falha ao registrar hooks padrao", { error = tostring(defaults_err) })
                apply_error({
                    status = 500,
                    code = "default_hook_load_error",
                    message = "Internal Error",
                    details = defaults_err
                })
                return finalize_response(false)
            end
        end

        if req.upload_error then
            local status = upload_error_status(req.upload_error)
            apply_error({
                status = status,
                code = "upload_error",
                message = tostring(req.upload_error)
            })
            return finalize_response(false)
        end

        local stop_before_request, before_request_reason = hooks.run_stage("before_request", req, res,
            { phase = "before_request" })
        if before_request_reason == "hook_error" then
            apply_error({
                status = 500,
                code = "hook_error",
                message = "Internal Error",
                details = "before_request"
            })
            return finalize_response(false)
        end
        if stop_before_request == true then
            return finalize_response(false)
        end

        local template_path, route_err = router.resolve_or_404(req, res, {
            templates_root = opts.templates_root
        })

        if not template_path then
            local code = route_err == "invalid_path" and "route_invalid_path" or "route_not_found"
            apply_error({
                status = 404,
                code = code,
                message = "Not Found"
            })
            return finalize_response(false)
        end

        local template_source, read_err = safe_read_file(template_path)
        if not template_source then
            log_error("Falha ao ler template", {
                path = template_path,
                error = tostring(read_err)
            })
            apply_error({
                status = 500,
                code = "template_read_error",
                message = "Internal Error",
                details = read_err
            })
            return finalize_response(false)
        end

        local stop_before_render, before_render_reason = hooks.run_stage("before_render", req, res, {
            phase = "before_render",
            template_path = template_path
        })
        if before_render_reason == "hook_error" then
            apply_error({
                status = 500,
                code = "hook_error",
                message = "Internal Error",
                details = "before_render"
            })
            return finalize_response(false)
        end
        if stop_before_render == true then
            return finalize_response(false)
        end

        local compiled_lua, compile_err = parser.compile(template_source)
        if not compiled_lua then
            log_error("Falha ao compilar template", {
                path = template_path,
                error = tostring(compile_err)
            })
            apply_error({
                status = 500,
                code = "template_compile_error",
                message = "Internal Error",
                details = compile_err
            })
            return finalize_response(false)
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
            apply_error({
                status = 500,
                code = "template_render_error",
                message = "Internal Error",
                details = render_err
            })
            return finalize_response(false)
        end

        res.body = rendered_body

        return finalize_response(true, template_path)
    end)

    if not ok_pipeline then
        log_error("Falha inesperada no pipeline", {
            error = tostring(pipeline_error),
            context_id = req.context_id
        })
        apply_error({
            status = 500,
            code = "unhandled_exception",
            message = "Internal Error",
            details = pipeline_error
        })
        return finalize_response(false)
    end

    return pipeline_error
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

-- Phase 11: model registry (REST Dataware)
function M.model(name)
    return dataware.model(name)
end

function M.get_model(name)
    return dataware.get(name)
end

function M.list_models()
    return dataware.list()
end

function M.clear_models()
    return dataware.clear()
end

function M.set_error_handler(handler_fn)
    if type(handler_fn) ~= "function" then
        return nil, "error_handler_must_be_function"
    end
    configured_error_handler = handler_fn
    return true
end

function M.reset_error_handler()
    configured_error_handler = error_handler.create_default({
        env = "prod"
    })
    return true
end

return M
