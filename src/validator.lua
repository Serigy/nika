local json_util = require("json_util")

local M = {}

local MAX_PAYLOAD_BYTES_DEFAULT = 1024 * 1024

local EMAIL_PATTERN = "^[^%s@]+@[^%s@]+%.[^%s@]+$"

local function split(value, sep)
    local out = {}
    local pattern = "([^" .. sep .. "]+)"
    for token in tostring(value or ""):gmatch(pattern) do
        out[#out + 1] = token
    end
    return out
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function parse_enum_list(raw)
    local items = split(raw, ",")
    local out = {}
    for i = 1, #items do
        local item = trim(items[i])
        if item ~= "" then
            out[#out + 1] = item
        end
    end
    return out
end

local function parse_rule_string(rule_text)
    local rule = {
        required = false,
        type_name = "string"
    }

    local tokens = split(rule_text, "|")
    if #tokens == 0 then
        return nil, "invalid_rule"
    end

    rule.type_name = trim(tokens[1])

    for i = 2, #tokens do
        local token = trim(tokens[i])

        if token == "required" then
            rule.required = true
        elseif token:match("^min:") then
            rule.min = tonumber(token:sub(5))
        elseif token:match("^max:") then
            rule.max = tonumber(token:sub(5))
        elseif token == "email" then
            rule.email = true
        elseif token:match("^pattern:") then
            rule.pattern = token:sub(9)
        elseif token:match("^enum:") then
            rule.enum = parse_enum_list(token:sub(6))
        end
    end

    if rule.type_name == "email" then
        rule.type_name = "string"
        rule.email = true
    end

    return rule
end

local function normalize_schema(schema_def)
    if type(schema_def) ~= "table" then
        return nil, "schema_must_be_table"
    end

    local normalized = {
        __nika_validator_schema = true,
        fields = {}
    }

    for field, def in pairs(schema_def) do
        if type(field) ~= "string" or field == "" then
            return nil, "invalid_schema_field"
        end

        local rule = nil
        local err = nil

        if type(def) == "string" then
            rule, err = parse_rule_string(def)
            if not rule then
                return nil, err
            end
        elseif type(def) == "table" then
            rule = {
                required = def.required == true,
                type_name = tostring(def.type or "string"),
                min = tonumber(def.min),
                max = tonumber(def.max),
                email = def.email == true,
                pattern = def.pattern,
                enum = def.enum
            }
        else
            return nil, "invalid_schema_rule"
        end

        normalized.fields[field] = rule
    end

    return normalized
end

local function type_matches(value, type_name)
    if type_name == "string" then
        return type(value) == "string"
    end

    if type_name == "number" then
        return type(value) == "number"
    end

    if type_name == "integer" then
        return type(value) == "number" and value % 1 == 0
    end

    if type_name == "boolean" then
        return type(value) == "boolean"
    end

    if type_name == "table" then
        return type(value) == "table"
    end

    return false
end

local function error_message(code)
    local map = {
        required = "Field is required",
        invalid_type = "Field type is invalid",
        min_violation = "Field is below minimum",
        max_violation = "Field is above maximum",
        invalid_email = "Field is not a valid email",
        invalid_pattern = "Field does not match required pattern",
        invalid_enum = "Field is not in allowed enum",
        payload_too_large = "Payload too large"
    }

    return map[code] or "Validation error"
end

local function payload_size_too_large(payload, max_bytes)
    local serialized = json_util.encode(payload)
    return #serialized > max_bytes
end

function M.schema(schema_def)
    return normalize_schema(schema_def)
end

function M.validate(payload, schema_def, opts)
    if type(payload) ~= "table" then
        return nil, {
            {
                field = "_payload",
                code = "invalid_payload",
                message = "Payload must be table"
            }
        }
    end

    local compiled = schema_def
    if type(schema_def) ~= "table" or schema_def.__nika_validator_schema ~= true then
        compiled = nil
        local compile_err = nil
        compiled, compile_err = normalize_schema(schema_def)
        if not compiled then
            return nil, {
                {
                    field = "_schema",
                    code = compile_err or "invalid_schema",
                    message = "Schema is invalid"
                }
            }
        end
    end

    local max_payload_bytes = tonumber(opts and opts.max_payload_bytes) or MAX_PAYLOAD_BYTES_DEFAULT
    if payload_size_too_large(payload, max_payload_bytes) then
        return nil, {
            {
                field = "_payload",
                code = "payload_too_large",
                message = error_message("payload_too_large")
            }
        }
    end

    local errors = {}

    for field, rule in pairs(compiled.fields) do
        local value = payload[field]

        if value == nil or value == "" then
            if rule.required then
                errors[#errors + 1] = {
                    field = field,
                    code = "required",
                    message = error_message("required")
                }
            end
        else
            if not type_matches(value, rule.type_name) then
                errors[#errors + 1] = {
                    field = field,
                    code = "invalid_type",
                    message = error_message("invalid_type")
                }
            else
                if rule.type_name == "string" then
                    local len = #value
                    if rule.min and len < rule.min then
                        errors[#errors + 1] = {
                            field = field,
                            code = "min_violation",
                            message = error_message("min_violation")
                        }
                    end
                    if rule.max and len > rule.max then
                        errors[#errors + 1] = {
                            field = field,
                            code = "max_violation",
                            message = error_message("max_violation")
                        }
                    end
                    if rule.email and tostring(value):match(EMAIL_PATTERN) == nil then
                        errors[#errors + 1] = {
                            field = field,
                            code = "invalid_email",
                            message = error_message("invalid_email")
                        }
                    end
                    if type(rule.pattern) == "string" and tostring(value):match(rule.pattern) == nil then
                        errors[#errors + 1] = {
                            field = field,
                            code = "invalid_pattern",
                            message = error_message("invalid_pattern")
                        }
                    end
                end

                if (rule.type_name == "number" or rule.type_name == "integer") and type(value) == "number" then
                    if rule.min and value < rule.min then
                        errors[#errors + 1] = {
                            field = field,
                            code = "min_violation",
                            message = error_message("min_violation")
                        }
                    end
                    if rule.max and value > rule.max then
                        errors[#errors + 1] = {
                            field = field,
                            code = "max_violation",
                            message = error_message("max_violation")
                        }
                    end
                end

                if type(rule.enum) == "table" and #rule.enum > 0 then
                    local ok_enum = false
                    local str_value = tostring(value)
                    for i = 1, #rule.enum do
                        if str_value == tostring(rule.enum[i]) then
                            ok_enum = true
                            break
                        end
                    end
                    if not ok_enum then
                        errors[#errors + 1] = {
                            field = field,
                            code = "invalid_enum",
                            message = error_message("invalid_enum")
                        }
                    end
                end
            end
        end
    end

    if #errors > 0 then
        return nil, errors
    end

    return true
end

return M
