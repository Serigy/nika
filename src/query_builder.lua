local db = require("db")
local dataware_audit = require("dataware_audit")

local M = {}

local ALLOWED_OPERATORS = {
    ["="] = true,
    ["!="] = true,
    ["<>"] = true,
    [">"] = true,
    ["<"] = true,
    [">="] = true,
    ["<="] = true,
    ["LIKE"] = true,
    ["IN"] = true
}

local function sanitize_identifier(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return nil
    end
    if not identifier:match("^[a-zA-Z_][a-zA-Z0-9_%.]*$") then
        return nil
    end
    return identifier
end

local function sorted_keys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

local Builder = {}
Builder.__index = Builder

local function apply_eager_loading(self, rows)
    if type(rows) ~= "table" or #self._with == 0 then
        return rows, nil
    end

    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" then
            for j = 1, #self._with do
                local relation_name = self._with[j]
                local relation = self._relations[relation_name]
                if relation then
                    local local_value = row[relation.local_key]
                    if local_value == nil then
                        row[relation_name] = {}
                    else
                        local relation_context = { tenant_id = self._tenant_id }
                        local relation_rows, rel_err = relation.model:find(nil, relation_context)
                            :where(relation.foreign_key, "=", local_value)
                            :all()
                        if not relation_rows then
                            return nil, "eager_load_failed:" .. relation_name .. ":" .. tostring(rel_err)
                        end

                        if relation.type == "has_many" then
                            row[relation_name] = relation_rows
                        else
                            row[relation_name] = relation_rows[1]
                        end
                    end
                end
            end
        end
    end

    return rows, nil
end

local function collect_where_parts(self)
    local clauses = { "1 = ?" }
    local params = { 1 }

    if self._require_tenant then
        if self._tenant_id == nil or self._tenant_id == "" then
            dataware_audit.log_tenant_violation(self._model_name, "query")
            return nil, nil, "tenant_required"
        end
        clauses[#clauses + 1] = self._tenant_field .. " = ?"
        params[#params + 1] = self._tenant_id
    end

    for i = 1, #self._where do
        local part = self._where[i]
        clauses[#clauses + 1] = part.sql
        for j = 1, #part.params do
            params[#params + 1] = part.params[j]
        end
    end

    return clauses, params, nil
end

function Builder:set_tenant_id(tenant_id)
    self._tenant_id = tenant_id
    return self
end

function Builder:select(...)
    local args = { ... }
    if #args == 0 then
        return self
    end

    local cleaned = {}
    for i = 1, #args do
        local safe = sanitize_identifier(args[i])
        if not safe then
            error("invalid_select_column")
        end
        cleaned[#cleaned + 1] = safe
    end

    self._select = cleaned
    return self
end

function Builder:with(...)
    local args = { ... }
    if #args == 0 then
        return self
    end

    for i = 1, #args do
        local name = args[i]
        if type(name) ~= "string" or name == "" then
            error("invalid_relation_name")
        end
        if not self._relations[name] then
            error("relation_not_found")
        end
        self._with[#self._with + 1] = name
    end

    return self
end

function Builder:where(column, operator, value)
    local safe_col = sanitize_identifier(column)
    if not safe_col then
        error("invalid_where_column")
    end

    local op = tostring(operator or "="):upper()
    if not ALLOWED_OPERATORS[op] then
        error("invalid_where_operator")
    end

    if op == "IN" then
        if type(value) ~= "table" or #value == 0 then
            error("invalid_in_values")
        end
        local holders = {}
        for i = 1, #value do
            holders[#holders + 1] = "?"
        end
        self._where[#self._where + 1] = {
            sql = safe_col .. " IN (" .. table.concat(holders, ",") .. ")",
            params = value
        }
        return self
    end

    self._where[#self._where + 1] = {
        sql = safe_col .. " " .. op .. " ?",
        params = { value }
    }

    return self
end

function Builder:order_by(column, direction)
    local safe_col = sanitize_identifier(column)
    if not safe_col then
        error("invalid_order_column")
    end

    local dir = tostring(direction or "ASC"):upper()
    if dir ~= "ASC" and dir ~= "DESC" then
        error("invalid_order_direction")
    end

    self._order_by = safe_col .. " " .. dir
    return self
end

function Builder:limit(value)
    local n = tonumber(value)
    if not n or n < 1 then
        error("invalid_limit")
    end
    self._limit = math.floor(n)
    return self
end

function Builder:offset(value)
    local n = tonumber(value)
    if not n or n < 0 then
        error("invalid_offset")
    end
    self._offset = math.floor(n)
    return self
end

function Builder:_build_select_sql()
    local clauses, params, err = collect_where_parts(self)
    if err then
        return nil, nil, err
    end

    local sql = "SELECT " .. table.concat(self._select, ",") .. " FROM " .. self._table
    sql = sql .. " WHERE " .. table.concat(clauses, " AND ")

    if self._order_by then
        sql = sql .. " ORDER BY " .. self._order_by
    end

    if self._limit then
        sql = sql .. " LIMIT ?"
        params[#params + 1] = self._limit
    end

    if self._offset then
        sql = sql .. " OFFSET ?"
        params[#params + 1] = self._offset
    end

    return sql, params, nil
end

function Builder:all()
    local sql, params, err = self:_build_select_sql()
    if err then
        return nil, err
    end
    local result, db_err = db.execute(sql, params)
    if not result then
        return nil, db_err
    end

    local loaded, load_err = apply_eager_loading(self, result)
    if not loaded then
        return nil, load_err
    end

    return loaded
end

function Builder:first()
    local original_limit = self._limit
    self._limit = 1
    local rows, err = self:all()
    self._limit = original_limit

    if not rows then
        return nil, err
    end

    if type(rows) == "table" then
        return rows[1]
    end

    return rows
end

function Builder:paginate(page, per_page)
    local p = tonumber(page) or 1
    local pp = tonumber(per_page) or 10

    if p < 1 then p = 1 end
    if pp < 1 then pp = 10 end

    if pp > 100 then
        pp = 100
    end

    local clauses, params, err = collect_where_parts(self)
    if err then
        return nil, nil, err
    end

    local count_sql = "SELECT COUNT(*) AS total FROM " .. self._table .. " WHERE " .. table.concat(clauses, " AND ")
    local count_rows, count_err = db.execute(count_sql, params)
    if not count_rows then
        return nil, nil, count_err
    end

    local total = 0
    if type(count_rows) == "table" and count_rows[1] then
        total = tonumber(count_rows[1].total or count_rows[1][1]) or 0
    end

    local original_limit = self._limit
    local original_offset = self._offset
    self._limit = pp
    self._offset = (p - 1) * pp

    local list, list_err = self:all()

    self._limit = original_limit
    self._offset = original_offset

    if not list then
        return nil, nil, list_err
    end

    return list, total
end

function Builder:create(data)
    if type(data) ~= "table" then
        return nil, "invalid_create_data"
    end

    local payload = {}
    for k, v in pairs(data) do
        payload[k] = v
    end

    if self._require_tenant then
        if self._tenant_id == nil or self._tenant_id == "" then
            return nil, "tenant_required"
        end
        if payload[self._tenant_field] == nil then
            payload[self._tenant_field] = self._tenant_id
        end
    end

    local keys = sorted_keys(payload)
    if #keys == 0 then
        return nil, "empty_create_data"
    end

    local columns = {}
    local holders = {}
    local params = {}

    for i = 1, #keys do
        local key = sanitize_identifier(keys[i])
        if not key then
            return nil, "invalid_create_column"
        end
        columns[#columns + 1] = key
        holders[#holders + 1] = "?"
        params[#params + 1] = payload[keys[i]]
    end

    local sql = "INSERT INTO " ..
        self._table .. " (" .. table.concat(columns, ",") .. ") VALUES (" .. table.concat(holders, ",") .. ")"
    local result, err = db.execute(sql, params)
    if not result then
        return nil, err
    end

    dataware_audit.log_create(self._model_name, payload, self._tenant_id)
    return result
end

function Builder:update(data)
    if type(data) ~= "table" then
        return nil, "invalid_update_data"
    end

    if #self._where == 0 then
        return nil, "where_required_for_update"
    end

    local keys = sorted_keys(data)
    if #keys == 0 then
        return nil, "empty_update_data"
    end

    local set_parts = {}
    local params = {}

    for i = 1, #keys do
        local key = sanitize_identifier(keys[i])
        if not key then
            return nil, "invalid_update_column"
        end
        set_parts[#set_parts + 1] = key .. " = ?"
        params[#params + 1] = data[keys[i]]
    end

    local clauses, where_params, err = collect_where_parts(self)
    if err then
        return nil, err
    end

    for i = 1, #where_params do
        params[#params + 1] = where_params[i]
    end

    local sql = "UPDATE " ..
        self._table .. " SET " .. table.concat(set_parts, ",") .. " WHERE " .. table.concat(clauses, " AND ")
    local result, db_err = db.execute(sql, params)
    if not result then
        return nil, db_err
    end

    dataware_audit.log_update(self._model_name, nil, data, self._tenant_id)
    return result
end

function Builder:delete()
    if #self._where == 0 then
        return nil, "where_required_for_delete"
    end

    local clauses, params, err = collect_where_parts(self)
    if err then
        return nil, err
    end

    local sql = "DELETE FROM " .. self._table .. " WHERE " .. table.concat(clauses, " AND ")
    local result, db_err = db.execute(sql, params)
    if not result then
        return nil, db_err
    end

    dataware_audit.log_delete(self._model_name, { filters = self._where }, self._tenant_id)
    return result
end

function Builder:debug_sql()
    local sql, params, err = self:_build_select_sql()
    return sql, params, err
end

function M.new(model_definition, context)
    if type(model_definition) ~= "table" then
        error("model_definition must be table")
    end

    if not sanitize_identifier(model_definition.table_name) then
        error("invalid_table_name")
    end

    local tenant_field = model_definition.tenant_field or "tenant_id"
    if not sanitize_identifier(tenant_field) then
        error("invalid_tenant_field")
    end

    local builder = setmetatable({
        _model_name = model_definition.name,
        _table = model_definition.table_name,
        _select = { "*" },
        _where = {},
        _with = {},
        _relations = model_definition.relations or {},
        _order_by = nil,
        _limit = nil,
        _offset = nil,
        _require_tenant = model_definition.require_tenant == true,
        _tenant_field = tenant_field,
        _tenant_id = context and context.tenant_id or nil
    }, Builder)

    return builder
end

return M
