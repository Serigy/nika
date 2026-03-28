-- tests/route_group_spec.lua
-- Testes para route_group.lua (Phase 10)
-- Valida namespacing, prefixing, middleware scoping

local route_group = require("route_group")
local router_v2 = require("router_v2")
local middleware_chain = require("middleware_chain")

describe("Route Group (Phase 10)", function()
    local function dummy_handler() end

    before_each(function()
        router_v2.clear()
        middleware_chain.clear()
    end)

    it("cria novo grupo com prefix", function()
        local group = route_group.new("/api/v1", router_v2, middleware_chain)

        assert(group ~= nil, "deve criar grupo")
        assert(group.prefix() == "/api/v1", "deve retornar prefix correto")
    end)

    it("normaliza prefix: adiciona / se falta", function()
        local group = route_group.new("api/v1", router_v2, middleware_chain)

        assert(group.prefix() == "/api/v1", "deve adicionar / no início")
    end)

    it("normaliza prefix: remove trailing / se houver", function()
        local group = route_group.new("/api/v1/", router_v2, middleware_chain)

        assert(group.prefix() == "/api/v1", "deve remover / no final")
    end)

    it("preserva / como root prefix", function()
        local group = route_group.new("/", router_v2, middleware_chain)

        assert(group.prefix() == "/", "deve preservar /")
    end)

    it("registra rotas com prefix automático", function()
        local group = route_group.new("/api/v1", router_v2, middleware_chain)

        group.get("/users", dummy_handler)

        -- Verifica se foi registrada como /api/v1/users
        local handler = router_v2.match("GET", "/api/v1/users")
        assert(handler ~= nil, "deve registrar com prefix")
    end)

    it("DSL: get, post, put, delete com prefix", function()
        local group = route_group.new("/api/v1", router_v2, middleware_chain)

        group.get("/users", dummy_handler)
        group.post("/posts", dummy_handler)
        group.put("/items/:id", dummy_handler)
        group.delete("/comments/:id", dummy_handler)

        assert(router_v2.match("GET", "/api/v1/users") ~= nil)
        assert(router_v2.match("POST", "/api/v1/posts") ~= nil)
        assert(router_v2.match("PUT", "/api/v1/items/123") ~= nil)
        assert(router_v2.match("DELETE", "/api/v1/comments/5") ~= nil)
    end)

    it("registra middleware específico do grupo", function()
        local group = route_group.new("/api/v1", router_v2, middleware_chain)

        local mid = function() end
        local name = group.use(mid, "auth_mid", 50)

        assert(name ~= nil, "deve registrar middleware")
        assert(#group.get_middlewares() == 1, "deve contar 1 middleware")
    end)

    it("retorna middlewares do grupo", function()
        local group = route_group.new("/api/v1", router_v2, middleware_chain)

        group.use(function() end, "mid1", 50)
        group.use(function() end, "mid2", 30)

        local mids = group.get_middlewares()
        assert(#mids == 2, "deve retornar 2 middlewares")
    end)

    it("retorna rotas registradas no grupo", function()
        local group = route_group.new("/api/v1", router_v2, middleware_chain)

        group.get("/users", dummy_handler, "get_users")
        group.post("/users", dummy_handler, "post_users")

        local routes = group.get_routes()
        assert(#routes == 2, "deve retornar 2 rotas")
    end)

    it("retorna informações do grupo", function()
        local group = route_group.new("/api/v1", router_v2, middleware_chain)

        group.get("/users", dummy_handler)
        group.use(function() end)

        local info = group.info()
        assert(info.prefix == "/api/v1", "info deve ter prefix")
        assert(info.route_count == 1, "info deve ter route_count")
        assert(info.middleware_count == 1, "info deve ter middleware_count")
    end)

    it("permite múltiplos grupos com diferentes prefixes", function()
        local v1 = route_group.new("/api/v1", router_v2, middleware_chain)
        local v2 = route_group.new("/api/v2", router_v2, middleware_chain)

        v1.get("/users", dummy_handler)
        v2.get("/users", dummy_handler)

        local h1 = router_v2.match("GET", "/api/v1/users")
        local h2 = router_v2.match("GET", "/api/v2/users")

        assert(h1 ~= nil, "deve registrar em /api/v1")
        assert(h2 ~= nil, "deve registrar em /api/v2")
    end)

    it("rotas com parâmetros funcionam em grupos", function()
        local group = route_group.new("/api", router_v2, middleware_chain)

        group.get("/users/:id", dummy_handler)
        group.get("/posts/:id/comments/:cid", dummy_handler)

        local _, _, params1 = router_v2.match("GET", "/api/users/123")
        local _, _, params2 = router_v2.match("GET", "/api/posts/5/comments/7")

        assert(params1 ~= nil, "deve extrair params para /api/users/123")
        assert(params1.id == "123", "deve extrair id em grupo")

        assert(params2 ~= nil, "deve extrair params para /api/posts/5/comments/7")
        assert(params2.id == "5", "deve extrair id de posts")
        assert(params2.cid == "7", "deve extrair cid de comments")
    end)

    it("cria subgrupo a partir de grupo", function()
        local api = route_group.new("/api", router_v2, middleware_chain)
        local v1 = route_group.subgroup(api, "/v1")

        assert(v1.prefix() == "/api/v1", "subgrupo deve combinar prefixes")
    end)

    it("cada grupo tem seus próprios middlewares", function()
        local g1 = route_group.new("/api/v1", router_v2, middleware_chain)
        local g2 = route_group.new("/api/v2", router_v2, middleware_chain)

        g1.use(function() end, "mid_v1")
        g2.use(function() end, "mid_v2")

        assert(#g1.get_middlewares() == 1, "g1 deve ter 1 middleware")
        assert(#g2.get_middlewares() == 1, "g2 deve ter 1 middleware")
    end)

    it("rejeita router_v2 ausente", function()
        local ok, err = pcall(function()
            route_group.new("/api", nil, middleware_chain)
        end)

        assert(ok == false, "deve lançar erro sem router_v2")
    end)

    it("rejeita middleware_chain ausente", function()
        local ok, err = pcall(function()
            route_group.new("/api", router_v2, nil)
        end)

        assert(ok == false, "deve lançar erro sem middleware_chain")
    end)
end)
