# ROADMAP Nika

## Objetivo Macro
Construir um framework web Lua minimalista e auditável, mantendo sintaxe ASP em `.nika` (`<% %>`, `<%= %>`) e atingindo paridade comportamental 1:1 com `html/template` e `text/template` do Go em segurança e previsibilidade (por fases, sem migração para `{{ }}`).

## Status Geral
- ✅ Fases 1 a 5 concluídas (MVP funcional e publicado).
- ✅ Suite de integração e regressão de segurança ativa.
- ✅ Pipeline de release (GitHub Release + pacote LuaRocks) configurado.
- ⏳ Próxima frente: paridade comportamental 1:1 de template engine (Go-inspired).

---

## Fases Concluídas (Histórico)

### Fase 1: Fundação e Rastreabilidade (ISO 27001) — ✅ Concluída
| Entrega | Arquivo | Evidência |
| :--- | :--- | :--- |
| Auditoria estruturada (`log_error`, `log_security`) | `src/nika_audit.lua` | `docs/PHASE1_A14_VALIDATION.md` |
| Fábrica req/res com defesa básica | `src/nika_io.lua` | `docs/PHASE1_A14_VALIDATION.md` |

### Fase 2: Motor ASP (Parser + Sandbox) — ✅ Concluída
| Entrega | Arquivo | Evidência |
| :--- | :--- | :--- |
| Compilação `.nika` para Lua com buffer | `src/parser.lua` | `docs/PHASE2_SECURITY_VALIDATION.md` |
| Sandbox restrito de execução | `src/sandbox.lua` | `docs/PHASE2_SECURITY_VALIDATION.md` |

### Fase 3: Ciclo de Vida e Interceptação — ✅ Concluída
| Entrega | Arquivo | Evidência |
| :--- | :--- | :--- |
| Roteamento com bloqueio de traversal | `src/router.lua` | `docs/PHASE3_SECURITY_VALIDATION.md` |
| Engine de hooks e short-circuit seguro | `src/hooks.lua` | `docs/PHASE3_SECURITY_VALIDATION.md` |
| Hook nativo de security headers | `hooks/security_headers.lua` | `docs/PHASE3_SECURITY_VALIDATION.md` |

### Fase 4: Camada de Dados Agnóstica — ✅ Concluída
| Entrega | Arquivo | Evidência |
| :--- | :--- | :--- |
| Wrapper de banco com prepared statements obrigatórios | `src/db.lua` | `docs/PHASE4_SQLI_VALIDATION.md` |

### Fase 5: Integração e Lançamento do MVP — ✅ Concluída
| Entrega | Arquivo | Evidência |
| :--- | :--- | :--- |
| Entrypoint orquestrando pipeline completo | `src/nika.lua` | `docs/PHASE5_FINAL_REVIEW.md` |
| Adapter CGI de referência | `src/adapter_cgi.lua` | `docs/PHASE5_FINAL_REVIEW.md` |
| Quickstart, contribuição e licença | `README.md`, `CONTRIBUTING.md`, `LICENSE.txt` | Repositório |

### Qualidade e Operação — ✅ Concluída
| Entrega | Arquivo |
| :--- | :--- |
| Testes estilo Busted (runner local) | `tests/` |
| Smoke de execução CGI | `scripts/smoke_cgi.lua` |
| Release pipelines | `.github/workflows/release.yml`, `.github/workflows/release-on-tag.yml` |

---

## Próximas Fases: Paridade 1:1 Go Templates (Comportamental)

## Fase 6: Paridade Baseline Formal (HTML/Text) — ✅ Concluída
Objetivo: formalizar baseline já existente e fechar lacunas de previsibilidade.

| Tarefa | Descrição | Definition of Done |
| :--- | :--- | :--- |
| 6.1 Matriz de Contextos — ✅ Concluída | Definir matriz oficial de contextos de saída (`html_text`, `html_attr`, `url`, `js`, `css`) e regras de escape por contexto. | `docs/TEMPLATE_CONTEXT_MATRIX.md` publicado. |
| 6.2 Contrato de Parser — ✅ Concluída | Fixar contrato de compilação para `<%= %>` com metadados de contexto sem alterar sintaxe ASP. | `src/parser.lua` emitindo contexto (`HTML_TEXT`, `HTML_ATTR_QUOTED`, `URL_ATTR`, `JS_STRING`, `CSS_STRING`) e bloqueio runtime para contextos não suportados. |
| 6.3 Testes de Baseline — ✅ Concluída | Expandir regressão para payloads por contexto. | `tests/security_regression_spec.lua` cobrindo matriz mínima com validação no runtime; `lua tests/run_all.lua` verde. |

## Fase 7: Context-Aware Escaping (Go-inspired) — ✅ Concluída
Objetivo: aproximar comportamento de `html/template` na prática.

| Tarefa | Descrição | Definition of Done |
| :--- | :--- | :--- |
| 7.1 Escape por contexto — ✅ Concluída | Implementar funções de escape dedicadas por contexto no runtime. | `src/escape_context.lua` com dispatch automático por contexto (HTML_TEXT, HTML_ATTR_QUOTED, URL_ATTR); testes em `security_regression_spec.lua` validando escapes e bloqueios; compatibilidade retroativa confirmada. |
| 7.2 Seleção determinística — ✅ Concluída | Resolver contexto de saída de forma determinística no compilador, sem mágica implícita. | `tests/determinism_spec.lua` com 16 casos validando determinismo, reprodutibilidade e auditabilidade; `docs/CONTEXT_SELECTION_DETERMINISM.md` documentando algoritmo; 100% reproduzível em múltiplas compilações. |
| 7.3 Compatibilidade retroativa — ✅ Validada | Preservar templates ASP existentes com fallback seguro. | Zero quebra em templates atuais do MVP. |

## Fase 8: Features de Template Inspiradas em Go — ✅ Concluída
Objetivo: elevar expressividade sem perder simplicidade.

| Tarefa | Descrição | Definition of Done |
| :--- | :--- | :--- |
| 8.1 Registry de funções — ✅ Concluída | Definir registry explícito de funções de template (allow-list). | `src/template_functions.lua` com allow-list e validação de símbolos; integração em `src/sandbox.lua` e `src/nika.lua`; testes em `tests/template_functions_registry_spec.lua` validados. |
| 8.2 Blocos reutilizáveis — ✅ Concluída | Adicionar blocos/parciais com semântica previsível e sem ocultar fluxo. | `src/template_partials.lua` com allow-list de parciais, `include()`/`partial()` explícitos no parser e integração no sandbox com limite de profundidade; testes em `tests/template_partials_spec.lua` validados. |
| 8.3 Modo text/template — ✅ Concluída | Criar modo sem auto-escape HTML para casos estritamente textuais. | `template_mode = "text"` implementado no sandbox/nika com isolamento explícito por opção, suporte em parciais e testes em `tests/template_text_mode_spec.lua` cobrindo não regressão de `html`. |

## Fase 9: Validação 1:1 e Hardening Final — ✅ Concluída
Objetivo: concluir meta de paridade comportamental.

| Tarefa | Descrição | Definition of Done |
| :--- | :--- | :--- |
| 9.1 Suite de equivalência — ✅ Concluída | Criar suite de comparação Nika vs comportamentos esperados de Go templates. | `tests/template_equivalence_spec.lua` validando paridade em `HTML_TEXT`, `HTML_ATTR_QUOTED`, `URL_ATTR`, `text mode`, parciais e registry; diferenças conhecidas justificadas em teste: bloqueio hardening de `JS_STRING`, `CSS_STRING` e URL perigosa em modo `html`. |
| 9.2 Pentest final de template engine — ✅ Concluída | Reexecutar auditoria completa XSS/SSTI em todos contextos. | `tests/template_pentest_final_spec.lua` cobrindo XSS por contexto, SSTI, evasão por registry, abuso de parciais, não-vazamento de erro e logging de segurança; suíte completa verde. |
| 9.3 Selo 1:1 comportamental — ✅ Concluída | Publicar documento de conformidade final. | `docs/PHASE9_CONFORMITY_SEAL.md` publicado com checklist final, evidências técnicas, diferenças conhecidas e decisão de aprovação. |

---

## Critérios de Não Regressão (Sempre Ativos)
1. Sem dependências externas no core (exceto exceções explicitamente aprovadas).
2. Sem SQL concatenado com input do usuário.
3. Sem exposição de `_G`, `require`, `io`, `os` no contexto de template.
4. Sem quebra do contrato agnóstico req/res.
5. Sem promessa de paridade 1:1 imediata sem evidência de teste por contexto.

---

## Marco Atual
MVP estável concluído. Fase 9 concluída com equivalência (9.1), pentest final (9.2) e selo de conformidade (9.3). Próxima execução técnica: **Ciclo de manutenção e monitoramento contínuo**.
