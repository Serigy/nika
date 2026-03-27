local parser = require("parser")
local sandbox = require("sandbox")

describe("Deterministic context selection (Fase 7.2)", function()
    local function extract_contexts_from_compiled(compiled)
        local contexts = {}
        for context in compiled:gmatch('__nika_emit%("([^"]+)"') do
            table.insert(contexts, context)
        end
        return contexts
    end

    it("determinismo: mesma template sempre produz mesmos contextos", function()
        local template = '<p><%= x %></p><a href="<%= y %>">link</a>'
        local contexts_run1 = {}
        local contexts_run2 = {}

        for run = 1, 2 do
            local compiled = parser.compile(template)
            local contexts = extract_contexts_from_compiled(compiled)
            if run == 1 then
                contexts_run1 = contexts
            else
                contexts_run2 = contexts
            end
        end

        assert.are.equal(#contexts_run1, #contexts_run2)
        for i = 1, #contexts_run1 do
            assert.are.equal(contexts_run1[i], contexts_run2[i], "context at index " .. i .. " differs")
        end
    end)

    it("inferencia: multiplos outputs em mesma template", function()
        local template = '<p><%= a %></p><p><%= b %></p>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(2, #contexts)
        assert.are.equal("HTML_TEXT", contexts[1])
        assert.are.equal("HTML_TEXT", contexts[2])
    end)

    it("inferencia: HTML_TEXT antes de primeiro tag", function()
        local template = 'antes <%= value %> depois'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("HTML_TEXT", contexts[1])
    end)

    it("inferencia: HTML_ATTR em atributos genéricos", function()
        local template = '<div class="<%= class_val %>" title="<%= title_val %>"></div>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(2, #contexts)
        assert.are.equal("HTML_ATTR_QUOTED", contexts[1])
        assert.are.equal("HTML_ATTR_QUOTED", contexts[2])
    end)

    it("inferencia: URL_ATTR em href", function()
        local template = '<a href="<%= link %>">click</a>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("URL_ATTR", contexts[1])
    end)

    it("inferencia: URL_ATTR em src", function()
        local template = '<img src="<%= image_url %>">'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("URL_ATTR", contexts[1])
    end)

    it("inferencia: JS_STRING dentro de script tag", function()
        local template = '<script>var x = "<%= value %>";</script>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("JS_STRING", contexts[1])
    end)

    it("inferencia: CSS_STRING dentro de style tag", function()
        local template = "<style>body { color: '<%= color %>'; }</style>"
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("CSS_STRING", contexts[1])
    end)

    it("inferencia: multiplas scripts, contexto correto por posicao", function()
        local template = '<script>var a = "<%= x %>";</script> <p><%= y %></p> <script>var b = "<%= z %>";</script>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(3, #contexts)
        assert.are.equal("JS_STRING", contexts[1])
        assert.are.equal("HTML_TEXT", contexts[2])
        assert.are.equal("JS_STRING", contexts[3])
    end)

    it("inferencia: nested divs nao afetam contexto", function()
        local template = '<div><div><div><p><%= value %></p></div></div></div>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("HTML_TEXT", contexts[1])
    end)

    it("inferencia: atributo apos espacos e quebras de linha", function()
        local template = '<input\n  value="<%= val %>"\n  />'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("HTML_ATTR_QUOTED", contexts[1])
    end)

    it("inferencia: multiplos atributos URL na mesma tag", function()
        local template = '<a href="<%= link %>" data="<%= data_url %>">link</a>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(2, #contexts)
        assert.are.equal("URL_ATTR", contexts[1])
        assert.are.equal("URL_ATTR", contexts[2])
    end)

    it("inferencia: HTML_TEXT apos fechamento de script", function()
        local template = '<script>code</script><p><%= value %></p>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("HTML_TEXT", contexts[1])
    end)

    it("inferencia: script tag case-insensitive", function()
        local template = '<SCRIPT>var x = "<%= value %>";</SCRIPT>'
        local compiled = parser.compile(template)
        local contexts = extract_contexts_from_compiled(compiled)

        assert.are.equal(1, #contexts)
        assert.are.equal("JS_STRING", contexts[1])
    end)

    it("auditability: compilacao sem erros de sintaxe", function()
        local templates = {
            '<p><%= a %></p>',
            '<a href="<%= b %>">',
            '<script><%= c %></script>',
            '<div class="<%= d %>"></div>'
        }

        for _, template in ipairs(templates) do
            local compiled, metadata = parser.compile(template)
            assert.is_not_nil(compiled, "erro compilando: " .. template)
            assert.is_not_nil(metadata)
            assert.is_not_nil(metadata.contexts)
        end
    end)
end)
