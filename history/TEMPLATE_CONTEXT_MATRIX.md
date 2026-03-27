# TEMPLATE_CONTEXT_MATRIX

## Objetivo
Definir a matriz oficial de contextos de saída para o Nika, mantendo sintaxe ASP (`<% %>`, `<%= %>`) e guiando a evolução de paridade comportamental com Go `html/template` e `text/template`.

Este documento orienta:
- `src/parser.lua`
- `src/sandbox.lua`
- `tests/security_regression_spec.lua`

## Escopo
- Escopo atual: template output e prevenção de XSS/SSTI.
- Fora de escopo nesta fase: mudança de sintaxe para `{{ }}` e reescrita completa de parser.

---

## Fases de Aderência

### Fase BASELINE (atual mínima obrigatória)
- Toda saída dinâmica em `<%= %>` passa por `escape()`.
- Sandbox impede acesso a globais perigosas (`_G`, `require`, `os`, `io`, etc.).
- Parser preserva literais como string segura.

### Fase PARCIAL (transição)
- Introduzir diferenciação de contexto em pontos críticos (atributo e URL primeiro).
- Incluir testes de regressão por contexto.

### Fase TARGET (1:1 comportamental Go-inspired)
- Resolver contexto de saída de forma determinística para HTML text, attr, URL, JS, CSS.
- Cobertura de testes de injeção por contexto com equivalência documentada.

---

## Matriz de Contextos

| Contexto | Exemplo de template ASP | Risco principal | Estratégia de escape esperada | Status atual |
| :--- | :--- | :--- | :--- | :--- |
| HTML_TEXT | `<p><%= value %></p>` | XSS por tags/script | Escape HTML (`&`, `<`, `>`, `"`, `'`) | BASELINE |
| HTML_ATTR_QUOTED | `<input value="<%= value %>">` | Quebra de atributo + XSS | Escape de atributo (HTML + aspas) | PARCIAL |
| URL_ATTR | `<a href="<%= value %>">` | `javascript:` / URI injection | Sanitização de esquema + encode URL | PARCIAL |
| JS_STRING | `<script>var x="<%= value %>"</script>` | JS injection / breakout | Escape específico de JS string | FUTURO |
| CSS_STRING | `<style>.x{background:url('<%= value %>')}</style>` | CSS/URL injection | Escape CSS + política de URL segura | FUTURO |
| RAW_TEXT_TEMPLATE | `<% write(value) %>` em modo texto controlado | Injeção por escrita direta | Uso restrito e explícito, sem HTML rendering implícito | FUTURO |

Observação:
- Enquanto não houver context-aware escaping completo, considerar `JS_STRING` e `CSS_STRING` como `BLOQUEADO` para dados não confiáveis.

---

## Regras de Decisão por Contexto

1. HTML_TEXT
- Permitido no baseline com `escape()` obrigatório.

2. HTML_ATTR_QUOTED
- Se não houver rotina específica de atributo, tratar como risco `HIGH` quando input for não confiável.

3. URL_ATTR
- Bloquear ou normalizar esquemas não permitidos (`javascript:`, `data:` para casos não autorizados).
- Recomendado allow-list de esquemas (`http`, `https`, `mailto`) por padrão.

4. JS_STRING
- Sem escape de contexto JS, classificar como `BLOQUEADO` para input externo.

5. CSS_STRING
- Sem escape CSS contextual, classificar como `BLOQUEADO` para input externo.

---

## Payloads de Regressão (Mínimo Obrigatório)

### HTML_TEXT
- Payload: `<script>alert(1)</script>`
- Esperado: render como texto literal escapado (sem execução).

### HTML_ATTR_QUOTED
- Payload: `\"><img src=x onerror=alert(1)>`
- Esperado: sem quebra de atributo e sem execução de evento.

### URL_ATTR
- Payload: `javascript:alert(1)`
- Esperado: bloqueio/sanitização para esquema seguro.

### JS_STRING
- Payload: `";alert(1);//`
- Esperado: sem execução; enquanto não suportado, caminho deve ser bloqueado para input não confiável.

### CSS_STRING
- Payload: `');background-image:url(javascript:alert(1));/*`
- Esperado: sem execução; enquanto não suportado, caminho deve ser bloqueado para input não confiável.

### SSTI / Sandbox
- Payload: `<% os.execute('id') %>`
- Esperado: acesso negado no sandbox, sem exposição de stack trace ao usuário.

---

## Casos de Teste Recomendados

1. `tests/security_regression_spec.lua`
- adicionar `describe("Template context matrix")` com um `it` por contexto.
- validar `BASELINE` para HTML_TEXT.
- validar bloqueio para JS/CSS enquanto contexto não for implementado.

2. `tests/integration_mvp_spec.lua`
- manter cobertura de fluxo completo com hooks e headers.

3. Casos negativos
- garantir erro seguro (`Erro interno`) sem vazar detalhes.
- verificar log de segurança quando contexto bloqueado.

---

## Critérios de Aceite da Fase 6.1

1. Matriz documentada e usada como referência de implementação.
2. Contextos classificados por status (`BASELINE`, `PARCIAL`, `FUTURO`).
3. Payloads de regressão definidos para parser/sandbox/testes.
4. Regras explícitas de bloqueio para contextos ainda não suportados.

---

## Decisões Arquiteturais

1. Manter sintaxe ASP em `.nika`.
2. Perseguir paridade comportamental com Go templates por fases.
3. Priorizar segurança determinística sobre conveniência.
4. Não introduzir dependências externas no core para resolver escaping contextual nesta etapa.
