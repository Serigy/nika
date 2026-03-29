# ROADMAP Nika

## Objetivo Macro
Construir um framework web Lua minimalista e auditável, mantendo sintaxe ASP em `.nika` (`<% %>`, `<%= %>`) e atingindo paridade comportamental 1:1 com `html/template` e `text/template` do Go em segurança e previsibilidade (por fases, sem migração para `{{ }}`).

## Status Geral
- ✅ Fases 1 a 5 concluídas (MVP funcional e publicado).
- ✅ Suite de integração e regressão de segurança ativa.
- ✅ Pipeline de release (GitHub Release + pacote LuaRocks) configurado.
- ✅ Fases 6 a 10 concluídas (template engine + core routing/middleware).
- ✅ Fase 11 (REST Dataware ORM + Auto-CRUD) concluída.
- ✅ Fase 12 (File Uploads + Multipart Parsing) concluída.
- ✅ Fase 13 (Error Handling + Route Grouping) concluída.

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
MVP estável concluído. Fase 9 concluída com equivalência (9.1), pentest final (9.2) e selo de conformidade (9.3). Fase 10 concluída com router explícito, context store request-scoped, middleware chain e route groups, com suíte verde em `lua tests/run_all.lua`. Próxima execução técnica: **Fase 11 — REST Dataware ORM + Auto-CRUD**.

---

# PRÓXIMA FRENTE: Framework Maduro — Gin + REST Dataware (3+ meses)

## Visão Estratégica

Evoluir Nika de um micro-framework template-centric para um **framework web minimalista completo**, inspirado no Gin (Go) e integrado nativamente com **REST Dataware** para abstração de dados agnóstica. Objetivos:

1. **Roteamento explícito** (`:id`, regex, método HTTP) substituindo file-system routing
2. **Middlewares estruturados** com contexto local request-scoped
3. **ORM nativo Lua** (REST Dataware) com auto-CRUD generator e query builder fluente
4. **File uploads** com validação MIME + multipart parsing
5. **Tratamento centralizado de erros** + route grouping
6. **Validação + binding** automáticos + security middleware nativa (CORS, CSRF, rate-limit)

**Timeline:** 5 fases sequenciais (Fases 10-14), ~10 semanas, cada uma com ISO 27001 audit.

---

## Fase 10: Core Routing + Middleware Context (Semanas 1-2) — ✅ Concluída

**Objetivo:** Foundation para rota com parâmetros, grupos, método HTTP, e context local request-scoped.

### Arquitetura

```
         /users/:id
             ↓
    ┌─────────────────────┐
    │  router.compile()   │ Regex compile: /users/(\d+)
    │  pattern → syntax   │
    └────────┬────────────┘
             ↓
    ┌─────────────────────┐
    │  route.resolve()    │ Match: /users/123 → params = {id = "123"}
    │  /:id → { id }      │
    └────────┬────────────┘
             ↓
    ┌─────────────────────┐
    │  middleware chain   │ before_request → handler → after_request
    │  + context_store    │ context.set("user_id", 123)
    └─────────────────────┘
```

### Componentes Novos

| Arquivo | Responsabilidade | Status |
|---------|------------------|--------|
| `src/router_v2.lua` | Router explícito com suporte para `:param`, regex, método HTTP | ✅ |
| `src/context_store.lua` | Isolamento request-scoped via UUID; sandbox-safe; cleanup automático | ✅ |
| `src/middleware_chain.lua` | Sequenciador de middlewares com prioridade; backward compat com `hooks.lua` | ✅ |
| `src/route_group.lua` | Namespace de rotas (`/api/v1`); middleware scoping por grupo | ✅ |

### Modificações em Arquivos Existentes

| Arquivo | Mudança |
|---------|---------|
| `src/nika.lua` | Integrar `router_v2`, deprecate FS resolver com warning logs |
| `src/hooks.lua` | Manter compatibilidade; delegar para `middleware_chain` |
| `src/nika_io.lua` | Adicionar `req.params`, `req.context` binding |
| `src/sandbox.lua` | Estender _ENV com read-only `context_store` access |

### Sintaxe Nova (Nika)

```lua
-- Novo router explícito
local router = nika.router()

-- Rotas com parâmetros
router.get("/users/:id", function(req, res)
  local user_id = req.params.id
  return res.json({id = user_id})
end)

router.post("/users", function(req, res)
  return res.status(201).json({created = true})
end)

-- Route groups para namespacing
local api_v1 = router.group("/api/v1")
api_v1.get("/posts/:id", function(req, res)
  return res.json({post_id = req.params.id})
end)

-- Middleware com contexto local
router:use(function(req, res, context)
  context.set("user_id", 123)
  context.set("roles", {"admin"})
end)
```

### Definition of Done

- [x] Router compila `/users/:id`, `/posts/:id/comments/:cid`, regex `/articles/[0-9]{4}` sem erro
- [x] Parâmetros extraídos: `/users/123` → `req.params = {id = "123"}`
- [x] Método HTTP descriminado: `GET /users` ≠ `POST /users`
- [x] `context.set(key, val)` sobrevive middleware chain; limpo após response
- [x] Backward compat com file-system routing **deprecated** (logs avisam migração até Fase 12)
- [x] Testes: `tests/router_v2_spec.lua`, `tests/context_store_spec.lua`, `tests/middleware_chain_spec.lua`, `tests/route_group_spec.lua`
- [x] ISO 27001: Context store não vaza dados entre requisições

---

## Fase 11: REST Dataware ORM + Auto-CRUD (Semanas 3-4) — ✅ Concluída

**Objetivo:** ORM Lua nativo com query builder fluente + gerador automático de rotas CRUD.

### Arquitetura

```
    ┌──────────────────────────┐
    │   nika.model('User')     │ Registry de modelos + schema
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │   QueryBuilder (Lua)     │ Fluent: find(), create(), update()
    │   .where(), .select()    │ + pagination, sort, eager load
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │   Database Adapter       │ Prepared statement wrapper
    │   (SQLite, Postgres...)  │
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │   Audit + Multi-tenancy  │ tenant_id filter automático
    │  (log CRUD operations)   │
    └──────────────────────────┘
```

### Componentes Novos

| Arquivo | Responsabilidade | Status |
|---------|------------------|--------|
| `src/dataware.lua` | Model registry + schema DSL | ✅ |
| `src/query_builder.lua` | Fluent API: `find()`, `create()`, `where()`, `select()`, `order_by()`, `limit()`, `paginate()`, `with()` | ✅ |
| `src/auto_crud.lua` | Generator: Model → 5 rotas CRUD (List, Get, Create, Update, Delete) | ✅ |
| `src/dataware_audit.lua` | Log automático de CRUD + tenant violation | ✅ |
| `src/dataware_tenancy.lua` | Middleware: auto-inject `tenant_id` em todas queries | ✅ |

### Sintaxe Nova (Nika)

```lua
-- Definir modelo
local User = nika.model('User')
  :schema({
    id = "integer|pk",
    name = "string",
    email = "email",
    created_at = "datetime"
  })
  :table("users")

-- Query flourente
local active_users = User:find()
  :where("active", "=", true)
  :order_by("created_at", "desc")
  :limit(10)
  :all()

local user = User:find(123):first()

-- Create
User:create({name = "John", email = "john@example.com"})

-- Update
User:find(123):update({name = "Jane"})

-- Delete
User:find(123):delete()

-- Relacionamentos (eager load)
local posts = User:find(1):with("posts"):first()

-- Auto-CRUD routes geradas
-- GET    /api/users              (list com paginação)
-- GET    /api/users/:id          (get um)
-- POST   /api/users              (create)
-- PUT    /api/users/:id          (update)
-- DELETE /api/users/:id          (delete)
```

### Definition of Done

- [x] Define modelo com schema DSL; compila sem erro
- [x] CRUD routes geradas automaticamente (5 rotas)
- [x] Query builder funciona: `User:find():where(...):select(...):first()`
- [x] Relacionamentos (eager load): `User:find(1):with("posts")`
- [x] Audit: logs registram CREATE, UPDATE, DELETE e tenant violations
- [x] Multi-tenancy: middleware auto-injeta `tenant_id`; query sem tenant retorna erro
- [x] Paginação: `list, total = User:find():paginate(page=1, per_page=10)`
- [x] Testes: `tests/dataware_spec.lua`, `tests/query_builder_spec.lua`, `tests/auto_crud_spec.lua`, `tests/dataware_audit_spec.lua`, `tests/dataware_tenancy_spec.lua`
- [x] ISO 27001: QueryBuilder usa prepared statements; tenant_id validado

---

## Fase 12: File Uploads + Multipart Parsing (Semanas 5-6) — ✅ Concluída

**Objetivo:** Suporte completo a upload de arquivos com validação MIME, size check, armazenamento plugável.

### Arquitetura

```
    ┌─────────────────────┐
    │  multipart.parse()  │ Content-Type: multipart/form-data
    └────────┬────────────┘
             ↓
    ┌─────────────────────┐
    │  file validator     │ MIME type, size, extension whitelist
    └────────┬────────────┘
             ↓
    ┌─────────────────────┐
    │  storage strategy   │ /uploads, S3 plugin, GCS plugin
    │  (plugável)         │
    └────────┬────────────┘
             ↓
    ┌─────────────────────┐
    │  req.files registry │ Acesso em handler/templates
    └─────────────────────┘
```

### Componentes Novos

| Arquivo | Responsabilidade | Status |
|---------|------------------|--------|
| `src/multipart.lua` | Parser multipart/form-data (boundary-safe) | ✅ |
| `src/file_validator.lua` | MIME whitelist, size limits, extension sanitize | ✅ |
| `src/file_storage.lua` | Interface plugável (File provider default) | ✅ |
| `src/file_manager.lua` | Wrapper: validate(), store(), cleanup() por request | ✅ |

### Sintaxe Nova (Nika)

```lua
-- Handler com upload
router.post("/api/documents", function(req, res)
  local files = req.files
  local form = req.form_data
  
  if not file_validator.is_whitelisted(files[1].content_type) then
    return res.status(400).json({error = "MIME not allowed"})
  end
  
  local path = file_manager.store(files[1], {
    dir = "/uploads/documents",
    max_size = "100MB",
    allowed_mime = {"application/pdf", "image/jpeg"}
  })
  
  return res.status(200).json({path = path})
end)
```

### Definition of Done

- [x] Parse multipart com N fields + N files
- [x] Extrai metadados em `req.files` (`filename`, `content_type`, `size`, `path`)
- [x] Validação: rejeita MIME não-whitelist (ex: .exe)
- [x] File size limit: rejeita > 100MB (configurável)
- [x] Armazena em `uploads/id_filename` com provider local padrão
- [x] Cleanup: remove arquivos temporários após resposta por `request_id`
- [x] Erro handling: 413 Payload Too Large, 400 Bad Request
- [x] Testes: `tests/multipart_spec.lua`, `tests/file_validator_spec.lua`, `tests/file_storage_spec.lua`, `tests/file_manager_spec.lua`, `tests/adapter_cgi_multipart_spec.lua`, `tests/nika_upload_flow_spec.lua`
- [x] ISO 27001: Filenames sanitizados; MIME verificado; path traversal bloqueado

---

## Fase 13: Error Handling + Route Grouping (Semanas 7-8) — ✅ Concluída

**Objetivo:** Error handler centralizado, route grouping com middleware scope, versionamento API.

### Arquitetura

```
    ┌──────────────────────────┐
    │  error handler (global)  │ Catch 4xx, 5xx; custom response
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  route_group             │ Prefix + middleware scope
    │  /api/v1                 │
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  Resultado              │ /api/v1/users/:id com error handling
    │  versioning, fallback   │
    └──────────────────────────┘
```

### Componentes Novos

| Arquivo | Responsabilidade | Status |
|---------|------------------|--------|
| `src/error_handler.lua` | Centralizador com custom formatters (JSON, HTML, XML) | ✅ |
| `src/error_formatter.lua` | JSON, XML, HTML; stack trace only in dev | ✅ |

### Sintaxe Nova (Nika)

```lua
-- Error handler global
nika.set_error_handler(function(err, context)
  if err.status == 401 then
    return {status = 401, body = json({error = "Unauthorized"})}
  elseif err.status == 404 then
    return {status = 404, body = json({error = "Not Found"})}
  else
    local msg = os.getenv("ENV") == "prod" and "Internal Error" or err.message
    return {status = 500, body = json({error = msg})}
  end
end)

-- Route groups com middleware
local api_v1 = router.group("/api/v1")
api_v1:use(auth_middleware)
api_v1:use(rate_limit_middleware)
api_v1.get("/users/:id", get_user_handler)

local api_v2 = router.group("/api/v2")
api_v2.get("/users/:id", get_user_v2_handler)
```

### Definition of Done

- [x] Error handler centralizado captura 4xx, 5xx
- [x] Custom formatters: JSON, HTML, XML
- [x] Stack trace hidden in prod; dev mostra completo
- [x] Route groups com prefix correto: `/api/v1/users/:id`
- [x] Middleware por grupo (não herda global)
- [x] Error handler responde com Content-Negotiation (Accept header)
- [x] Testes: `tests/error_handler_spec.lua`, `tests/route_group_spec.lua`, `tests/nika_middleware_error_flow_spec.lua`, `tests/nika_stress_errors_spec.lua`
- [x] ISO 27001: Stack trace nunca exposto em produção (validado em `history/PHASE13_ISO27001_VALIDATION.md`)

---

## Fase 14: Validation + Binding + Security Middleware (Semanas 9-10) — ✅ Concluída

**Objetivo:** Request validation, JSON/form binding, CORS/CSRF/rate-limit nativos.

### Arquitetura

```
    ┌──────────────────────────┐
    │  schema validator        │ JSON schema, form schema
    │  (input guards)          │
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  binder (JSON, form)     │ Auto-map request → Lua table
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  Security middlewares    │ CORS, CSRF, rate-limit
    └──────────────────────────┘
```

### Componentes Novos

| Arquivo | Responsabilidade | Status |
|---------|------------------|--------|
| `src/validator.lua` | Schema validator declarativo com limites de payload | ✅ |
| `src/binder.lua` | Binding de `req.body_table`/`req.form_data` com coerção segura | ✅ |
| `src/middleware_cors.lua` | CORS allow-list + preflight `OPTIONS` | ✅ |
| `src/middleware_csrf.lua` | CSRF double-submit cookie+header para métodos mutáveis | ✅ |
| `src/middleware_ratelimit.lua` | Rate-limit in-memory por IP com `429` + `Retry-After` | ✅ |

### Sintaxe Nova (Nika)

```lua
-- Schema validator
local UserCreateSchema = validator.schema({
  name = "string|required|min:3|max:100",
  email = "email|required",
  age = "integer|optional|min:18"
})

-- Handler com validação + binding
router.post("/api/users", function(req, res)
  local user_data, errors = nika.validate_and_bind(req, UserCreateSchema)
  if errors then
    return res.status(400).json({errors = errors})
  end
  
  local user = User:create(user_data)
  return res.status(201).json(user)
end)

-- Security middleware
router:use(middleware_cors({
  allowed_origins = {"https://app.example.com"},
  allowed_methods = {"GET", "POST", "PUT", "DELETE"},
  allowed_headers = {"Content-Type", "Authorization"}
}))

router:use(middleware_csrf())
router:use(middleware_ratelimit({
  window = 60,
  max_requests = 100,
  retry_after_header = true
}))
```

### Definition of Done

- [x] Schema validator rejeita payload inválido com mensagens claras
- [x] Binder: JSON/form → Lua table automático
- [x] CORS: preflight (OPTIONS) respondido; origin validation
- [x] CSRF: double-submit cookie+header em POST/PUT/PATCH/DELETE
- [x] Rate-limit: per-IP enforced; 429 com Retry-After
- [x] Testes: `tests/validator_spec.lua`, `tests/binder_spec.lua`, `tests/security_middleware_spec.lua`
- [x] ISO 27001: Validator rejeita payloads > 1MB; CSRF bloqueia token inválido; rate-limit reduz brute force

---

## Backward Compatibility & Migration Path

| Fase | Ação |
|------|------|
| **Fase 10 launch** | File-system routing em modo "deprecated"; warning logs |
| **Fim Fase 11** | Release migration guide com exemplos de refactor FS → Gin |
| **Fim Fase 12** | (Opcional) Deprecation warning mais forte |
| **v2.0 release** | File-system routing removido; Gin-style obrigatório |

---

## Reuso de Componentes Existentes

| Arquivo | Uso Atual | Integração Proposta |
|---------|-----------|-------------------|
| [src/router.lua](src/router.lua) | FS routing | Deprecate; manter resolver_404 |
| [src/hooks.lua](src/hooks.lua) | 3-stage hooks | Migrar para `middleware_chain` (compat) |
| [src/nika_io.lua](src/nika_io.lua) | Abstração req/res | Adicionar `req.params`, `req.files`, context binding |
| [src/db.lua](src/db.lua) | Prepared statements | Base para `query_builder`; reuse driver interface |
| [src/sandbox.lua](src/sandbox.lua) | Isolamento template | Estender _ENV com `context_store` (read-only) |
| [src/nika_audit.lua](src/nika_audit.lua) | Log segurança | Reuse para audit CRUD + error handling |
| [src/adapter_cgi.lua](src/adapter_cgi.lua) | CGI I/O | Chamar `multipart.parse()` em Content-Type check |

---

## Verificação Não Regressão (Contínua)

1. **Compatibilidade:** Templates `.nika` existentes renderizam sem quebra
2. **Segurança:** Sandbox _ENV intacto; escaping contextual preservado
3. **Auditoria:** Logs de segurança + erro continuam funcionando
4. **Performance:** Sem degradação vs MVP atual
5. **ISO 27001:** Cada fase auditada antes de integração

---

## Dependencies & Parallelization

```
Fase 10 (Router + Context) 
    ├─→ Fase 11 (ORM + Auto-CRUD)
    │   ├─→ Fase 12 (File Upload) [parallelizable com Fase 11]
    │   └─→ Fase 13 (Error + Grouping)
    │       └─→ Fase 14 (Validation + Security)
    └─→ Testes contínuos + audit ISO 27001
```

**Possível paralelização:** Fases 11 + 12 podem iniciar em paralelo após Fase 10, mas Fase 13 + 14 devem aguardar Fases 11 + 12.

---

## Próximas Ações Imediatas (Sprint 0)

- [x] Iniciar implementação Fase 11 (dataware.lua + query_builder.lua + auto_crud.lua)
- [x] Definir schema DSL e contrato mínimo de Model Registry
- [x] Criar testes estruturais para QueryBuilder e Auto-CRUD
- [x] Documentar migration guide FS → Router explícito (release note da Fase 10)
- [x] Audit ISO 27001 para Fase 11 antes de merge (`history/PHASE11_ISO27001_VALIDATION.md`)

**Status Sprint 0:** ✅ Concluída.
