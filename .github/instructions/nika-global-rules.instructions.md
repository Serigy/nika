---
description: "Use when implementing, refactoring, or reviewing Nika framework code in Lua or .nika templates. Enforces ISO 27001-oriented security, zero-magic simplicity, sandboxing, and req/res agnostic contracts."
name: "Nika Global Rules"
applyTo: ["**/*.lua", "**/*.nika"]
---

# Regras Globais do Projeto: Framework Nika (Lua)

## Identidade do Projeto
- Nika e um framework web minimalista, agnostico e focado em seguranca (ISO 27001), escrito em Lua.
- O paradigma e inspirado em ASP Classico (templates com logica embarcada).
- Zero-magic: abstrações complexas e fluxo implicito sao proibidos.

## Regras Inquebraveis (Hard Rules)
1. Nunca sugerir dependencias externas (LuaRocks ou bibliotecas C), exceto driver de banco de dados ou criptografia previamente aprovada.
2. Sanitizacao por padrao: qualquer saida HTML com variavel dinamica deve usar `escape()`.
3. Prepared statements obrigatorios: nunca concatenar input do usuario em SQL.
4. Isolamento de template: arquivos `.nika` nao podem acessar `_G`, `require`, `os` ou `io`; usar `_ENV` (Lua 5.2+) ou `setfenv` (Lua 5.1).
5. Agnosticismo HTTP no core: nao usar `ngx.*` ou APIs especificas de servidor; manter contrato req/res.
6. Performance de string: proibido `..` em loops de renderizacao; usar `table.insert(buffer, str)` e `table.concat(buffer)`.
7. Auditoria e erros: falhas de seguranca, input invalido e erros de sistema devem ser logados (ex.: `nika_audit.log_security` e `nika_audit.log_error`); nao expor stack trace ao usuario final; usar `pcall` em areas de risco.
8. Templates `.nika` mantem sintaxe ASP (`<% %>`, `<%= %>`). `html/template` e `text/template` do Go sao referencia de comportamento seguro (escaping/contexto), adotado por fases, sem promessa de paridade 1:1 imediata.
9. Mudanca em parser/renderizacao deve incluir validacao de regressao XSS/SSTI com payloads de contexto (HTML texto, atributo, URL, JS e CSS quando aplicavel).

## Fluxo de Trabalho Exigido
- Se a solicitacao for criar feature, perguntar antes se a arquitetura ja foi validada contra ISO 27001.
- Se a solicitacao for revisar codigo, priorizar deteccao de XSS, SSTI e SQLi antes de estilo, organizacao ou performance.

## Prioridade de Decisao
- Em conflito entre simplicidade e conveniencia, escolher simplicidade auditavel.
- Em conflito entre velocidade de entrega e seguranca, bloquear e propor alternativa minima segura.
