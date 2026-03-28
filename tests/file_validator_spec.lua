local file_validator = require("file_validator")

describe("File validator (Phase 12)", function()
    it("aceita arquivo valido", function()
        local ok, err = file_validator.validate_file({
            filename = "invoice.pdf",
            content_type = "application/pdf",
            size = 1024
        })

        assert.is_true(ok == true)
        assert.is_nil(err)
    end)

    it("rejeita payload acima do limite", function()
        local ok, err = file_validator.validate_payload({
            {
                filename = "a.pdf",
                content_type = "application/pdf",
                size = 150 * 1024 * 1024
            },
            {
                filename = "b.pdf",
                content_type = "application/pdf",
                size = 100 * 1024 * 1024
            }
        })

        assert.is_nil(ok)
        assert.are.equal("file_too_large", err)
    end)

    it("rejeita nome com traversal", function()
        local ok, err = file_validator.validate_file({
            filename = "../../secrets.txt",
            content_type = "text/plain",
            size = 10
        })

        assert.is_nil(ok)
        assert.are.equal("path_traversal", err)
    end)
end)
