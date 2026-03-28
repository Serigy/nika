local dataware_tenancy = require("dataware_tenancy")

describe("Dataware tenancy (Phase 11)", function()
    it("extrai tenant por header padrao", function()
        local tenant = dataware_tenancy.extract_tenant_id({
            headers = {
                ["X-Tenant-Id"] = "tenant-abc"
            }
        })

        assert.are.equal("tenant-abc", tenant)
    end)

    it("middleware injeta tenant no context e nao bloqueia", function()
        local middleware = dataware_tenancy.create_middleware()
        local context = {}
        local res = { status = 200, body = "" }

        local stop = middleware({
            headers = {
                ["X-Tenant-Id"] = "tenant-xyz"
            }
        }, res, context)

        assert.is_true(stop == false)
        assert.are.equal("tenant-xyz", context.tenant_id)
    end)

    it("middleware falha fechado sem tenant", function()
        local middleware = dataware_tenancy.create_middleware()
        local res = { status = 200, body = "" }
        local context = {}

        local stop = middleware({ headers = {} }, res, context)

        assert.is_true(stop)
        assert.are.equal(403, res.status)
        assert.is_true(tostring(res.body):find("Tenant context required", 1, true) ~= nil)
    end)
end)
