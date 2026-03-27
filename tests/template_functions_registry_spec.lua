local parser = require("parser")
local sandbox = require("sandbox")
local template_functions = require("template_functions")

local function compile_and_render(template, query, opts)
    local compiled, compile_err = parser.compile(template)
    assert(compiled ~= nil, "parser nao compilou: " .. tostring(compile_err))

    opts = opts or {}

    local rendered, render_err = sandbox.render_template(compiled, { query = query or {} }, { headers = {} }, {
        escape = function(v)
            local s = tostring(v or "")
            s = s:gsub("&", "&amp;")
            s = s:gsub("<", "&lt;")
            s = s:gsub(">", "&gt;")
            s = s:gsub('"', "&quot;")
            s = s:gsub("'", "&#39;")
            return s
        end,
        api = opts.api,
        template_functions = opts.template_functions
    })

    return rendered, render_err
end

describe("Template functions registry (Fase 8.1)", function()
    it("permite funcao registrada via tabela allow-list", function()
        local rendered, render_err = compile_and_render("<p><%= upper(Request.query.name) %></p>", { name = "alice" }, {
            template_functions = {
                upper = function(v)
                    return tostring(v):upper()
                end
            }
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("ALICE", 1, true))
    end)

    it("permite funcao registrada via objeto registry", function()
        local registry = template_functions.new()
        local ok = template_functions.register(registry, "trim", function(v)
            local s = tostring(v or "")
            return (s:gsub("^%s+", ""):gsub("%s+$", ""))
        end)
        assert.is_true(ok)

        local rendered, render_err = compile_and_render("<p><%= trim(Request.query.value) %></p>", { value = "  nika  " }, {
            template_functions = registry
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find(">nika<", 1, true))
    end)

    it("bloqueia chamada de funcao nao registrada", function()
        local rendered, render_err = compile_and_render("<p><%= upper(Request.query.name) %></p>", { name = "alice" }, {
            template_functions = {}
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("mantem compatibilidade de funcoes via template_api legado", function()
        local rendered, render_err = compile_and_render("<p><%= lower(Request.query.name) %></p>", { name = "ALICE" }, {
            api = {
                lower = function(v)
                    return tostring(v):lower()
                end
            }
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("alice", 1, true))
    end)

    it("mantem compatibilidade de valores nao-funcao via template_api legado", function()
        local rendered, render_err = compile_and_render("<h1><%= site_name %></h1>", {}, {
            api = {
                site_name = "Nika"
            }
        })

        assert.is_nil(render_err)
        assert.is_not_nil(rendered)
        assert.is_not_nil(rendered:find("Nika", 1, true))
    end)

    it("bloqueia funcao proibida no registry", function()
        local rendered, render_err = compile_and_render("<p><%= os() %></p>", {}, {
            template_functions = {
                os = function()
                    return "blocked"
                end
            }
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)

    it("retorna erro para formato invalido de template_functions", function()
        local rendered, render_err = compile_and_render("<p><%= Request.query.name %></p>", { name = "alice" }, {
            template_functions = "invalido"
        })

        assert.is_nil(rendered)
        assert.are.equal("Erro interno", render_err)
    end)
end)
