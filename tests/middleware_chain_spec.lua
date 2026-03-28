-- tests/middleware_chain_spec.lua
-- Testes para middleware_chain.lua (Phase 10)
-- Valida sequenciamento, prioridade, short-circuit

local middleware_chain = require("middleware_chain")

describe("Middleware Chain (Phase 10)", function()
    before_each(function()
        middleware_chain.clear()
    end)

    it("registra middleware em stage válido", function()
        local mid = function(req, res, ctx) return false end
        local name = middleware_chain.use("before_request", mid)

        assert(name ~= nil, "deve retornar nome do middleware")
    end)

    it("rejeita stage inválido", function()
        local mid = function() end
        local ok, err = pcall(function()
            middleware_chain.use("invalid_stage", mid)
        end)

        assert(ok == false, "deve lançar erro para stage inválido")
    end)

    it("rejeita middleware não-function", function()
        local ok, err = pcall(function()
            middleware_chain.use("before_request", "not_a_function")
        end)

        assert(ok == false, "deve lançar erro para middleware não-function")
    end)

    it("executa middlewares em ordem de prioridade", function()
        local execution_order = {}

        local mid1 = function(req, res, ctx)
            table.insert(execution_order, "mid1")
            return false
        end

        local mid2 = function(req, res, ctx)
            table.insert(execution_order, "mid2")
            return false
        end

        local mid3 = function(req, res, ctx)
            table.insert(execution_order, "mid3")
            return false
        end

        middleware_chain.use("before_request", mid1, "m1", 30) -- priority 30
        middleware_chain.use("before_request", mid2, "m2", 50) -- priority 50 (higher = first)
        middleware_chain.use("before_request", mid3, "m3", 40) -- priority 40

        middleware_chain.run("before_request", {}, {}, {})

        assert(execution_order[1] == "mid2", "mid2 (priority 50) deve executar primeiro")
        assert(execution_order[2] == "mid3", "mid3 (priority 40) deve executar segundo")
        assert(execution_order[3] == "mid1", "mid1 (priority 30) deve executar por último")
    end)

    it("interrompe execução ao short-circuit em before_request", function()
        local execution_order = {}

        middleware_chain.use("before_request", function(req, res, ctx)
            table.insert(execution_order, "mid1")
            return true    -- short-circuit
        end, "a_mid1", 60) -- explicit name + high priority

        middleware_chain.use("before_request", function(req, res, ctx)
            table.insert(execution_order, "mid2")
            return false
        end, "z_mid2", 50) -- explicit name + lower priority

        local is_short, err, ctx = middleware_chain.run("before_request", {}, {}, {})

        assert(is_short == true, "deve retornar short-circuit flag")
        assert(execution_order[1] == "mid1", "deve executar mid1")
        assert(execution_order[2] == nil, "deve parar em mid1")
    end)

    it("não short-circuit em after_request", function()
        local execution_order = {}

        middleware_chain.use("after_request", function(req, res, ctx)
            table.insert(execution_order, "mid1")
            return true -- retorna true mas não short-circuit
        end)

        middleware_chain.use("after_request", function(req, res, ctx)
            table.insert(execution_order, "mid2")
            return false
        end)

        middleware_chain.run("after_request", {}, {}, {})

        assert(#execution_order == 2, "deve executar ambos em after_request")
    end)

    it("permite middleware modificar context", function()
        middleware_chain.use("before_request", function(req, res, ctx)
            ctx.modified = true
            ctx.value = 123
            return false
        end)

        local _, err, ctx = middleware_chain.run("before_request", {}, {}, {})

        assert(ctx.modified == true, "deve modificar context")
        assert(ctx.value == 123, "deve armazenar valor")
    end)

    it("conta middlewares registrados", function()
        middleware_chain.use("before_request", function() end)
        middleware_chain.use("before_request", function() end)
        middleware_chain.use("before_render", function() end)

        local count_before = middleware_chain.count("before_request")
        local count_render = middleware_chain.count("before_render")
        local count_total = middleware_chain.count()

        assert(count_before == 2, "deve contar 2 em before_request")
        assert(count_render == 1, "deve contar 1 em before_render")
        assert(count_total == 3, "deve contar 3 total")
    end)

    it("remove middleware específico via unuse", function()
        local name = middleware_chain.use("before_request", function() end, "test_mid")

        middleware_chain.unuse("before_request", name)

        local count = middleware_chain.count("before_request")
        assert(count == 0, "deve remover middleware")
    end)

    it("retorna lista de middlewares por stage", function()
        middleware_chain.use("before_request", function() end, "mid1", 50)
        middleware_chain.use("before_request", function() end, "mid2", 30)

        local list = middleware_chain.get_middleware_list("before_request")

        assert(#list == 2, "deve retornar 2 middlewares")
        assert(list[1].name == "mid1", "mid1 deve estar primeiro (priority 50)")
        assert(list[2].name == "mid2", "mid2 deve estar segundo (priority 30)")
    end)

    it("limpa middlewares específicos", function()
        middleware_chain.use("before_request", function() end)
        middleware_chain.use("before_render", function() end)

        middleware_chain.clear("before_request")

        local count_before = middleware_chain.count("before_request")
        local count_render = middleware_chain.count("before_render")

        assert(count_before == 0, "deve limpar before_request")
        assert(count_render == 1, "deve manter before_render")
    end)

    it("limpa todos os middlewares", function()
        middleware_chain.use("before_request", function() end)
        middleware_chain.use("before_render", function() end)
        middleware_chain.use("after_request", function() end)

        middleware_chain.clear()

        local total = middleware_chain.count()
        assert(total == 0, "deve limpar tudo")
    end)

    it("gera nome único se não fornecido", function()
        local name1 = middleware_chain.use("before_request", function() end)
        local name2 = middleware_chain.use("before_request", function() end)

        assert(name1 ~= name2, "nomes devem ser únicos")
    end)

    it("stages válidos: before_request, before_render, after_request", function()
        local ok1 = pcall(function()
            middleware_chain.use("before_request", function() end)
        end)

        local ok2 = pcall(function()
            middleware_chain.use("before_render", function() end)
        end)

        local ok3 = pcall(function()
            middleware_chain.use("after_request", function() end)
        end)

        assert(ok1 == true, "before_request é válido")
        assert(ok2 == true, "before_render é válido")
        assert(ok3 == true, "after_request é válido")
    end)
end)
