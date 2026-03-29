local nika = require("nika")
local db = require("db")

describe("SQLite Dataware integration (Phase 11)", function()
    local temp_db_path
    local sqlite
    local connection

    before_each(function()
        nika.clear_models()
        temp_db_path = nil
        sqlite = nil
        connection = nil
    end)

    after_each(function()
        if connection and type(connection.close) == "function" then
            pcall(connection.close, connection)
        end
        if temp_db_path then
            pcall(os.remove, temp_db_path)
        end
    end)

    it("inicializa Dataware com SQLite e executa CRUD basico com tenant", function()
        local ok_require, mod = pcall(require, "lsqlite3")
        if not ok_require then
            -- Ambiente sem lsqlite3: suite permanece deterministica sem quebrar CI.
            assert.is_true(true)
            return
        end

        sqlite = mod
        temp_db_path = "tests/tmp_sqlite_dataware_" ..
        tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)) .. ".db"

        connection = sqlite.open(temp_db_path)
        assert.is_not_nil(connection)

        local ok_schema = connection:exec([[
            CREATE TABLE users (
                id INTEGER PRIMARY KEY,
                tenant_id TEXT NOT NULL,
                name TEXT NOT NULL
            );
        ]])
        assert.is_true(ok_schema == true or ok_schema == 0)

        local init_ok, init_err = nika.init_dataware_sqlite({ connection = connection })
        assert.is_true(init_ok == true)
        assert.is_nil(init_err)

        local user = nika.model("SqliteUser")
            :table("users")
            :tenant("tenant_id")

        local create_result, create_err = user:create({ id = 1, name = "Alice" }, { tenant_id = "tenant-a" })
        assert.is_not_nil(create_result)
        assert.is_nil(create_err)

        local row, row_err = user:find(1, { tenant_id = "tenant-a" }):first()
        assert.is_nil(row_err)
        assert.is_not_nil(row)
        assert.are.equal("Alice", row.name)

        local blocked_row, blocked_err = user:find(1, { tenant_id = "tenant-b" }):first()
        assert.is_nil(blocked_err)
        assert.is_true(blocked_row == nil)
    end)

    it("faz rollback real em erro de constraint dentro de transacao", function()
        local ok_require, mod = pcall(require, "lsqlite3")
        if not ok_require then
            assert.is_true(true)
            return
        end

        sqlite = mod
        temp_db_path = "tests/tmp_sqlite_tx_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)) .. ".db"

        connection = sqlite.open(temp_db_path)
        assert.is_not_nil(connection)

        local ok_schema = connection:exec([[
            CREATE TABLE users (
                id INTEGER PRIMARY KEY,
                tenant_id TEXT NOT NULL,
                name TEXT NOT NULL UNIQUE
            );
        ]])
        assert.is_true(ok_schema == true or ok_schema == 0)

        local init_ok, init_err = nika.init_dataware_sqlite({ connection = connection })
        assert.is_true(init_ok == true)
        assert.is_nil(init_err)

        local user = nika.model("SqliteTxUser")
            :table("users")
            :tenant("tenant_id")

        local tx_result, tx_err = db.with_transaction(function()
            local first, first_err = user:create({ id = 10, name = "dup" }, { tenant_id = "tenant-x" })
            if not first then
                return nil, first_err
            end

            local second, second_err = user:create({ id = 11, name = "dup" }, { tenant_id = "tenant-x" })
            if not second then
                return nil, second_err
            end

            return true
        end)

        assert.is_nil(tx_result)
        assert.are.equal("db_constraint_violation", tx_err)

        local rows, rows_err = user:find(nil, { tenant_id = "tenant-x" }):all()
        assert.is_nil(rows_err)
        assert.are.equal(0, #rows)
    end)
end)
