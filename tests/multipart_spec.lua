local multipart = require("multipart")

describe("Multipart parser (Phase 12)", function()
    it("parseia campos e arquivo", function()
        local boundary = "----NIKA"
        local body = table.concat({
            "------NIKA\r\n",
            "Content-Disposition: form-data; name=\"title\"\r\n\r\n",
            "Documento\r\n",
            "------NIKA\r\n",
            "Content-Disposition: form-data; name=\"file\"; filename=\"a.txt\"\r\n",
            "Content-Type: text/plain\r\n\r\n",
            "hello world\r\n",
            "------NIKA--\r\n"
        })

        local parsed, err = multipart.parse(body, "multipart/form-data; boundary=" .. boundary)
        assert.is_not_nil(parsed)
        assert.is_nil(err)
        assert.are.equal("Documento", parsed.form_data.title)
        assert.are.equal(1, #parsed.files)
        assert.are.equal("a.txt", parsed.files[1].filename)
    end)

    it("retorna erro sem boundary", function()
        local parsed, err = multipart.parse("abc", "multipart/form-data")
        assert.is_nil(parsed)
        assert.are.equal("boundary_missing", err)
    end)
end)
