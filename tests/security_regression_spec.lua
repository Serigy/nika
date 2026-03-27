local parser = require("parser")
local sandbox = require("sandbox")
local router = require("router")
local db = require("db")

local function escape_html(value)
    local str = tostring(value or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")
    return str
end

local function compile_and_render(template, query)
    local compiled, compile_err = parser.compile(template)
    assert(compiled ~= nil, "parser nao compilou: " .. tostring(compile_err))

    local rendered, render_err = sandbox.render_template(compiled, { query = query or {} }, { headers = {} }, {
        escape = escape_html
    })

    return rendered, render_err
end

describe("Security regression suite", function()
    it("envelopa expressoes com escape no parser", function()
        local compiled, compile_err = parser.compile("<p><%= Request.query.nome %></p>")
        assert(compiled ~= nil, "parser nao compilou: " .. tostring(compile_err))

        local compiled_str = compiled or ""
        assert.is_not_nil(compiled_str:find('__nika_emit%("HTML_TEXT", Request%.query%.nome%)'))
    end)

    it("bloqueia acesso a os no sandbox", function()
        local rendered, render_err = sandbox.render_template("return os.execute('id')", { query = {} }, { headers = {} },
            {
                escape = function(v)
                    return tostring(v)
                end
            })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("bloqueia path traversal no router", function()
        local path, route_err = router.resolve("/%2e%2e/%2e%2e/etc/passwd", { templates_root = "views" })
        assert.is_nil(path)
        assert.are.equal("invalid_path", route_err)
    end)

    it("bloqueia SQL inseguro e permite SQL parametrizado", function()
        local fake_driver = {
            execute = function(sql)
                return { ok = true, sql = sql }
            end
        }

        local ok_set = db.set_driver(fake_driver)
        assert.is_true(ok_set)

        local result, db_err = db.execute("SELECT * FROM users WHERE id = " .. "1", {})
        assert.is_nil(result)
        assert.are.equal("invalid_query", db_err)

        local safe_result, safe_err = db.execute("SELECT * FROM users WHERE id = ?", { 1 })
        assert.is_not_nil(safe_result)
        assert.is_nil(safe_err)
    end)
end)

describe("Template context matrix contract", function()
    it("HTML_TEXT escapa payload de script", function()
        local payload = "<script>alert(1)</script>"
        local rendered, render_err = compile_and_render("<p><%= Request.query.value %></p>", { value = payload })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)

        assert.is_not_nil(rendered:find("&lt;script&gt;alert%(1%)&lt;/script&gt;"))
        assert.is_nil(rendered:find("<script>", 1, true))
    end)

    it("HTML_ATTR_QUOTED nao quebra atributo com payload malicioso", function()
        local payload = '\"><img src=x onerror=alert(1)>'
        local rendered, render_err = compile_and_render('<input value="<%= Request.query.value %>">', { value = payload })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)

        assert.is_not_nil(rendered:find('<input value="', 1, true))
        assert.is_nil(rendered:find("<img", 1, true))
    end)

    it("URL_ATTR bloqueia esquema javascript no runtime", function()
        local rendered, render_err = compile_and_render('<a href="<%= Request.query.value %>">link</a>', {
            value = "javascript:alert(1)"
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("JS_STRING fica bloqueado para input nao confiavel no runtime", function()
        local rendered, render_err = compile_and_render('<script>var x="<%= Request.query.value %>"</script>', {
            value = '";alert(1);//'
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("CSS_STRING fica bloqueado para input nao confiavel no runtime", function()
        local rendered, render_err = compile_and_render("<style>.x{background:url('<%= Request.query.value %>')}</style>", {
            value = "');background-image:url(javascript:alert(1));/*"
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("RAW_TEXT_TEMPLATE fica bloqueado para input nao confiavel no runtime", function()
        local rendered, render_err = compile_and_render("<% write(Request.query.value) %>", {
            value = "<img src=x onerror=alert(1)>"
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)
end)

describe("Context-aware escaping (Fase 7.1)", function()
    it("HTML_TEXT usa escape generico com caracteres especiais", function()
        local payload = '<a href="#">&nbsp;</a>'
        local rendered, render_err = compile_and_render("<p><%= Request.query.value %></p>", { value = payload })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)

        assert.is_not_nil(rendered:find("&lt;a href=", 1, true))
        assert.is_not_nil(rendered:find("&amp;nbsp;", 1, true))
        assert.is_not_nil(rendered:find("&lt;/a&gt;", 1, true))
    end)

    it("HTML_ATTR_QUOTED escapa aspas como atributo", function()
        local payload = '"><img src=x onerror=alert(1)>'
        local rendered, render_err = compile_and_render('<input value="<%= Request.query.value %>">', { value = payload })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)

        assert.is_not_nil(rendered:find('<input value="', 1, true))
        assert.is_not_nil(rendered:find("&quot;&gt;", 1, true))
        assert.is_nil(rendered:find('<img', 1, true))
    end)

    it("URL_ATTR sanitiza e permite http/https/ftp/mailto", function()
        local cases = {
            { input = "http://example.com", should_pass = true },
            { input = "https://example.com", should_pass = true },
            { input = "/relative/path", should_pass = true },
            { input = "mailto:user@example.com", should_pass = true }
        }

        for _, case in ipairs(cases) do
            local rendered, render_err = compile_and_render('<a href="<%= Request.query.value %>">link</a>', {
                value = case.input
            })

            if case.should_pass then
                assert.is_nil(render_err, "URL " .. case.input .. " should pass")
                assert.is_not_nil(rendered)
                assert.is_not_nil(rendered:find("href=", 1, true))
            end
        end
    end)

    it("URL_ATTR bloqueia javascript: e data: schemes", function()
        local bad_cases = { "javascript:alert(1)", "data:text/html,<script>alert(1)</script>" }

        for _, payload in ipairs(bad_cases) do
            local rendered, render_err = compile_and_render('<a href="<%= Request.query.value %>">link</a>', {
                value = payload
            })

            assert.is_nil(rendered, "URL " .. payload .. " should be blocked")
            assert.are.equal("Erro interno", render_err)
        end
    end)
end)
