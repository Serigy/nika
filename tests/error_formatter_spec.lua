local error_formatter = require("error_formatter")

describe("Error formatter (Phase 13)", function()
    it("negocia formato por header Accept", function()
        assert.are.equal("json", error_formatter.negotiate("application/json"))
        assert.are.equal("xml", error_formatter.negotiate("application/xml"))
        assert.are.equal("html", error_formatter.negotiate("text/html"))
    end)

    it("suporta wildcards explicitos no Accept", function()
        assert.are.equal("json", error_formatter.negotiate("application/*"))
        assert.are.equal("html", error_formatter.negotiate("text/*"))
        assert.are.equal("xml", error_formatter.negotiate("*/*", "xml"))
    end)

    it("renderiza payload em json xml e html", function()
        local payload = {
            status = 500,
            error = "internal_error",
            message = "Internal Error"
        }

        local json_body, json_ct = error_formatter.render(payload, "json")
        assert.are.equal("application/json; charset=utf-8", json_ct)
        assert.is_not_nil(json_body:find("internal_error", 1, true))

        local xml_body, xml_ct = error_formatter.render(payload, "xml")
        assert.are.equal("application/xml; charset=utf-8", xml_ct)
        assert.is_not_nil(xml_body:find("<error>", 1, true))

        local html_body, html_ct = error_formatter.render(payload, "html")
        assert.are.equal("text/html; charset=utf-8", html_ct)
        assert.is_not_nil(html_body:find("<html>", 1, true))
    end)
end)
