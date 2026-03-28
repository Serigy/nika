-- Router V2: Roteador explícito com suporte a :param, regex, método HTTP
-- Substitui file-system routing gradualmente
-- Suporta: GET /users/:id, POST /api/posts, regex /articles/[0-9]{4}, etc.

local M = {}

local _routes = {}            -- { method → { { pattern, handler, name, lua_pattern, param_names } } }
local _compiled_patterns = {} -- cache de padrões compilados

-- Compila um padrão de rota para regex Lua
-- Exemplos:
--   /users/:id → /users/([^/]+)
--   /posts/:id/comments/:cid → /posts/([^/]+)/comments/([^/]+)
--   /articles/{[0-9]{4}} → /articles/([0-9]{4})
local function compile_pattern(pattern)
    if _compiled_patterns[pattern] then
        return _compiled_patterns[pattern]
    end

    local lua_pattern = pattern

    -- Substitui :param por capture group
    lua_pattern = lua_pattern:gsub(":([a-zA-Z_][a-zA-Z0-9_]*)", "([^/]+)")

    -- Substitui {regex} por capture group com regex
    lua_pattern = lua_pattern:gsub("{([^}]+)}", function(regex)
        return "(" .. regex .. ")"
    end)

    _compiled_patterns[pattern] = lua_pattern
    return lua_pattern
end

-- Extrai nomes de parâmetros de um padrão
-- Exemplo: /users/:id/posts/:cid → { "id", "cid" }
local function extract_param_names(pattern)
    local names = {}
    for param in pattern:gmatch(":([a-zA-Z_][a-zA-Z0-9_]*)") do
        table.insert(names, param)
    end
    return names
end

-- Registra uma rota
-- method: GET, POST, PUT, DELETE, PATCH (case-insensitive)
-- pattern: /users/:id ou /api/{[0-9]+}
-- handler: function(req, res, context) end
-- name: identificador único (gerado se não fornecido)
function M.register(method, pattern, handler, name)
    if type(method) ~= "string" or type(pattern) ~= "string" or
        type(handler) ~= "function" then
        error("Assinatura: register(method, pattern, handler, [name])")
    end

    method = string.upper(method)

    if not pattern:match("^/") then
        pattern = "/" .. pattern
    end

    name = name or (method .. "_" .. pattern:gsub("[^a-zA-Z0-9]", "_") ..
        "_" .. math.random(10000, 99999))

    if not _routes[method] then
        _routes[method] = {}
    end

    local param_names = extract_param_names(pattern)
    local lua_pattern = compile_pattern(pattern)

    table.insert(_routes[method], {
        pattern = pattern,
        lua_pattern = lua_pattern,
        param_names = param_names,
        handler = handler,
        name = name
    })

    return name
end

-- Tenta encontrar rota que corresponde ao método + caminho
-- Retorna: (handler, nil, params) ou (nil, error, nil)
function M.match(method, path)
    method = string.upper(method)

    if not _routes[method] then
        return nil, "Método não registrado: " .. method
    end

    -- Normaliza path
    if not path or path == "" then path = "/" end
    if not path:match("^/") then path = "/" .. path end

    -- Tenta encontrar rota que faz match
    for _, route in ipairs(_routes[method]) do
        local pattern = "^" .. route.lua_pattern .. "$"
        local matches = table.pack(path:match(pattern))

        if matches[1] ~= nil then
            -- Extrai parâmetros
            local params = {}
            for i, param_name in ipairs(route.param_names) do
                params[param_name] = matches[i]
            end

            return route.handler, nil, params
        end
    end

    return nil, string.format("%s %s not found", method, path)
end

-- Retorna lista de rotas registradas
function M.get_routes(method)
    if method then
        method = string.upper(method)
        return _routes[method] or {}
    end
    return _routes
end

-- Limpa todas as rotas
function M.clear()
    _routes = {}
    _compiled_patterns = {}
end

-- DSL helpers para sintaxe mais natural
function M.get(pattern, handler, name)
    return M.register("GET", pattern, handler, name)
end

function M.post(pattern, handler, name)
    return M.register("POST", pattern, handler, name)
end

function M.put(pattern, handler, name)
    return M.register("PUT", pattern, handler, name)
end

function M.delete(pattern, handler, name)
    return M.register("DELETE", pattern, handler, name)
end

function M.patch(pattern, handler, name)
    return M.register("PATCH", pattern, handler, name)
end

function M.head(pattern, handler, name)
    return M.register("HEAD", pattern, handler, name)
end

-- Debug: retorna todas as rotas em formato legível
function M.debug_routes()
    local result = {}
    for method, routes in pairs(_routes) do
        result[method] = {}
        for _, route in ipairs(routes) do
            table.insert(result[method], {
                name = route.name,
                pattern = route.pattern,
                params = route.param_names
            })
        end
    end
    return result
end

-- Retorna contagem total de rotas
function M.count()
    local total = 0
    for _, routes in pairs(_routes) do
        total = total + #routes
    end
    return total
end

return M
