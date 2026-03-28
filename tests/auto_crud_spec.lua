local db = require("db")
local dataware = require("dataware")
local auto_crud = require("auto_crud")
local router_v2 = require("router_v2")

describe("Auto CRUD generator (Phase 11)", function()
    before_each(function()
        dataware.clear()
        router_v2.clear()

        db.set_driver({
            execute_prepared = function(sql, params)
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
        assert.is_true(res.body:find("tenant_required") ~= nil)
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
        assert.is_true(res.body:find("body_table_required") ~= nil)
    end)
end)
