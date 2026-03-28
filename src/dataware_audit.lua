local M = {}

local has_audit, audit = pcall(require, "nika_audit")

local function log_security(message, context)
    if has_audit and audit and type(audit.log_security) == "function" then
        audit.log_security(message, context)
    end
end

function M.log_create(model_name, data, tenant_id)
    log_security("dataware_create", {
        model = model_name,
        tenant_id = tenant_id,
        data = data
    })
end

function M.log_update(model_name, old_data, new_data, tenant_id)
    log_security("dataware_update", {
        model = model_name,
        tenant_id = tenant_id,
        old_data = old_data,
        new_data = new_data
    })
end

function M.log_delete(model_name, data, tenant_id)
    log_security("dataware_delete", {
        model = model_name,
        tenant_id = tenant_id,
        data = data
    })
end

function M.log_tenant_violation(model_name, operation)
    log_security("dataware_tenant_violation", {
        model = model_name,
        operation = operation or "query",
        reason = "tenant_required"
    })
end

return M
