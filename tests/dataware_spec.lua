local dataware = require("dataware")

describe("Dataware registry (Phase 11)", function()
    before_each(function()
        dataware.clear()
    end)

    it("registra modelo com schema e tabela customizada", function()
        local user = dataware.model("User")
            :schema({ id = "integer|pk", name = "string" })
            :table("users")

        local info = user:info()
        assert.are.equal("User", info.name)
        assert.are.equal("users", info.table_name)
        assert.is_true(info.require_tenant)
    end)

    it("lista modelos registrados", function()
        dataware.model("User")
        dataware.model("Post")

        local list = dataware.list()
        assert.are.equal(2, #list)
        assert.are.equal("Post", list[1].name)
        assert.are.equal("User", list[2].name)
    end)

    it("permite desabilitar tenant por modelo", function()
        local catalog = dataware.model("Catalog"):without_tenant()
        local info = catalog:info()
        assert.is_true(info.require_tenant == false)
    end)
end)
