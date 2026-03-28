local json_util = require("json_util")
local dataware_tenancy = require("dataware_tenancy")

local M = {}

local function copy_table(input)
    local out = {}
    for k, v in pairs(input or {}) do
        out[k] = v
    end
    return out
end

local function send_json(res, status, payload)
    if type(res) ~= "table" then
        return
    end

    res.status = status
    res.headers = res.headers or {}
    res.headers["Content-Type"] = "application/json; charset=utf-8"
    res.body = json_util.encode(payload)
end

local function resolve_tenant(req, res, opts)
    local context = {}
    local middleware = opts.tenant_middleware or dataware_tenancy.create_middleware(opts.tenant_extractor)
    local short = middleware(req, res, context)
    if short == true then
        return nil, true
    end

    local tenant_id = context.tenant_id or dataware_tenancy.extract_tenant_id(req, opts.tenant_extractor)
    if not tenant_id then
        send_json(res, 403, { error = "tenant_required" })
        return nil, true
    end

    return tenant_id, false
end

local function get_payload(req)
    if type(req) ~= "table" then
        return nil, "invalid_request"
    end

    if type(req.body_table) == "table" then
        return copy_table(req.body_table)
    end

    if type(req.body) == "table" then
        return copy_table(req.body)
    end

    return nil, "body_table_required"
end

function M.generate(model, router, opts)
    if type(model) ~= "table" then
        error("model is required")
    end
    if type(router) ~= "table" then
        error("router is required")
    end

    opts = opts or {}

    local info = model:info()
    local resource = opts.resource or string.lower(info.name) .. "s"
    local base_path = opts.base_path or ("/" .. resource)
    local per_page_default = tonumber(opts.per_page_default) or 10

    local routes = {}

    routes.list = router.get(base_path, function(req, res)
        local tenant_id, blocked = resolve_tenant(req, res, opts)
        if blocked then
            return res
        end

        local page = tonumber(req.query and req.query.page) or 1
        local per_page = tonumber(req.query and req.query.per_page) or per_page_default

        local rows, total, err = model:find(nil, { tenant_id = tenant_id }):paginate(page, per_page)
        if not rows then
            send_json(res, 500, { error = err or "list_failed" })
            return res
        end

        send_json(res, 200, {
            data = rows,
            page = page,
            per_page = per_page,
            total = total
        })

        return res
    end, resource .. "_list")

    routes.get = router.get(base_path .. "/:id", function(req, res)
        local tenant_id, blocked = resolve_tenant(req, res, opts)
        if blocked then
            return res
        end

        local row, err = model:find(req.params and req.params.id, { tenant_id = tenant_id }):first()
        if err then
            send_json(res, 500, { error = err })
            return res
        end

        if not row then
            send_json(res, 404, { error = "not_found" })
            return res
        end

        send_json(res, 200, row)
        return res
    end, resource .. "_get")

    routes.create = router.post(base_path, function(req, res)
        local tenant_id, blocked = resolve_tenant(req, res, opts)
        if blocked then
            return res
        end

        local payload, payload_err = get_payload(req)
        if not payload then
            send_json(res, 400, { error = payload_err })
            return res
        end

        local result, err = model:create(payload, { tenant_id = tenant_id })
        if not result then
            send_json(res, 500, { error = err or "create_failed" })
            return res
        end

        send_json(res, 201, { ok = true })
        return res
    end, resource .. "_create")

    routes.update = router.put(base_path .. "/:id", function(req, res)
        local tenant_id, blocked = resolve_tenant(req, res, opts)
        if blocked then
            return res
        end

        local payload, payload_err = get_payload(req)
        if not payload then
            send_json(res, 400, { error = payload_err })
            return res
        end

        local result, err = model:find(req.params and req.params.id, { tenant_id = tenant_id }):update(payload)
        if not result then
            send_json(res, 500, { error = err or "update_failed" })
            return res
        end

        send_json(res, 200, { ok = true })
        return res
    end, resource .. "_update")

    routes.delete = router.delete(base_path .. "/:id", function(req, res)
        local tenant_id, blocked = resolve_tenant(req, res, opts)
        if blocked then
            return res
        end

        local result, err = model:find(req.params and req.params.id, { tenant_id = tenant_id }):delete()
        if not result then
            send_json(res, 500, { error = err or "delete_failed" })
            return res
        end

        send_json(res, 200, { ok = true })
        return res
    end, resource .. "_delete")

    return routes
end

return M
