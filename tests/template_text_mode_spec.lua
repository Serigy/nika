local parser = require("parser")
local sandbox = require("sandbox")

local function escape_html(value)
    local str = tostring(value or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")
    return str
end

local function compile_and_render(template, query, opts)
    local compiled, compile_err = parser.compile(template)
    assert(compiled ~= nil, "parser nao compilou: " .. tostring(compile_err))

    opts = opts or {}

    local rendered, render_err = sandbox.render_template(compiled, { query = query or {} }, { headers = {} }, {
        escape = escape_html,
        template_mode = opts.template_mode,
        template_partials = opts.template_partials
    })

    return rendered, render_err
end

describe("Template text mode (Fase 8.3)", function()
    it("modo html continua escapando por padrao", function()
        local payload = "<script>alert(1)</script>"
        local rendered, render_err = compile_and_render("<p><%= Request.query.value %></p>", { value = payload })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("&lt;script&gt;alert%(1%)&lt;/script&gt;"))
        assert.is_nil(rendered:find("<script>", 1, true))
    end)

    it("modo text nao faz auto-escape em HTML_TEXT", function()
        local payload = "<script>alert(1)</script>"
        local rendered, render_err = compile_and_render("<p><%= Request.query.value %></p>", {
            value = payload
        }, {
            template_mode = "text"
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("<script>alert%(1%)</script>"))
    end)

    it("modo text permite URL_ATTR sem bloqueio de esquema", function()
        local rendered, render_err = compile_and_render('<a href="<%= Request.query.value %>">x</a>', {
            value = "javascript:alert(1)"
        }, {
            template_mode = "text"
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("javascript:alert%(1%)"))
    end)

    it("modo text permite JS_STRING e CSS_STRING sem bloqueio", function()
        local js_rendered, js_err = compile_and_render('<script>var x="<%= Request.query.value %>"</script>', {
            value = '";alert(1);//'
        }, {
            template_mode = "text"
        })

        assert.is_nil(js_err)
        assert.is_not_nil(js_rendered)
        assert.is_not_nil(js_rendered:find('";alert%(1%);//'))

        local css_rendered, css_err = compile_and_render("<style>.x{background:url('<%= Request.query.value %>')}</style>", {
            value = "javascript:alert(1)"
        }, {
            template_mode = "text"
        })

        assert.is_nil(css_err)
        assert.is_not_nil(css_rendered)
        assert.is_not_nil(css_rendered:find("javascript:alert%(1%)"))
    end)

    it("modo text tambem se aplica a parciais", function()
        local rendered, render_err = compile_and_render("<% include('txt', { value = Request.query.value }) %>", {
            value = "<b>raw</b>"
        }, {
            template_mode = "text",
            template_partials = {
                txt = "<%= Request.query.value %>"
            }
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("<b>raw</b>", 1, true))
    end)

    it("modo invalido retorna erro interno", function()
        local rendered, render_err = compile_and_render("<p><%= Request.query.value %></p>", {
            value = "x"
        }, {
            template_mode = "binary"
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("modo html continua bloqueando contextos restritos", function()
        local rendered, render_err = compile_and_render('<script>var x="<%= Request.query.value %>"</script>', {
            value = '";alert(1);//'
        }, {
            template_mode = "html"
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)
end)
