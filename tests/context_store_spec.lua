-- tests/context_store_spec.lua
-- Testes para context_store.lua (Phase 10)
-- Valida isolamento request-scoped, cleanup, e segurança

local context_store = require("context_store")

describe("Context Store (Phase 10)", function()
    it("cria novo contexto com UUID se não fornecido", function()
        context_store.cleanup_all_pending() -- limpa antes

        local ctx_id = context_store.create_context()
        assert(ctx_id ~= nil, "context_id deve ser gerado")
        assert(#ctx_id > 0, "context_id não pode ser vazio")

        context_store.cleanup_all_pending()
    end)

    it("reutiliza context_id se já existe", function()
        context_store.cleanup_all_pending()

        local ctx_id = "test-ctx-123"
        local id1 = context_store.create_context(ctx_id)
        local id2 = context_store.create_context(ctx_id)

        assert(id1 == id2, "deve retornar mesmo context_id")

        context_store.cleanup_all_pending()
    end)

    it("armazena e recupera valores", function()
        context_store.cleanup_all_pending()

        local ctx_id = context_store.create_context()

        local ok = context_store.set(ctx_id, "user_id", 123)
        assert(ok == true, "set deve retornar true")

        local value = context_store.get(ctx_id, "user_id")
        assert(value == 123, "get deve retornar valor armazenado")

        context_store.cleanup_all_pending()
    end)

    it("rejeita chaves reservadas", function()
        context_store.cleanup_all_pending()

        local ctx_id = context_store.create_context()

        local ok, err = context_store.set(ctx_id, "_request_id", "should-fail")
        assert(ok == false, "deve rejeitar _request_id")
        assert(err:find("reservada") ~= nil, "erro deve mencionar chave reservada")

        context_store.cleanup_all_pending()
    end)

    it("retorna nil para context inexistente", function()
        context_store.cleanup_all_pending()

        local value = context_store.get("nonexistent", "key")
        assert(value == nil, "deve retornar nil para context inexistente")

        context_store.cleanup_all_pending()
    end)

    it("retorna todo contexto via get_all", function()
        context_store.cleanup_all_pending()

        local ctx_id = context_store.create_context()
        context_store.set(ctx_id, "key1", "value1")
        context_store.set(ctx_id, "key2", "value2")

        local all = context_store.get_all(ctx_id)
        assert(all.key1 == "value1", "get_all deve retornar key1")
        assert(all.key2 == "value2", "get_all deve retornar key2")

        context_store.cleanup_all_pending()
    end)

    it("limpa contexto específico", function()
        context_store.cleanup_all_pending()

        local ctx_id = context_store.create_context()
        context_store.set(ctx_id, "key", "value")

        context_store.cleanup(ctx_id)

        local value = context_store.get(ctx_id, "key")
        assert(value == nil, "contexto deve estar vazio após cleanup")

        context_store.cleanup_all_pending()
    end)

    it("expõe read-only API para template", function()
        context_store.cleanup_all_pending()

        local ctx_id = context_store.create_context()
        context_store.set(ctx_id, "user_id", 123)
        context_store.set(ctx_id, "role", "admin")

        local readonly_api = context_store.make_readonly_api(ctx_id)

        assert(readonly_api.user_id == 123, "deve ler via índex")
        assert(readonly_api.role == "admin", "deve ler múltiplos valores")

        -- Tenta escrever (deve falhar)
        local ok, err = pcall(function()
            readonly_api.new_key = "value"
        end)
        assert(ok == false, "deve falhar ao tentar escrever")
        assert(tostring(err):find("read%-only") ~= nil, "erro deve mencionar read-only")

        context_store.cleanup_all_pending()
    end)

    it("limpa múltiplos contextos pendentes", function()
        context_store.cleanup_all_pending()

        local id1 = context_store.create_context()
        local id2 = context_store.create_context()
        local id3 = context_store.create_context()

        context_store.set(id1, "a", 1)
        context_store.set(id2, "b", 2)
        context_store.set(id3, "c", 3)

        context_store.cleanup_all_pending()

        assert(context_store.get(id1, "a") == nil, "id1 deve estar limpo")
        assert(context_store.get(id2, "b") == nil, "id2 deve estar limpo")
        assert(context_store.get(id3, "c") == nil, "id3 deve estar limpo")
    end)

    it("retorna stats do store", function()
        context_store.cleanup_all_pending()

        local _ = context_store.create_context()
        local _ = context_store.create_context()

        local stats = context_store.get_store_stats()
        assert(stats.active_contexts >= 2, "deve reportar contextos ativos")
        assert(stats.total_stored >= 2, "deve reportar total armazenado")

        context_store.cleanup_all_pending()
    end)
end)
