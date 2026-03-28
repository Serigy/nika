local file_storage = require("file_storage")

describe("File storage local provider (Phase 12)", function()
    it("grava e recupera metadata", function()
        local provider = file_storage.new_local({ root_dir = "uploads_test" })

        local id, meta = provider:put({
            filename = "notes.txt",
            content_type = "text/plain",
            data = "hello"
        })

        assert.is_not_nil(id)
        assert.is_not_nil(meta)

        local fetched = provider:get(id)
        assert.is_not_nil(fetched)
        assert.are.equal("notes.txt", fetched.filename)

        provider:delete(id)
    end)

    it("registry alterna provider ativo", function()
        local provider = file_storage.new_local({ root_dir = "uploads_test" })
        local registry = file_storage.new_registry(provider)

        local id = registry:put({ filename = "a.txt", content_type = "text/plain", data = "x" })
        assert.is_not_nil(id)

        local meta = registry:get(id)
        assert.is_not_nil(meta)

        registry:delete(id)
    end)
end)
