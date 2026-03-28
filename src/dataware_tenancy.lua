local M = {}

local function default_extractor(req)
    if type(req) ~= "table" then
        return nil
    end

    local headers = req.headers or {}
    return headers["X-Tenant-Id"]
        or headers["x-tenant-id"]
        or req.tenant_id
        or (req.query and req.query.tenant_id)
end

function M.extract_tenant_id(req, extractor)
    extractor = extractor or default_extractor
    local ok, tenant_id = pcall(extractor, req)
    if not ok then
        return nil
    end
    if tenant_id == nil or tenant_id == "" then
        return nil
    end
    return tostring(tenant_id)
end

function M.create_middleware(extractor)
    return function(req, res, context)
        local tenant_id = M.extract_tenant_id(req, extractor)
        if not tenant_id then
            if type(res) == "table" then
                res.status = 403
                res.body = "Tenant context required"
            end
            return true
        end

        if type(context) == "table" then
            if type(context.set) == "function" then
                context.set("tenant_id", tenant_id)
            else
                context.tenant_id = tenant_id
            end
        end

        return false
    end
end

return M
