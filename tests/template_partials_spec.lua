local parser = require("parser")
local sandbox = require("sandbox")
local template_partials = require("template_partials")

local function escape_html(value)
    local s = tostring(value or "")
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub('"', "&quot;")
    s = s:gsub("'", "&#39;")
    return s
end

local function compile_and_render(template, query, opts)
    local compiled, compile_err = parser.compile(template)
    assert(compiled ~= nil, "parser nao compilou: " .. tostring(compile_err))

    opts = opts or {}

    local rendered, render_err = sandbox.render_template(compiled, { query = query or {} }, { headers = {} }, {
        escape = escape_html,
        api = opts.api,
        template_functions = opts.template_functions,
        template_partials = opts.template_partials,
        max_partial_depth = opts.max_partial_depth
    })

    return rendered, render_err
end

describe("Template partials (Fase 8.2)", function()
    it("include renderiza parcial reutilizavel", function()
        local rendered, render_err = compile_and_render("<% include('greeting', { name = Request.query.name }) %>", {
            name = "Alice"
        }, {
            template_partials = {
                greeting = "<p>Ola, <%= Request.query.name %></p>"
            }
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("<p>Ola, Alice</p>", 1, true))
    end)

    it("include preserva escape interno da parcial", function()
        local rendered, render_err = compile_and_render("<% include('safe', { name = Request.query.name }) %>", {
            name = "<script>alert(1)</script>"
        }, {
            template_partials = {
                safe = "<div><%= Request.query.name %></div>"
            }
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("&lt;script&gt;alert(1)&lt;/script&gt;", 1, true))
        assert.is_nil(rendered:find("<script>", 1, true))
    end)

    it("partial retorna string para uso em <%= %>", function()
        local rendered, render_err = compile_and_render("<p><%= partial('badge', { label = 'OK' }) %></p>", {}, {
            template_partials = {
                badge = "<strong><%= Request.query.label %></strong>"
            }
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("&lt;strong&gt;OK&lt;/strong&gt;", 1, true))
    end)

    it("bloqueia parcial inexistente", function()
        local rendered, render_err = compile_and_render("<% include('missing') %>", {}, {
            template_partials = {
                known = "<p>x</p>"
            }
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("bloqueia recursao acima do limite", function()
        local rendered, render_err = compile_and_render("<% include('loop') %>", {}, {
            template_partials = {
                loop = "<% include('loop') %>"
            },
            max_partial_depth = 2
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("suporta registry de parciais explicito", function()
        local registry = template_partials.new()
        local ok = template_partials.register(registry, "card", "<article><%= Request.query.title %></article>")
        assert.is_true(ok)

        local rendered, render_err = compile_and_render("<% include('card', { title = 'Nika' }) %>", {}, {
            template_partials = registry
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("<article>Nika</article>", 1, true))
    end)

    it("retorna erro quando template_partials e invalido", function()
        local rendered, render_err = compile_and_render("<% include('x') %>", {}, {
            template_partials = "invalido"
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)
end)
