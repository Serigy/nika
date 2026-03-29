local validator = require("validator")

describe("Validator (Phase 14)", function()
    it("valida schema simples com campos obrigatorios", function()
        local schema, schema_err = validator.schema({
            name = "string|required|min:3|max:20",
            age = "integer|required|min:18|max:99",
            email = "string|required|email"
        })

        assert.is_not_nil(schema)
        assert.is_nil(schema_err)

        local ok, errors = validator.validate({
            name = "Alice",
            age = 30,
            email = "alice@example.com"
        }, schema)

        assert.is_true(ok == true)
        assert.is_nil(errors)
    end)

    it("retorna erros estruturados quando payload invalido", function()
        local ok, errors = validator.validate({
            name = "Al",
            age = 15,
            email = "invalido"
        }, {
            name = "string|required|min:3",
            age = "integer|required|min:18",
            email = "string|required|email"
        })

        assert.is_nil(ok)
        assert.is_true(type(errors) == "table")
        assert.is_true(#errors >= 3)
    end)

    it("rejeita payload acima do limite configurado", function()
        local big = string.rep("a", 64)
        local ok, errors = validator.validate({
            value = big
        }, {
            value = "string|required"
        }, {
            max_payload_bytes = 16
        })

        assert.is_nil(ok)
        assert.is_true(type(errors) == "table")
        assert.are.equal("payload_too_large", errors[1].code)
    end)
end)
