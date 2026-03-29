# PHASE 11 ISO 27001 Validation

## Scope
Fase 11 introduziu a camada REST Dataware no Nika com:
- registry de modelos e schema DSL
- query builder fluente
- gerador Auto-CRUD
- isolamento de tenancy
- trilha de auditoria de operacoes CRUD

Objetivo da validacao: verificar aderencia pratica ao desenvolvimento seguro (familia A.14, com rastreabilidade para controles operacionais correlatos).

## Artefatos auditados
- `src/dataware.lua`
- `src/query_builder.lua`
- `src/auto_crud.lua`
- `src/dataware_tenancy.lua`
- `src/dataware_audit.lua`
- `src/db.lua`

## Controles e decisoes de seguranca

### 1. Prevencao de SQL Injection
- Prepared statements obrigatorios via wrapper `db`.
- Bloqueio de SQL concatenado com input de usuario.
- Validacao de placeholders e parametros posicionais.

Risco mitigado:
- injecao SQL em filtros e mutacoes CRUD.

### 2. Isolamento de tenant
- Enforcement de `tenant_id` na camada de query/CRUD quando habilitado.
- Falhas de tenant geram evento de seguranca auditavel.

Risco mitigado:
- leitura/escrita cross-tenant por erro de handler.

### 3. Auditoria de eventos
- Operacoes relevantes de CRUD sao registradas para trilha forense.
- Mensagens de erro para cliente nao vazam internals do banco.

Risco mitigado:
- baixa rastreabilidade em incidentes e vazamento de detalhes internos.

### 4. Contrato de erro previsivel
- Falhas de banco mapeadas para codigos internos padronizados.
- Camada HTTP mantem payload consistente para cliente e permite retry controlado.

Risco mitigado:
- ambiguidade de tratamento de erro no cliente e retry inseguro.

## Evidencias de teste
- `tests/query_builder_spec.lua`
- `tests/auto_crud_spec.lua`
- `tests/dataware_spec.lua`
- `tests/dataware_tenancy_spec.lua`
- `tests/dataware_audit_spec.lua`
- `tests/security_regression_spec.lua`

Resultado esperado e validado no ciclo:
- suite de testes completa verde no runner local.

## Riscos residuais aceitos
1. Uso incorreto de schema por integradores (fora do core) pode gerar inconsistencias de negocio.
2. Politicas de rate-limit e CSRF vivem em fase posterior; devem ser aplicadas em rotas expostas.
3. Driver de banco customizado por terceiros precisa respeitar o contrato do wrapper `db`.

## Recomendacoes operacionais
- habilitar logs de auditoria em ambientes de producao.
- revisar periodicamente politicas de tenancy por endpoint.
- manter testes de nao regressao de query builder e auto-crud em pipeline obrigatorio.

## Conclusao
Status: APROVADO.

A implementacao da Fase 11 atende os requisitos de desenvolvimento seguro aplicaveis ao escopo REST Dataware, com controles objetivos para SQLi, segregacao de tenant, auditoria de eventos e tratamento seguro de erro.
