local sqlite_driver = require("sqlite_driver")

local function make_stmt(rows)
    local stmt = {
        finalized = false,
        bound = nil,
        _rows = rows or {}
    }

    function stmt:bind_values(...)
        self.bound = { ... }
    end

    function stmt:nrows()
        local i = 0
        return function()
            i = i + 1
            return self._rows[i]
        end
    end

    function stmt:finalize()
        self.finalized = true
    end

    return stmt
end

describe("SQLite driver (Phase 11 - implementation start)", function()
    it("executa SQL preparado e retorna linhas", function()
        local captured_sql = nil
        local stmt = make_stmt({
            { id = 1, name = "Alice" },
            { id = 2, name = "Bob" }
        })

        local driver, err = sqlite_driver.new({
            prepare = function(_, sql)
                captured_sql = sql
                return stmt
            end
        })

        assert.is_nil(err)

        local rows, exec_err = driver.execute_prepared("SELECT * FROM users WHERE id = ?", { 1 })
        assert.is_nil(exec_err)
        assert.are.equal("SELECT * FROM users WHERE id = ?", captured_sql)
        assert.are.equal(2, #rows)
        assert.are.equal(1, stmt.bound[1])
        assert.is_true(stmt.finalized)
    end)

    it("suporta execute com varargs", function()
        local stmt = make_stmt({ { ok = true } })

        local driver = sqlite_driver.new({
            prepare = function()
                return stmt
            end
        })

        local rows, exec_err = driver.execute("SELECT * FROM users WHERE id = ? AND active = ?", 10, true)
        assert.is_nil(exec_err)
        assert.are.equal(1, #rows)
        assert.are.equal(10, stmt.bound[1])
        assert.are.equal(true, stmt.bound[2])
    end)

    it("retorna erro quando prepare falha", function()
        local driver = sqlite_driver.new({
            prepare = function()
                error("prepare failed")
            end
        })

        local rows, exec_err = driver.execute_prepared("SELECT 1 WHERE id = ?", { 1 })
        assert.is_nil(rows)
        assert.are.equal("sqlite_prepare_failed", exec_err)
    end)

    it("retorna erro em params invalidos", function()
        local driver = sqlite_driver.new({
            prepare = function()
                return make_stmt()
            end
        })

        local rows, exec_err = driver.execute_prepared("SELECT 1 WHERE id = ?", { [2] = 1 })
        assert.is_nil(rows)
        assert.are.equal("params_must_be_dense_array", exec_err)
    end)

    it("from_lsqlite3 usa modulo injetado", function()
        local stmt = make_stmt({ { id = 1 } })
        local fake_module = {
            open = function(path)
                assert.are.equal(":memory:", path)
                return {
                    prepare = function()
                        return stmt
                    end
                }
            end
        }

        local driver, err = sqlite_driver.from_lsqlite3(":memory:", fake_module)
        assert.is_nil(err)

        local rows, exec_err = driver.execute_prepared("SELECT * FROM users WHERE id = ?", { 1 })
        assert.is_nil(exec_err)
        assert.are.equal(1, #rows)
    end)
end)
