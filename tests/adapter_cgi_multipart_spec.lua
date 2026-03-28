local adapter_cgi = require("adapter_cgi")

describe("Adapter CGI multipart integration (Phase 12)", function()
    it("preenche form_data e files ao receber multipart", function()
        local env = {
            REQUEST_METHOD = "POST",
            PATH_INFO = "/upload",
            CONTENT_TYPE = "multipart/form-data; boundary=----NIKA",
            CONTENT_LENGTH = "221"
        }

        local body = table.concat({
            "------NIKA\r\n",
            "Content-Disposition: form-data; name=\"title\"\r\n\r\n",
            "Contrato\r\n",
            "------NIKA\r\n",
            "Content-Disposition: form-data; name=\"file\"; filename=\"doc.txt\"\r\n",
            "Content-Type: text/plain\r\n\r\n",
            "conteudo\r\n",
            "------NIKA--\r\n"
        })

        local req = adapter_cgi.request_from_cgi(env, function()
            return body
        end)

        assert.are.equal("Contrato", req.form_data.title)
        assert.are.equal(1, #req.files)
        assert.is_not_nil(req.files[1].id)
        assert.is_not_nil(req.context_id)
    end)

    it("preenche upload_error quando arquivo e bloqueado", function()
        local env = {
            REQUEST_METHOD = "POST",
            PATH_INFO = "/upload",
            CONTENT_TYPE = "multipart/form-data; boundary=----NIKA",
            CONTENT_LENGTH = "230"
        }

        local body = table.concat({
            "------NIKA\r\n",
            "Content-Disposition: form-data; name=\"title\"\r\n\r\n",
            "Contrato\r\n",
            "------NIKA\r\n",
            "Content-Disposition: form-data; name=\"file\"; filename=\"../../bad.exe\"\r\n",
            "Content-Type: application/x-msdownload\r\n\r\n",
            "payload\r\n",
            "------NIKA--\r\n"
        })

        local req = adapter_cgi.request_from_cgi(env, function()
            return body
        end)

        assert.is_not_nil(req.upload_error)
        assert.are.equal(0, #req.files)
    end)
end)
