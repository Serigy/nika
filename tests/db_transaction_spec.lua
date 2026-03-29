local db = require("db")

describe("DB wrapper transactions", function()
    it("executa transacao com commit no caminho feliz", function()
        local calls = {}

        local ok_set, set_err = db.set_driver({
            begin = function()
                calls[#calls + 1] = "begin"
                return true
            end,
            commit = function()
                calls[#calls + 1] = "commit"
                return true
            end,
            rollback = function()
                calls[#calls + 1] = "rollback"
                return true
            end,
            execute_prepared = function(sql, params)
                return { { ok = true } }
            end
        })

        assert.is_true(ok_set == true)
        assert.is_nil(set_err)

        local result, err = db.with_transaction(function()
            local rows, exec_err = db.execute("SELECT * FROM users WHERE id = ?", { 1 })
            if not rows then
                return nil, exec_err
            end
            return "ok"
        end)

        assert.are.equal("ok", result)
        assert.is_nil(err)
        assert.are.equal("begin", calls[1])
        assert.are.equal("commit", calls[2])
        assert.is_true(#calls == 2)
    end)

    it("faz rollback quando callback dispara excecao", function()
        local calls = {}
        db.set_driver({
            begin = function()
                calls[#calls + 1] = "begin"
                return true
            end,
            commit = function()
                calls[#calls + 1] = "commit"
                return true
            end,
            rollback = function()
                calls[#calls + 1] = "rollback"
                return true
            end,
            execute_prepared = function(sql, params)
                return { { ok = true } }
            end
        })

        local result, err = db.with_transaction(function()
            error("falha no bloco transacional")
        end)

        assert.is_nil(result)
        assert.are.equal("transaction_failed", err)
        assert.are.equal("begin", calls[1])
        assert.are.equal("rollback", calls[2])
        assert.is_true(#calls == 2)
    end)

    it("faz rollback quando callback retorna erro de negocio", function()
        local calls = {}
        db.set_driver({
            begin = function()
                calls[#calls + 1] = "begin"
                return true
            end,
            commit = function()
                calls[#calls + 1] = "commit"
                return true
            end,
            rollback = function()
                calls[#calls + 1] = "rollback"
                return true
            end,
            execute_prepared = function(sql, params)
                return { { ok = true } }
            end
        })

        local result, err = db.with_transaction(function()
            return nil, "db_constraint_violation"
        end)

        assert.is_nil(result)
        assert.are.equal("db_constraint_violation", err)
        assert.are.equal("begin", calls[1])
        assert.are.equal("rollback", calls[2])
        assert.is_true(#calls == 2)
    end)

    it("mapeia constraint busy e locked para codigos padronizados", function()
        local function assert_mapped(raw_err, expected)
            db.set_driver({
                execute_prepared = function(sql, params)
                    return nil, raw_err
                end
            })

            local rows, err = db.execute("SELECT * FROM users WHERE id = ?", { 1 })
            assert.is_nil(rows)
            assert.are.equal(expected, err)
        end

        assert_mapped("UNIQUE constraint failed: users.email", "db_constraint_violation")
        assert_mapped("database is busy", "db_busy")
        assert_mapped("database table is locked", "db_locked")
    end)
end)
