# Context Selection Determinism — Fase 7.2

## Objetivo
Garantir que a seleção de contexto de saída em templates `.nika` seja **determinística**, **reproduzível** e **auditável**, cumprindo requisitos de Security by Design e zero-magic.

---

## Princípios de Determinismo

### 1. Mesma entrada, sempre mesma saída
Uma template compilada em run A deve produzir exatamente o mesmo contexto de saída que em run B.

```lua
-- Compile da mesma template 2x
local compiled1, meta1 = parser.compile('<a href="<%= x %>">link</a>')
local compiled2, meta2 = parser.compile('<a href="<%= x %>">link</a>')

-- meta1.contexts e meta2.contexts devem ser idênticas
assert(meta1.contexts[1] == meta2.contexts[1])  -- ambas "URL_ATTR"
```

### 2. Posição determina contexto
O contexto de uma expressão `<%= ... %>` é determinado **exclusivamente** pela posição anterior no HTML, não por nenhum estado global ou dinâmico.

---

## Algoritmo de Seleção de Contexto

A função `infer_expr_context(template_source, open_start, literal_before)` em [src/parser.lua](../src/parser.lua) aplica as seguintes regras em ordem:

### Regra 1: JS_STRING (prioridade alta)
Se há um `<script>` tag aberto (não fechado) antes da expressão:
```lua
local last_script_open = last_pattern_index(prefix, "<script[%s>]")
local last_script_close = last_pattern_index(prefix, "</script>")
if last_script_open and (not last_script_close or last_script_open > last_script_close) then
    return "JS_STRING"
end
```

**Casos cobertos:**
- `<script>var x = "<%= value %>"</script>` → JS_STRING
- `<script>` (maiúsculas/minúsculas insensível)
- Múltiplas scripts: contexto correto por posição

**Invariantes:**
- Tags case-insensitive (`<SCRIPT>`, `<Script>`)
- Busca de último padrão para lidar com nested tags
- Requer fechamento `</script>` explícito para sair de JS_STRING

### Regra 2: CSS_STRING (prioridade alta)
Análogo a Regra 1, mas para `<style>` tags:
```lua
local last_style_open = last_pattern_index(prefix, "<style[%s>]")
local last_style_close = last_pattern_index(prefix, "</style>")
if last_style_open and (not last_style_close or last_style_open > last_style_close) then
    return "CSS_STRING"
end
```

### Regra 3: HTML_ATTR_QUOTED e URL_ATTR (prioridade média)
Se a última sequência literal antes de `<%` terminava com padrão de atributo (`name="` ou `name='`):
```lua
local attr_name = lower_literal:match("([%w_:%-]+)%s*=%s*['\"]%s*$")
if attr_name then
    if URL_ATTRS[attr_name] then
        return "URL_ATTR"
    end
    return "HTML_ATTR_QUOTED"
end
```

**URL_ATTRS allow-list:**
```lua
local URL_ATTRS = {
    href = true,
    src = true,
    action = true,
    formaction = true,
    poster = true,
    cite = true,
    data = true,
    srcset = true
}
```

**Casos cobertos:**
- `<a href="<%= value %>">` → URL_ATTR
- `<input value="<%= value %>">` → HTML_ATTR_QUOTED
- Múltiplos atributos na mesma tag
- Espaços em branco e quebras de linha antes de `<%`

**Invariantes:**
- Busca por `name="` ou `name='` no final da literal
- Atributos case-insensitive
- Suporta `-`, `:`, e `_` em nomes de atributo

### Regra 4: HTML_TEXT (fallback)
Se nenhuma das regras anteriores se aplicar, assume HTML_TEXT (conteúdo de elemento):
```lua
return "HTML_TEXT"
```

**Casos cobertos:**
- `<p><%= value %></p>` → HTML_TEXT
- `antes <%= value %> depois` → HTML_TEXT
- Após fechamento de qualquer tag (`</script>`, `</style>`, etc)

---

## Casos Testados (Determinismo Garantido)

| Caso | Entrada | Contexto esperado | Status |
| :--- | :--- | :--- | :--- |
| Recompilação | Mesma template 2x | Contextos idênticos | ✅ |
| Múltiplos outputs | `<%= x %><%= y %>` | HTML_TEXT, HTML_TEXT | ✅ |
| Atributos genéricos | `class="<%= x %>"` | HTML_ATTR_QUOTED | ✅ |
| Atributos URL | `href="<%= x %>"` | URL_ATTR | ✅ |
| Script simples | `<script><%= x %></script>` | JS_STRING | ✅ |
| Script múltiplo | `<script><%= x %></script> <p><%= y %></p> <script><%= z %></script>` | JS_STRING, HTML_TEXT, JS_STRING | ✅ |
| Nested tags | `<div><div><div><%= x %></div></div></div>` | HTML_TEXT | ✅ |
| Espaços em atributo | `value="<%= x %>"` (com `\n`) | HTML_ATTR_QUOTED | ✅ |
| Case-insensitive | `<SCRIPT>` vs `<script>` | JS_STRING | ✅ |
| Fechamento expl. | `</script><%= x %>` | HTML_TEXT | ✅ |

---

## Auditabilidade

### Extração de contextos compilados
Para inspecionar contextos atribuídos a uma template:

```lua
local parser = require("parser")
local compiled, metadata = parser.compile(template_source)
print("Contextos:", table.concat(metadata.contexts, ", "))
```

Exemplo:
```lua
local compiled, meta = parser.compile('<p><%= x %></p><a href="<%= y %>">link</a>')
-- meta.contexts = { "HTML_TEXT", "URL_ATTR" }
```

### Verificação no código compilado
Cada expressão `<%= ... %>` emite chamada `__nika_emit("CONTEXT", expr)`:

```lua
-- Template: <p><%= value %></p>
-- Compilado:
__nika_emit("HTML_TEXT", value)
```

Permite auditoria manual ou automatizada.

---

## Garantias de Não Regressão

1. **Determinismo:** Compilação de mesma template sempre produz mesmos contextos.
2. **Reprodutibilidade:** Contexto depende únicamente de conteúdo literal e posição no HTML.
3. **Auditabilidade:** Metadados retornados e chamadas de emissão rastreáveis.
4. **Segurança:** Regras de priorizacao (JS/CSS antes de atributos) garantem escapamento correto em casos ambíguos.

---

## Próximas Melhorias (Fase 8+)

- Suporte a comentários HTML com `<!--` `-->`
- Casos de CDATA e XML
- Registry explícito de contextos com warn/error em ambígüidades
- Tooling de análise estática de templates para alertar sobre mudanças intencionais de contexto
