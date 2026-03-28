local audit = require("nika_audit")
local dataware_audit = require("dataware_audit")

describe("Dataware audit (Phase 11)", function()
    it("registra evento de tenant violation", function()
        local log_path = "tests/nika_audit_dataware_" .. tostring(os.time()) .. ".log"
        audit.set_log_path(log_path)

        dataware_audit.log_tenant_violation("User", "select")

        local fh = io.open(log_path, "r")
        assert.is_not_nil(fh)
        local content = fh:read("*a")
        fh:close()

        assert.is_not_nil(content:find('"dataware_tenant_violation"', 1, true))
        assert.is_not_nil(content:find('"model":"User"', 1, true))
        assert.is_not_nil(content:find('"operation":"select"', 1, true))

        os.remove(log_path)
    end)
end)
