local file_manager = require("file_manager")
local file_storage = require("file_storage")

describe("File manager (Phase 12)", function()
    before_each(function()
        local registry = file_storage.new_registry(file_storage.new_local({ root_dir = "uploads_test" }))
        file_manager.set_registry(registry)
        file_manager.reset_request_index()
    end)

    it("processa e armazena arquivos validados", function()
        local files, err = file_manager.process_files({
            {
                field = "doc",
                filename = "invoice.pdf",
                content_type = "application/pdf",
                data = "abc",
                size = 3
            }
        })

        assert.is_not_nil(files)
        assert.is_nil(err)
        assert.are.equal(1, #files)
        assert.is_not_nil(files[1].id)
        assert.is_not_nil(files[1].path)
    end)

    it("bloqueia upload invalido", function()
        local files, err = file_manager.process_files({
            {
                field = "doc",
                filename = "../../bad.exe",
                content_type = "application/x-msdownload",
                data = "abc",
                size = 3
            }
        })

        assert.is_nil(files)
        assert.is_not_nil(err)
    end)

    it("faz cleanup por request_id", function()
        local deleted = {}
        local seq = 0

        local fake_registry = {
            put = function(_, file)
                seq = seq + 1
                local id = "f-" .. tostring(seq)
                return id, {
                    filename = file.filename,
                    content_type = file.content_type,
                    size = file.size
                }
            end,
            delete = function(_, id)
                deleted[#deleted + 1] = id
                return true
            end
        }

        file_manager.set_registry(fake_registry)

        local files, err = file_manager.process_files({
            {
                field = "doc",
                filename = "invoice.pdf",
                content_type = "application/pdf",
                data = "abc",
                size = 3
            },
            {
                field = "doc2",
                filename = "terms.pdf",
                content_type = "application/pdf",
                data = "xyz",
                size = 3
            }
        }, {
            request_id = "req-42"
        })

        assert.is_not_nil(files)
        assert.is_nil(err)
        assert.are.equal(0, #deleted)

        file_manager.cleanup_request("req-42")

        assert.are.equal(2, #deleted)
    end)
end)
