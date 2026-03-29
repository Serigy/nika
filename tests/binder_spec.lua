local binder = require("binder")

describe("Binder (Phase 14)", function()
    it("faz bind e coercao a partir de body_table", function()
        local data, errors = binder.bind({
            body_table = {
                name = "Alice",
                age = "30",
                active = "true"
            },
            form_data = {}
        }, {
            name = "string|required|min:3",
            age = "integer|required|min:18",
            active = "boolean|required"
        })

        assert.is_not_nil(data)
        assert.is_nil(errors)
        assert.are.equal("Alice", data.name)
        assert.are.equal(30, data.age)
        assert.is_true(data.active == true)
    end)

    it("usa form_data quando body_table estiver vazio", function()
        local data, errors = binder.bind({
            body_table = {},
            form_data = {
                page = "2",
                per_page = "10"
            }
        }, {
            page = "integer|required|min:1",
            per_page = "integer|required|min:1"
        })

        assert.is_not_nil(data)
        assert.is_nil(errors)
        assert.are.equal(2, data.page)
        assert.are.equal(10, data.per_page)
    end)

    it("retorna erro estruturado em coercao invalida", function()
        local data, errors = binder.bind({
            body_table = {
                age = "nao-numerico"
            }
        }, {
            age = "integer|required|min:18"
        })

        assert.is_nil(data)
        assert.is_true(type(errors) == "table")
        assert.are.equal("invalid_type", errors[1].code)
    end)
end)
