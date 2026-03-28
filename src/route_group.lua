-- Route Group: Agrupador de rotas com prefix + middleware scoping
-- Permite /api/v1, /api/v2, etc. com middlewares específicos por grupo
-- Integração com router_v2 e middleware_chain

local M = {}

-- Cria um novo grupo de rotas
-- prefix: /api/v1
-- router_v2: instância de router_v2.lua
-- middleware_chain: instância de middleware_chain.lua
local function create_group(prefix, router_v2, middleware_chain)
    local group = {
        _prefix = prefix,
        _router = router_v2,
        _middleware = middleware_chain,
        _middlewares = {}, -- middlewares específicos deste grupo
        _route_names = {}  -- names das rotas registradas neste grupo
    }

    -- DSL helpers: registra rotas prefixadas
    function group.get(pattern, handler, name)
        local full_pattern = group._prefix .. pattern
        local route_name = group._router.register("GET", full_pattern, handler, name)
        table.insert(group._route_names, route_name)
        return route_name
    end

    function group.post(pattern, handler, name)
        local full_pattern = group._prefix .. pattern
        local route_name = group._router.register("POST", full_pattern, handler, name)
        table.insert(group._route_names, route_name)
        return route_name
    end

    function group.put(pattern, handler, name)
        local full_pattern = group._prefix .. pattern
        local route_name = group._router.register("PUT", full_pattern, handler, name)
        table.insert(group._route_names, route_name)
        return route_name
    end

    function group.delete(pattern, handler, name)
        local full_pattern = group._prefix .. pattern
        local route_name = group._router.register("DELETE", full_pattern, handler, name)
        table.insert(group._route_names, route_name)
        return route_name
    end

    function group.patch(pattern, handler, name)
        local full_pattern = group._prefix .. pattern
        local route_name = group._router.register("PATCH", full_pattern, handler, name)
        table.insert(group._route_names, route_name)
        return route_name
    end

    function group.head(pattern, handler, name)
        local full_pattern = group._prefix .. pattern
        local route_name = group._router.register("HEAD", full_pattern, handler, name)
        table.insert(group._route_names, route_name)
        return route_name
    end

    -- Registra middleware específico deste grupo
    -- Middlewares de grupo são executados antes/depois de handlers neste grupo
    function group.use(middleware_fn, name, priority)
        if type(middleware_fn) ~= "function" then
            error("Middleware deve ser function")
        end

        name = name or "group_mid_" .. math.random(10000, 99999)
        priority = priority or 50

        table.insert(group._middlewares, {
            fn = middleware_fn,
            name = name,
            priority = priority
        })

        return name
    end

    -- Retorna middlewares deste grupo
    function group.get_middlewares()
        return group._middlewares
    end

    -- Retorna nomes das rotas registradas neste grupo
    function group.get_routes()
        return group._route_names
    end

    -- Retorna prefix deste grupo
    function group.prefix()
        return group._prefix
    end

    -- Retorna informações do grupo
    function group.info()
        return {
            prefix = group._prefix,
            route_count = #group._route_names,
            middleware_count = #group._middlewares
        }
    end

    return group
end

-- Factory: cria novo route group
function M.new(prefix, router_v2, middleware_chain)
    if not prefix or prefix == "" then
        prefix = "/"
    end

    -- Normaliza prefix
    if prefix:sub(1, 1) ~= "/" then
        prefix = "/" .. prefix
    end

    -- Remove trailing slash (exceto na raiz)
    if prefix:sub(-1) == "/" and prefix ~= "/" then
        prefix = prefix:sub(1, -2)
    end

    if not router_v2 then
        error("router_v2 é obrigatório")
    end

    if not middleware_chain then
        error("middleware_chain é obrigatório")
    end

    return create_group(prefix, router_v2, middleware_chain)
end

-- Cria subgrupo a partir de outro grupo
-- Permite: /api -> /api/v1 -> /api/v1/users
function M.subgroup(parent_group, sub_prefix)
    if not parent_group or not parent_group._prefix then
        error("parent_group deve ser um route group válido")
    end

    local combined_prefix = parent_group._prefix .. sub_prefix
    local subgroup = M.new(combined_prefix, parent_group._router, parent_group._middleware)

    -- Herda middlewares do parent (opcional - pode remover se não desejar)
    -- for _, mid in ipairs(parent_group:get_middlewares()) do
    --     subgroup:use(mid.fn, mid.name, mid.priority)
    -- end

    return subgroup
end

return M
