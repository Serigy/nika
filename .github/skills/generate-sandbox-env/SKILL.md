---
name: generate-sandbox-env
description: 'Gera código Lua para _ENV (Lua 5.2+) ou wrapper com setfenv (Lua 5.1), expondo apenas símbolos de uma allow-list para execução segura de templates no Nika.'
argument-hint: 'Informe a allow-list de símbolos permitidos, por exemplo: ["Request", "escape", "math.random"].'
user-invocable: true
---

# Generate Sandbox Env

## O que esta skill produz
Retorna código Lua para inicialização de ambiente estrito de template com base em uma allow-list:
- variante Lua 5.2+ com `load(..., env)` usando tabela de ambiente restrita
- variante Lua 5.1 com `setfenv` em wrapper seguro
- execução previsível e auditável alinhada ao objetivo de segurança inspirado em Go templates (sem mudar sintaxe ASP do Nika)

## Quando usar
- Construção de motor de template no Nika com isolamento de escopo.
- Revisão de segurança para evitar acesso a `_G`, `io`, `os`, `require` e bibliotecas perigosas.
- Geração rápida de boilerplate auditável para sandbox de execução.
- Evolução incremental de comportamento seguro em templates mantendo simplicidade do core.

## Entrada esperada
- Array de strings com símbolos permitidos.
- Exemplo: `["Request", "escape", "math.random"]`

## Procedimento
1. Normalizar e validar allow-list.
- Remover duplicatas e entradas vazias.
- Rejeitar símbolos proibidos: `_G`, `require`, `io`, `os`, `package`, `debug`, `load`, `loadfile`, `dofile`.

2. Resolver símbolos hierárquicos.
- Para itens simples (`Request`, `escape`), mapear diretamente no ambiente.
- Para itens com caminho (`math.random`), expor apenas a função final via alias seguro, sem abrir toda a biblioteca.

3. Construir ambiente estrito.
- Gerar tabela com apenas os símbolos permitidos.
- Opcionalmente proteger com metatable bloqueando leitura/escrita de chaves não permitidas.

4. Escolher estratégia por versão Lua.
- Lua 5.2+: usar `load(compiled, "template", "t", safe_env)`.
- Lua 5.1: usar `setfenv(chunk, safe_env)` antes da execução.

5. Emitir código final com tratamento de erro.
- Incluir `pcall` na execução.
- Retornar erro interno sem vazar stack trace para usuário final.

6. Declarar aderência por fase (Go-inspired).
- BASELINE: isolamento forte e execução determinística.
- PARCIAL: controles básicos presentes, mas sem garantias de escaping por contexto.
- BLOQUEADO: exposição de globais perigosas ou comportamento não determinístico.

## Regras de decisão
- Se a allow-list contiver qualquer símbolo proibido: bloquear geração e retornar código com erro explícito de validação.
- Se houver símbolo hierárquico inválido: bloquear geração e listar o item inválido.
- Se a allow-list estiver vazia: gerar ambiente mínimo sem APIs de sistema.
- Nunca expor tabelas globais completas por conveniência.
- Nunca mudar sintaxe de template para `{{ }}` neste fluxo; foco é sandbox e previsibilidade de execução.

## Critérios de qualidade e conclusão
- O código gerado deve conter validação de allow-list.
- O código gerado deve bloquear acesso a símbolos fora da lista.
- Deve haver variante para Lua 5.2+ e Lua 5.1.
- O snippet deve ser pronto para uso e auditável.
- O resultado deve preservar execução determinística e sem estado global implícito.

## Formato de saída obrigatório
- Entregar apenas código Lua.
- Incluir função de fábrica: `build_safe_env(allowed, context)`.
- Incluir função de execução: `render_sandboxed(compiled_lua_code, allowed, context, lua_version)`.

## Exemplo de saída esperada
```lua
local FORBIDDEN = {
    ["_G"] = true,
    ["require"] = true,
    ["io"] = true,
    ["os"] = true,
    ["package"] = true,
    ["debug"] = true,
    ["load"] = true,
    ["loadfile"] = true,
    ["dofile"] = true,
}

local function resolve_symbol(path, context)
    local cur = context
    for part in string.gmatch(path, "[^%.]+") do
        if type(cur) ~= "table" then
            return nil, "Símbolo inválido: " .. path
        end
        cur = cur[part]
        if cur == nil then
            return nil, "Símbolo não encontrado: " .. path
        end
    end
    return cur
end

local function validate_allowed(allowed)
    local unique = {}
    local out = {}
    for i = 1, #allowed do
        local item = allowed[i]
        if type(item) ~= "string" or item == "" then
            return nil, "Allow-list contém item inválido"
        end
        if FORBIDDEN[item] then
            return nil, "Símbolo proibido na allow-list: " .. item
        end
        if not unique[item] then
            unique[item] = true
            out[#out + 1] = item
        end
    end
    return out
end

local function build_safe_env(allowed, context)
    local valid, err = validate_allowed(allowed)
    if not valid then
        return nil, err
    end

    local env = {}
    for i = 1, #valid do
        local key = valid[i]
        if string.find(key, "%.", 1, true) then
            local value, resolve_err = resolve_symbol(key, context)
            if not value then
                return nil, resolve_err
            end
            env[key] = value
        else
            local value = context[key]
            if value == nil then
                return nil, "Símbolo não encontrado: " .. key
            end
            env[key] = value
        end
    end

    return setmetatable(env, {
        __index = function(_, k)
            error("Acesso negado no sandbox: " .. tostring(k), 2)
        end,
        __newindex = function()
            error("Ambiente sandbox é somente leitura", 2)
        end,
    })
end

local function render_sandboxed(compiled_lua_code, allowed, context, lua_version)
    local env, env_err = build_safe_env(allowed, context)
    if not env then
        return nil, env_err
    end

    local chunk, load_err
    if lua_version == "5.1" then
        chunk, load_err = loadstring(compiled_lua_code)
        if not chunk then
            return nil, "Erro de sintaxe: " .. tostring(load_err)
        end
        setfenv(chunk, env)
    else
        chunk, load_err = load(compiled_lua_code, "template", "t", env)
        if not chunk then
            return nil, "Erro de sintaxe: " .. tostring(load_err)
        end
    end

    local ok, exec_err = pcall(chunk)
    if not ok then
        return nil, "Erro interno na execução do template"
    end

    return true
end
```

## Restrições
- Não expor `_G` ou bibliotecas de sistema por padrão.
- Não usar metaprogramação complexa desnecessária.
- Não sugerir dependências externas para resolver sandbox básico.
