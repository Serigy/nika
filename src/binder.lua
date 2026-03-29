local validator = require("validator")

local M = {}

local function copy_table(input)
    local out = {}
    for k, v in pairs(input or {}) do
        out[k] = v
    end
    return out
end

local function coerce_boolean(value)
    if type(value) == "boolean" then
        return value
    end

    local text = string.lower(tostring(value or ""))
    if text == "true" or text == "1" or text == "yes" or text == "on" then
        return true
    end
    if text == "false" or text == "0" or text == "no" or text == "off" then
        return false
    end

    return nil
end

local function coerce_value(value, rule)
    local type_name = rule.type_name

    if value == nil then
        return nil, nil
    end

    if type_name == "string" then
        return tostring(value), nil
    end

    if type_name == "number" then
        local n = tonumber(value)
        if n == nil then
            return nil, "invalid_type"
        end
        return n, nil
    end

    if type_name == "integer" then
        local n = tonumber(value)
        if n == nil or n % 1 ~= 0 then
            return nil, "invalid_type"
        end
        return n, nil
    end

    if type_name == "boolean" then
        local b = coerce_boolean(value)
        if b == nil then
            return nil, "invalid_type"
        end
        return b, nil
    end

    if type_name == "table" then
        if type(value) ~= "table" then
            return nil, "invalid_type"
        end
        return value, nil
    end

    return value, nil
end

local function resolve_source(req, opts)
    local source_hint = opts and opts.source

    if source_hint == "form_data" then
        return req and req.form_data
    end

    if source_hint == "body_table" then
        return req and req.body_table
    end

    if type(req and req.body_table) == "table" and next(req.body_table) ~= nil then
        return req.body_table
    end

    if type(req and req.form_data) == "table" and next(req.form_data) ~= nil then
        return req.form_data
    end

    return req and req.body_table or nil
end

function M.bind(req, schema_def, opts)
    if type(req) ~= "table" then
        return nil, {
            {
                field = "_request",
                code = "invalid_request",
                message = "Request must be table"
            }
        }
    end

    local compiled, schema_err = validator.schema(schema_def)
    if not compiled then
        return nil, {
            {
                field = "_schema",
                code = schema_err or "invalid_schema",
                message = "Schema is invalid"
            }
        }
    end

    local source = resolve_source(req, opts)
    if type(source) ~= "table" then
        return nil, {
            {
                field = "_payload",
                code = "body_table_required",
                message = "Request body table is required"
            }
        }
    end

    local payload = copy_table(source)
    local bound = {}
    local bind_errors = {}

    for field, rule in pairs(compiled.fields) do
        local value = payload[field]
        if value ~= nil and value ~= "" then
            local coerced, err = coerce_value(value, rule)
            if err then
                bind_errors[#bind_errors + 1] = {
                    field = field,
                    code = err,
                    message = "Field type is invalid"
                }
            else
                bound[field] = coerced
            end
        end
    end

    if #bind_errors > 0 then
        return nil, bind_errors
    end

    local ok, validation_errors = validator.validate(bound, compiled, opts)
    if not ok then
        return nil, validation_errors
    end

    return bound
end

return M
