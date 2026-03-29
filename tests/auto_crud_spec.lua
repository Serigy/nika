local db = require("db")
local dataware = require("dataware")
local auto_crud = require("auto_crud")
local router_v2 = require("router_v2")

describe("Auto CRUD generator (Phase 11)", function()
    local calls

    before_each(function()
        calls = {}
        dataware.clear()
        router_v2.clear()

        db.set_driver({
            execute_prepared = function(sql, params)
                calls[#calls + 1] = { sql = sql, params = params }
                if sql:match("COUNT%(%*%)") then
                    return { { total = 1 } }
                end
                return { { id = 1, name = "Alice" } }
            end
        })
    end)

    it("gera 5 rotas CRUD", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        local routes = auto_crud.generate(user, router_v2, { base_path = "/users" })

        assert.is_not_nil(routes.list)
        assert.is_not_nil(routes.get)
        assert.is_not_nil(routes.create)
        assert.is_not_nil(routes.update)
        assert.is_not_nil(routes.delete)
    end)

    it("handler list retorna 403 sem tenant", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler = router_v2.match("GET", "/users")
        local res = { status = 200, headers = {}, body = "" }
        handler({ headers = {}, query = {} }, res)

        assert.are.equal(403, res.status)
        assert.is_true(tostring(res.body):find("Tenant context required") ~= nil)
    end)

    it("permite tenant via middleware customizado", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, {
            base_path = "/users",
            tenant_middleware = function(req, res, context)
                context.tenant_id = "tenant-from-middleware"
                return false
            end
        })

        local handler = router_v2.match("GET", "/users")
        local res = { status = 200, headers = {}, body = "" }
        handler({ headers = {}, query = {} }, res)

        assert.are.equal(200, res.status)
        assert.is_true(res.body:find("\"data\"") ~= nil)
    end)

    it("bloqueia middleware customizado sem tenant no context", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, {
            base_path = "/users",
            tenant_middleware = function()
                return false
            end
        })

        local handler = router_v2.match("GET", "/users")
        local res = { status = 200, headers = {}, body = "" }
        handler({ headers = {}, query = {} }, res)

        assert.are.equal(403, res.status)
        assert.is_true(res.body:find('"code":"tenant_required"', 1, true) ~= nil)
        assert.is_true(res.body:find('"message":"Tenant context required"', 1, true) ~= nil)
        assert.is_true(res.body:find('"retryable":false', 1, true) ~= nil)
    end)

    it("respeita short-circuit do middleware de tenant", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, {
            base_path = "/users",
            tenant_middleware = function(req, res)
                res.status = 401
                res.body = "blocked-by-middleware"
                return true
            end
        })

        local handler = router_v2.match("GET", "/users")
        local res = { status = 200, headers = {}, body = "" }
        handler({ headers = {}, query = {} }, res)

        assert.are.equal(401, res.status)
        assert.are.equal("blocked-by-middleware", res.body)
    end)

    it("retorna 400 em create sem body_table", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler = router_v2.match("POST", "/users")
        local res = { status = 200, headers = {}, body = "" }
        handler({ headers = { ["X-Tenant-Id"] = "t-1" } }, res)

        assert.are.equal(400, res.status)
        assert.is_true(res.body:find('"code":"body_table_required"', 1, true) ~= nil)
        assert.is_true(res.body:find('"message":"Request body table is required"', 1, true) ~= nil)
        assert.is_true(res.body:find('"retryable":false', 1, true) ~= nil)
    end)

    it("executa update com tenant e where por id", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler, match_err, params = router_v2.match("PUT", "/users/42")
        assert.is_nil(match_err)

        local req = {
            headers = { ["X-Tenant-Id"] = "t-1" },
            params = params,
            body_table = { name = "Neo" }
        }
        local res = { status = 200, headers = {}, body = "" }

        handler(req, res)

        assert.are.equal(200, res.status)
        assert.is_true(#calls >= 1)
        assert.is_true(calls[#calls].sql:find("UPDATE users SET", 1, true) ~= nil)
        assert.is_true(calls[#calls].sql:find("tenant_id = %?") ~= nil)
        assert.is_true(calls[#calls].sql:find("id = %?") ~= nil)
    end)

    it("executa delete com tenant e where por id", function()
        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler, match_err, params = router_v2.match("DELETE", "/users/42")
        assert.is_nil(match_err)

        local req = {
            headers = { ["X-Tenant-Id"] = "t-1" },
            params = params
        }
        local res = { status = 200, headers = {}, body = "" }

        handler(req, res)

        assert.are.equal(200, res.status)
        assert.is_true(#calls >= 1)
        assert.is_true(calls[#calls].sql:find("DELETE FROM users", 1, true) ~= nil)
        assert.is_true(calls[#calls].sql:find("tenant_id = %?") ~= nil)
        assert.is_true(calls[#calls].sql:find("id = %?") ~= nil)
    end)

    it("mapeia constraint para 409 no create", function()
        db.set_driver({
            execute_prepared = function(sql, params)
                return nil, "db_constraint_violation"
            end
        })

        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler = router_v2.match("POST", "/users")
        local req = {
            headers = { ["X-Tenant-Id"] = "t-1" },
            body_table = { name = "Duplicado" }
        }
        local res = { status = 200, headers = {}, body = "" }

        handler(req, res)

        assert.are.equal(409, res.status)
        assert.is_true(res.body:find('"code":"db_constraint_violation"', 1, true) ~= nil)
        assert.is_true(res.body:find('"message":"Database constraint violation"', 1, true) ~= nil)
        assert.is_true(res.body:find('"retryable":false', 1, true) ~= nil)
    end)

    it("mapeia busy para 503 no update", function()
        db.set_driver({
            execute_prepared = function(sql, params)
                if sql:find("UPDATE users SET", 1, true) ~= nil then
                    return nil, "db_busy"
                end
                return { { id = 1 } }
            end
        })

        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler, match_err, params = router_v2.match("PUT", "/users/7")
        assert.is_nil(match_err)

        local req = {
            headers = { ["X-Tenant-Id"] = "t-1" },
            params = params,
            body_table = { name = "Busy" }
        }
        local res = { status = 200, headers = {}, body = "" }

        handler(req, res)

        assert.are.equal(503, res.status)
        assert.is_true(res.body:find('"code":"db_busy"', 1, true) ~= nil)
        assert.is_true(res.body:find('"message":"Database temporarily busy"', 1, true) ~= nil)
        assert.is_true(res.body:find('"retryable":true', 1, true) ~= nil)
    end)

    it("mapeia locked para 503 no delete", function()
        db.set_driver({
            execute_prepared = function(sql, params)
                if sql:find("DELETE FROM users", 1, true) ~= nil then
                    return nil, "db_locked"
                end
                return { { id = 1 } }
            end
        })

        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler, match_err, params = router_v2.match("DELETE", "/users/7")
        assert.is_nil(match_err)

        local req = {
            headers = { ["X-Tenant-Id"] = "t-1" },
            params = params
        }
        local res = { status = 200, headers = {}, body = "" }

        handler(req, res)

        assert.are.equal(503, res.status)
        assert.is_true(res.body:find('"code":"db_locked"', 1, true) ~= nil)
        assert.is_true(res.body:find('"message":"Database temporarily locked"', 1, true) ~= nil)
        assert.is_true(res.body:find('"retryable":true', 1, true) ~= nil)
    end)

    it("retorna contrato estavel para not_found", function()
        db.set_driver({
            execute_prepared = function(sql, params)
                return {}
            end
        })

        local user = dataware.model("User")
            :table("users")
            :tenant("tenant_id")

        auto_crud.generate(user, router_v2, { base_path = "/users" })

        local handler, match_err, params = router_v2.match("GET", "/users/99")
        assert.is_nil(match_err)

        local req = {
            headers = { ["X-Tenant-Id"] = "t-1" },
            params = params
        }
        local res = { status = 200, headers = {}, body = "" }

        handler(req, res)

        assert.are.equal(404, res.status)
        assert.is_true(res.body:find('"code":"not_found"', 1, true) ~= nil)
        assert.is_true(res.body:find('"message":"Resource not found"', 1, true) ~= nil)
        assert.is_true(res.body:find('"retryable":false', 1, true) ~= nil)
    end)
end)
