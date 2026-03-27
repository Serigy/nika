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

    return sandbox.render_template(compiled, { query = query or {} }, { headers = {} }, {
        escape = escape_html,
        template_mode = opts.template_mode,
        template_partials = opts.template_partials,
        template_functions = opts.template_functions,
        api = opts.api
    })
end

describe("Template equivalence suite (Fase 9.1)", function()
    it("equivalencia html_text em modo html", function()
        local rendered, render_err = compile_and_render("<p><%= Request.query.value %></p>", {
            value = "<b>x</b>"
        }, {
            template_mode = "html"
        })

        assert.is_nil(render_err)
        assert.are.equal("<p>&lt;b&gt;x&lt;/b&gt;</p>", rendered)
    end)

    it("equivalencia html_attr_quoted em modo html", function()
        local rendered, render_err = compile_and_render('<input value="<%= Request.query.value %>">', {
            value = '"test"'
        }, {
            template_mode = "html"
        })

        assert.is_nil(render_err)
        assert.are.equal('<input value="&quot;test&quot;">', rendered)
    end)

    it("equivalencia url_attr segura em modo html", function()
        local rendered, render_err = compile_and_render('<a href="<%= Request.query.value %>">x</a>', {
            value = "https://example.com/a?b=1&c=2"
        }, {
            template_mode = "html"
        })

        assert.is_nil(render_err)
        assert.are.equal('<a href="https://example.com/a?b=1&amp;c=2">x</a>', rendered)
    end)

    it("equivalencia text_template sem escape em modo text", function()
        local rendered, render_err = compile_and_render("<p><%= Request.query.value %></p>", {
            value = "<b>x</b>"
        }, {
            template_mode = "text"
        })

        assert.is_nil(render_err)
        assert.are.equal("<p><b>x</b></p>", rendered)
    end)

    it("equivalencia partial include em modo html", function()
        local rendered, render_err = compile_and_render("<% include('row', { label = Request.query.label }) %>", {
            label = "<i>Nika</i>"
        }, {
            template_mode = "html",
            template_partials = {
                row = "<li><%= Request.query.label %></li>"
            }
        })

        assert.is_nil(render_err)
        assert.are.equal("<li>&lt;i&gt;Nika&lt;/i&gt;</li>", rendered)
    end)

    it("equivalencia function_registry aplica transformacao", function()
        local rendered, render_err = compile_and_render("<p><%= upper(Request.query.value) %></p>", {
            value = "nika"
        }, {
            template_mode = "html",
            template_functions = {
                upper = function(v)
                    return tostring(v):upper()
                end
            }
        })

        assert.is_nil(render_err)
        assert.are.equal("<p>NIKA</p>", rendered)
    end)

    it("diferenca conhecida: js_string bloqueado em modo html", function()
        local rendered, render_err = compile_and_render('<script>var x="<%= Request.query.value %>"</script>', {
            value = '";alert(1);//'
        }, {
            template_mode = "html"
        })

        -- Go html/template tende a escapar contexto JS; Nika atualmente bloqueia por hardening.
        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("diferenca conhecida: css_string bloqueado em modo html", function()
        local rendered, render_err = compile_and_render(
        "<style>.x{background:url('<%= Request.query.value %>')}</style>", {
            value = "javascript:alert(1)"
        }, {
            template_mode = "html"
        })

        -- Go html/template tende a escapar contexto CSS; Nika atualmente bloqueia por hardening.
        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("diferenca conhecida: url perigosa bloqueada em modo html", function()
        local rendered, render_err = compile_and_render('<a href="<%= Request.query.value %>">x</a>', {
            value = "javascript:alert(1)"
        }, {
            template_mode = "html"
        })

        -- Difere de abordagens que sanitizam para placeholder; Nika escolhe bloqueio com erro seguro.
        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)
end)
