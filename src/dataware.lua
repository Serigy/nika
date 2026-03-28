local query_builder = require("query_builder")
local auto_crud = require("auto_crud")

local M = {}

local _models = {}

local function default_table_name(name)
    return string.lower(name) .. "s"
end

local function copy_table(input)
    local out = {}
    for k, v in pairs(input or {}) do
        out[k] = v
    end
    return out
end

local function build_model(def)
    local model = {}

    function model:name()
        return def.name
    end

    function model:schema(schema_def)
        if type(schema_def) ~= "table" then
            error("schema must be table")
        end
        def.schema = copy_table(schema_def)
        return self
    end

    function model:table(table_name)
        if type(table_name) ~= "string" or table_name == "" then
            error("table name must be string")
        end
        def.table_name = table_name
        return self
    end

    function model:primary_key(pk)
        if type(pk) ~= "string" or pk == "" then
            error("primary key must be string")
        end
        def.primary_key = pk
        return self
    end

    function model:tenant(field_name)
        def.require_tenant = true
        if field_name ~= nil then
            if type(field_name) ~= "string" or field_name == "" then
                error("tenant field must be string")
            end
            def.tenant_field = field_name
        end
        return self
    end

    function model:without_tenant()
        def.require_tenant = false
        return self
    end

    function model:has_many(name, related_model, foreign_key, local_key)
        if type(name) ~= "string" or name == "" then
            error("relation name must be string")
        end
        if type(related_model) ~= "table" or type(related_model.find) ~= "function" then
            error("related model must be a model")
        end
        if type(foreign_key) ~= "string" or foreign_key == "" then
            error("foreign key must be string")
        end

        def.relations[name] = {
            type = "has_many",
            model = related_model,
            foreign_key = foreign_key,
            local_key = local_key or def.primary_key
        }
        return self
    end

    function model:find(id, context)
        local qb = query_builder.new(def, context)
        if id ~= nil then
            qb:where(def.primary_key, "=", id)
        end
        return qb
    end

    function model:create(data, context)
        return query_builder.new(def, context):create(data)
    end

    function model:auto_crud(router, opts)
        return auto_crud.generate(self, router, opts)
    end

    function model:info()
        return {
            name = def.name,
            table_name = def.table_name,
            schema = copy_table(def.schema),
            primary_key = def.primary_key,
            require_tenant = def.require_tenant,
            tenant_field = def.tenant_field
        }
    end

    return model
end

function M.model(name)
    if type(name) ~= "string" or name == "" then
        error("model name must be string")
    end

    if _models[name] then
        return _models[name]
    end

    local def = {
        name = name,
        table_name = default_table_name(name),
        schema = {},
        primary_key = "id",
        require_tenant = true,
        tenant_field = "tenant_id",
        relations = {}
    }

    local model = build_model(def)
    _models[name] = model
    return model
end

function M.get(name)
    return _models[name]
end

function M.list()
    local out = {}
    for name, model in pairs(_models) do
        out[#out + 1] = {
            name = name,
            table_name = model:info().table_name
        }
    end
    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

function M.clear()
    _models = {}
end

return M
