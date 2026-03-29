local M = {}

local function map_sqlite_error(raw_err, fallback)
    local text = string.lower(tostring(raw_err or ""))

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

    return fallback or "database_error"
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

local function finalize_stmt(stmt)
    if type(stmt) == "table" and type(stmt.finalize) == "function" then
        pcall(stmt.finalize, stmt)
    end
end

local function bind_params(stmt, params)
    if type(stmt.bind_values) == "function" then
        local ok, err = pcall(stmt.bind_values, stmt, table.unpack(params))
        if not ok then
            return nil, map_sqlite_error(err, "sqlite_bind_failed")
        end
        return true
    end

    if type(stmt.bind) == "function" then
        for i = 1, #params do
            local ok, err = pcall(stmt.bind, stmt, i, params[i])
            if not ok then
                return nil, map_sqlite_error(err, "sqlite_bind_failed")
            end
        end
        return true
    end

    return nil, "stmt_bind_not_supported"
end

local function read_rows(stmt)
    if type(stmt.nrows) == "function" then
        local rows = {}
        local ok_rows, rows_err = pcall(function()
            for row in stmt:nrows() do
                rows[#rows + 1] = row
            end
        end)
        if not ok_rows then
            return nil, map_sqlite_error(rows_err, "sqlite_read_failed")
        end
        return rows
    end

    return nil, "stmt_read_not_supported"
end

function M.new(connection)
    if type(connection) ~= "table" or type(connection.prepare) ~= "function" then
        return nil, "invalid_sqlite_connection"
    end

    local driver = {}

    local function run_direct_sql(sql)
        if type(connection.exec) == "function" then
            local ok_exec, exec_result = pcall(connection.exec, connection, sql)
            if not ok_exec then
                return nil, map_sqlite_error(exec_result, "sqlite_exec_failed")
            end

            if exec_result == false then
                local msg = nil
                if type(connection.errmsg) == "function" then
                    local ok_msg, err_msg = pcall(connection.errmsg, connection)
                    if ok_msg then
                        msg = err_msg
                    end
                end
                return nil, map_sqlite_error(msg, "sqlite_exec_failed")
            end

            return true
        end

        return driver.execute_prepared(sql, {})
    end

    function driver.execute_prepared(sql, params)
        if type(sql) ~= "string" or sql == "" then
            return nil, "invalid_sql"
        end

        if not is_dense_array(params) then
            return nil, "params_must_be_dense_array"
        end

        local ok_prepare, stmt_or_err = pcall(connection.prepare, connection, sql)
        if not ok_prepare or type(stmt_or_err) ~= "table" then
            return nil, map_sqlite_error(stmt_or_err, "sqlite_prepare_failed")
        end

        local stmt = stmt_or_err

        local ok_bind, bind_err = bind_params(stmt, params)
        if not ok_bind then
            finalize_stmt(stmt)
            return nil, bind_err
        end

        local rows, read_err = read_rows(stmt)
        finalize_stmt(stmt)
        if not rows then
            return nil, read_err
        end

        return rows
    end

    function driver.execute(sql, ...)
        local params = { ... }
        return driver.execute_prepared(sql, params)
    end

    function driver.begin()
        return run_direct_sql("BEGIN")
    end

    function driver.commit()
        return run_direct_sql("COMMIT")
    end

    function driver.rollback()
        return run_direct_sql("ROLLBACK")
    end

    return driver
end

function M.from_lsqlite3(db_path, sqlite_module)
    local mod = sqlite_module
    if mod == nil then
        local ok, loaded = pcall(require, "lsqlite3")
        if not ok then
            return nil, "sqlite_module_not_available"
        end
        mod = loaded
    end

    if type(mod) ~= "table" or type(mod.open) ~= "function" then
        return nil, "invalid_sqlite_module"
    end

    local ok_open, connection = pcall(mod.open, db_path or ":memory:")
    if not ok_open or type(connection) ~= "table" then
        return nil, "sqlite_open_failed"
    end

    return M.new(connection)
end

return M
