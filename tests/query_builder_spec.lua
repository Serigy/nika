local db = require("db")
local dataware = require("dataware")

local original_dataware_audit = package.loaded["dataware_audit"]

local function reload_query_builder_with_audit_stub(stub)
    package.loaded["query_builder"] = nil
    package.loaded["dataware_audit"] = stub
    return require("query_builder")
end

local function restore_query_builder_modules()
    package.loaded["query_builder"] = nil
    package.loaded["dataware_audit"] = original_dataware_audit
end

describe("Query Builder (Phase 11)", function()
    local calls

    before_each(function()
        calls = {}
        dataware.clear()

        db.set_driver({
            execute_prepared = function(sql, params)
                calls[#calls + 1] = { sql = sql, params = params }

                if sql:match("FROM posts") then
                    local user_id = params[#params]
                    return {
                        { id = 100 + tonumber(user_id), user_id = user_id, title = "Post " .. tostring(user_id) }
                    }
                end

                if sql:match("COUNT%(%*%)") then
                    return { { total = 2 } }
                end

                return {
                    { id = 1, name = "Alice" },
                    { id = 2, name = "Bob" }
                }
            end
        })
    end)

    it("monta select com where e tenant obrigatorio", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local rows, err = user:find(nil, { tenant_id = "t-1" })
            :where("active", "=", true)
            :order_by("id", "desc")
            :limit(10)
            :all()

        assert.is_not_nil(rows)
        assert.is_nil(err)
        assert.is_true(#calls >= 1)
        assert.is_true(calls[1].sql:find("tenant_id = %?") ~= nil)
    end)

    it("nao permite bypass de tenant via where manual", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local sql, params, err = user:find(nil, { tenant_id = "tenant-safe" })
            :where("tenant_id", "=", "tenant-forjado")
            :debug_sql()

        assert.is_nil(err)
        assert.is_true(sql:find("tenant_id = %?") ~= nil)
        assert.are.equal("tenant-safe", params[2])
        assert.are.equal("tenant-forjado", params[3])
    end)

    it("carrega relacao eager com with", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local post = dataware.model("Post")
            :table("posts")
            :tenant("tenant_id")

        user:has_many("posts", post, "user_id", "id")

        local rows, err = user:find(nil, { tenant_id = "t-1" }):with("posts"):all()
        assert.is_nil(err)
        assert.is_true(type(rows[1].posts) == "table")
        assert.is_true(#rows[1].posts >= 1)
        assert.are.equal(rows[1].id, rows[1].posts[1].user_id)
    end)

    it("falha sem tenant quando tenant e obrigatorio", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local rows, err = user:find():all()
        assert.is_nil(rows)
        assert.are.equal("tenant_required", err)
    end)

    it("executa paginate com total", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local rows, total, err = user:find(nil, { tenant_id = "t-2" }):paginate(1, 5)
        assert.is_not_nil(rows)
        assert.are.equal(2, total)
        assert.is_nil(err)
    end)

    it("audita tenant ausente em select", function()
        local events = {}
        local qb = reload_query_builder_with_audit_stub({
            log_tenant_violation = function(model_name, operation)
                events[#events + 1] = { model = model_name, operation = operation }
            end,
            log_create = function() end,
            log_update = function() end,
            log_delete = function() end
        })

        local model_def = {
            name = "User",
            table_name = "users",
            require_tenant = true,
            tenant_field = "tenant_id"
        }

        local rows, err = qb.new(model_def, {}):all()
        restore_query_builder_modules()

        assert.is_nil(rows)
        assert.are.equal("tenant_required", err)
        assert.are.equal(1, #events)
        assert.are.equal("select", events[1].operation)
    end)

    it("audita tenant ausente em create", function()
        local events = {}
        local qb = reload_query_builder_with_audit_stub({
            log_tenant_violation = function(model_name, operation)
                events[#events + 1] = { model = model_name, operation = operation }
            end,
            log_create = function() end,
            log_update = function() end,
            log_delete = function() end
        })

        local model_def = {
            name = "User",
            table_name = "users",
            require_tenant = true,
            tenant_field = "tenant_id"
        }

        local result, err = qb.new(model_def, {}):create({ name = "x" })
        restore_query_builder_modules()

        assert.is_nil(result)
        assert.are.equal("tenant_required", err)
        assert.are.equal(1, #events)
        assert.are.equal("create", events[1].operation)
    end)

    it("audita tenant ausente em update", function()
        local events = {}
        local qb = reload_query_builder_with_audit_stub({
            log_tenant_violation = function(model_name, operation)
                events[#events + 1] = { model = model_name, operation = operation }
            end,
            log_create = function() end,
            log_update = function() end,
            log_delete = function() end
        })

        local model_def = {
            name = "User",
            table_name = "users",
            require_tenant = true,
            tenant_field = "tenant_id"
        }

        local result, err = qb.new(model_def, {}):where("id", "=", 10):update({ name = "x" })
        restore_query_builder_modules()

        assert.is_nil(result)
        assert.are.equal("tenant_required", err)
        assert.are.equal(1, #events)
        assert.are.equal("update", events[1].operation)
    end)

    it("audita tenant ausente em delete", function()
        local events = {}
        local qb = reload_query_builder_with_audit_stub({
            log_tenant_violation = function(model_name, operation)
                events[#events + 1] = { model = model_name, operation = operation }
            end,
            log_create = function() end,
            log_update = function() end,
            log_delete = function() end
        })

        local model_def = {
            name = "User",
            table_name = "users",
            require_tenant = true,
            tenant_field = "tenant_id"
        }

        local result, err = qb.new(model_def, {}):where("id", "=", 10):delete()
        restore_query_builder_modules()

        assert.is_nil(result)
        assert.are.equal("tenant_required", err)
        assert.are.equal(1, #events)
        assert.are.equal("delete", events[1].operation)
    end)

    it("aplica tenant automaticamente em update e delete", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local update_result, update_err = user:find(nil, { tenant_id = "t-1" })
            :where("id", "=", 42)
            :update({ name = "Jane" })

        assert.is_not_nil(update_result)
        assert.is_nil(update_err)
        assert.is_true(calls[1].sql:find("UPDATE users SET", 1, true) ~= nil)
        assert.is_true(calls[1].sql:find("tenant_id = %?") ~= nil)

        local delete_result, delete_err = user:find(nil, { tenant_id = "t-1" })
            :where("id", "=", 42)
            :delete()

        assert.is_not_nil(delete_result)
        assert.is_nil(delete_err)
        assert.is_true(calls[2].sql:find("DELETE FROM users", 1, true) ~= nil)
        assert.is_true(calls[2].sql:find("tenant_id = %?") ~= nil)
    end)

    it("suporta tenant field customizado", function()
        local account_user = dataware.model("AccountUser")
            :table("account_users")
            :tenant("account_id")

        local sql, params, err = account_user:find(nil, { tenant_id = "acc-1" })
            :where("active", "=", true)
            :debug_sql()

        assert.is_nil(err)
        assert.is_true(sql:find("account_id = %?") ~= nil)
        assert.are.equal("acc-1", params[2])
    end)

    it("mantem payload hostil em LIKE como parametro", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local payload = "%'; DROP TABLE users; --%"
        local sql, params, err = user:find(nil, { tenant_id = "t-like" })
            :where("name", "LIKE", payload)
            :debug_sql()

        assert.is_nil(err)
        assert.is_true(sql:find("name LIKE %?") ~= nil)
        assert.are.equal(payload, params[3])
    end)
end)
