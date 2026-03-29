local M = {}

local has_audit, audit = pcall(require, "nika_audit")

local driver = nil

local TX_SQL = {
    begin = "BEGIN",
    commit = "COMMIT",
    rollback = "ROLLBACK"
}

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

local function count_placeholders(sql)
    local _, count = sql:gsub("%?", "?")
    return count
end

local function is_dense_array(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local n = #tbl
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 or k > n then
            return false
        end
    end
    return true
end

local function validate_param_value(v)
    local t = type(v)
    if t == "nil" or t == "boolean" or t == "number" or t == "string" then
        return true
    end
    return false
end

local function validate_sql(sql, params)
    if type(sql) ~= "string" or sql == "" then
        return nil, "invalid_sql"
    end

    if type(params) ~= "table" then
        return nil, "params_must_be_table"
    end

    if not is_dense_array(params) then
        return nil, "params_must_be_dense_array"
    end

    local placeholders = count_placeholders(sql)
    if placeholders == 0 then
        return nil, "placeholders_required"
    end

    if placeholders ~= #params then
        return nil, "placeholder_param_mismatch"
    end

    if sql:find(";", 1, true) then
        return nil, "multi_statement_not_allowed"
    end

    for i = 1, #params do
        if not validate_param_value(params[i]) then
            return nil, "invalid_param_type"
        end
    end

    return true
end

local function normalize_database_error(raw_err)
    local text = string.lower(tostring(raw_err or ""))

    if text == "db_constraint_violation" or text == "db_busy" or text == "db_locked" then
        return text
    end

    if text:find("constraint", 1, true) ~= nil or
        text:find("unique", 1, true) ~= nil or
        text:find("foreign key", 1, true) ~= nil then
        return "db_constraint_violation"
    end

    if text:find("busy", 1, true) ~= nil then
        return "db_busy"
    end

    if text:find("locked", 1, true) ~= nil or text:find("lock", 1, true) ~= nil then
        return "db_locked"
    end

    return "database_error"
end

local function ensure_driver(op)
    if type(driver) ~= "table" then
        log_error("Driver de banco nao configurado", { op = op })
        return nil, "driver_not_configured"
    end
    return true
end

local function map_and_log_driver_error(op, raw_err)
    local mapped = normalize_database_error(raw_err)
    log_error("Erro de execucao no driver", {
        op = op,
        error = tostring(raw_err),
        mapped_error = mapped
    })
    return mapped
end

local function call_driver_transaction(op)
    local ok_driver, driver_err = ensure_driver(op)
    if not ok_driver then
        return nil, driver_err
    end

    local action = driver[op]
    local call_ok, tx_result, tx_err = pcall(function()
        if type(action) == "function" then
            return action()
        end

        if type(driver.execute_prepared) == "function" then
            return driver.execute_prepared(TX_SQL[op], {})
        end

        if type(driver.execute) == "function" then
            return driver.execute(TX_SQL[op])
        end

        return nil, "driver_missing_" .. op
    end)

    if not call_ok then
        return nil, map_and_log_driver_error(op, tx_result)
    end

    if tx_result == nil and tx_err ~= nil then
        return nil, map_and_log_driver_error(op, tx_err)
    end

    return true
end

function M.set_driver(db_driver)
    if type(db_driver) ~= "table" then
        return nil, "driver_must_be_table"
    end

    local supports_execute = type(db_driver.execute) == "function"
    local supports_prepared = type(db_driver.execute_prepared) == "function"

    if not supports_execute and not supports_prepared then
        return nil, "driver_missing_execute"
    end

    driver = db_driver
    return true
end

function M.execute(sql, params)
    local ok_driver, driver_err = ensure_driver("execute")
    if not ok_driver then
        return nil, driver_err
    end

    local ok, validation_err = validate_sql(sql, params)
    if not ok then
        log_security("Query bloqueada por politica SQL segura", {
            reason = validation_err,
            sql = tostring(sql)
        })
        return nil, "invalid_query"
    end

    local call_ok, result_or_err, explicit_err = pcall(function()
        if type(driver.execute_prepared) == "function" then
            return driver.execute_prepared(sql, params)
        end

        return driver.execute(sql, table.unpack(params))
    end)

    if not call_ok then
        return nil, map_and_log_driver_error("execute", result_or_err)
    end

    if result_or_err == nil and explicit_err ~= nil then
        return nil, map_and_log_driver_error("execute", explicit_err)
    end

    return result_or_err
end

function M.begin()
    return call_driver_transaction("begin")
end

function M.commit()
    return call_driver_transaction("commit")
end

function M.rollback()
    return call_driver_transaction("rollback")
end

function M.with_transaction(work_fn)
    if type(work_fn) ~= "function" then
        return nil, "work_fn_must_be_function"
    end

    local ok_begin, begin_err = M.begin()
    if not ok_begin then
        return nil, begin_err
    end

    local ok_work, work_result, work_err = pcall(work_fn)
    if not ok_work then
        local _, rollback_err = M.rollback()
        log_error("Transacao revertida por excecao", {
            error = tostring(work_result),
            rollback_error = rollback_err
        })
        return nil, "transaction_failed"
    end

    if work_result == nil and work_err ~= nil then
        local _, rollback_err = M.rollback()
        log_error("Transacao revertida por erro de operacao", {
            error = tostring(work_err),
            rollback_error = rollback_err
        })
        return nil, work_err
    end

    local ok_commit, commit_err = M.commit()
    if not ok_commit then
        local _, rollback_err = M.rollback()
        log_error("Transacao revertida por falha no commit", {
            error = tostring(commit_err),
            rollback_error = rollback_err
        })
        return nil, commit_err
    end

    return work_result, work_err
end

return M
