-- tests/router_v2_spec.lua
-- Testes para router_v2.lua (Phase 10)
-- Valida routing com parâmetros, regex, método HTTP

local router_v2 = require("router_v2")

describe("Router V2 (Phase 10)", function()
    local function dummy_handler(req, res)
        return { status = 200, body = "OK" }
    end

    before_each(function()
        router_v2.clear()
    end)

    it("registra rota simples GET", function()
        local name = router_v2.get("/users", dummy_handler)
        assert(name ~= nil, "deve retornar nome da rota")
    end)

    it("encontra rota exata", function()
        router_v2.get("/users", dummy_handler)

        local handler, err, params = router_v2.match("GET", "/users")
        assert(handler ~= nil, "deve encontrar rota")
        assert(err == nil, "não deve ter erro")
        assert(params ~= nil, "deve retornar params (table vazia)")
    end)

    it("extrai parâmetro :id", function()
        router_v2.get("/users/:id", dummy_handler)

        local handler, err, params = router_v2.match("GET", "/users/123")
        assert(handler ~= nil, "deve encontrar rota com :id")
        assert(params.id == "123", "deve extrair id como '123'")
    end)

    it("extrai múltiplos parâmetros", function()
        router_v2.get("/posts/:id/comments/:cid", dummy_handler)

        local handler, err, params = router_v2.match("GET", "/posts/5/comments/7")
        assert(handler ~= nil, "deve encontrar rota")
        assert(params.id == "5", "deve extrair id como '5'")
        assert(params.cid == "7", "deve extrair cid como '7'")
    end)

    it("diferencia métodos HTTP", function()
        router_v2.get("/users", dummy_handler, "get_users")
        router_v2.post("/users", dummy_handler, "post_users")

        local h_get = router_v2.match("GET", "/users")
        local h_post = router_v2.match("POST", "/users")

        assert(h_get ~= nil, "GET /users deve encontrar")
        assert(h_post ~= nil, "POST /users deve encontrar")
    end)

    it("retorna 404 para rota não encontrada", function()
        router_v2.get("/users", dummy_handler)

        local handler, err = router_v2.match("GET", "/posts")
        assert(handler == nil, "não deve encontrar rota /posts")
        assert(err ~= nil, "deve retornar mensagem de erro")
        local has_text = string.find(err or "", "not found") or string.find(err or "", "não encontrada")
        assert(has_text ~= nil, "erro deve mencionar não encontrada")
    end)

    it("suporta todos os métodos HTTP", function()
        local methods = { "GET", "POST", "PUT", "DELETE", "PATCH", "HEAD" }

        for _, method in ipairs(methods) do
            router_v2.register(method, "/resource", dummy_handler)
            local handler = router_v2.match(method, "/resource")
            assert(handler ~= nil, "deve suportar " .. method)
        end
    end)

    it("normaliza path sem leading slash", function()
        router_v2.get("/users", dummy_handler)

        local handler1 = router_v2.match("GET", "/users")
        local handler2 = router_v2.match("GET", "users") -- sem /

        assert(handler1 ~= nil, "deve encontrar com /")
        assert(handler2 ~= nil, "deve encontrar sem /")
    end)

    it("normaliza path raiz vazio", function()
        router_v2.get("/", dummy_handler)

        local h1 = router_v2.match("GET", "/")
        local h2 = router_v2.match("GET", "")

        assert(h1 ~= nil, "deve encontrar com /")
        assert(h2 ~= nil, "deve encontrar com '' (vazio)")
    end)

    it("retorna contagem de rotas", function()
        router_v2.get("/users", dummy_handler)
        router_v2.post("/users", dummy_handler)
        router_v2.get("/posts", dummy_handler)

        local count = router_v2.count()
        assert(count == 3, "deve contar 3 rotas")
    end)

    it("limpa todas as rotas", function()
        router_v2.get("/users", dummy_handler)
        router_v2.post("/posts", dummy_handler)

        router_v2.clear()

        local count = router_v2.count()
        assert(count == 0, "deve estar vazio após clear")
    end)

    it("debug_routes retorna estrutura com todas as rotas", function()
        router_v2.get("/users", dummy_handler, "get_users")
        router_v2.post("/users", dummy_handler, "post_users")

        local debug = router_v2.debug_routes()
        assert(debug.GET ~= nil, "deve ter GET")
        assert(debug.POST ~= nil, "deve ter POST")
        assert(#debug.GET == 1, "deve ter 1 rota GET")
        assert(#debug.POST == 1, "deve ter 1 rota POST")
    end)

    it("retorna rotas por método", function()
        router_v2.get("/users", dummy_handler)
        router_v2.post("/users", dummy_handler)
        router_v2.put("/posts", dummy_handler)

        local get_routes = router_v2.get_routes("GET")
        local post_routes = router_v2.get_routes("POST")

        assert(#get_routes == 1, "deve ter 1 GET")
        assert(#post_routes == 1, "deve ter 1 POST")
    end)

    it("case-insensitive: GET vs get", function()
        router_v2.register("get", "/users", dummy_handler) -- minúscula

        local handler1 = router_v2.match("GET", "/users")  -- maiúscula
        local handler2 = router_v2.match("get", "/users")  -- minúscula

        assert(handler1 ~= nil, "deve encontrar com GET")
        assert(handler2 ~= nil, "deve encontrar com get")
    end)

    it("DSL helpers: get, post, put, delete", function()
        router_v2.get("/users", dummy_handler)
        router_v2.post("/posts", dummy_handler)
        router_v2.put("/comments/:id", dummy_handler)
        router_v2.delete("/items/:id", dummy_handler)

        local count = router_v2.count()
        assert(count == 4, "DSL helpers devem registrar 4 rotas")
    end)
end)
