# Fase 4 - Auditoria SQL Injection (db.lua)

## Escopo analisado
- Wrapper de banco: `db.lua`

## Resultado
- Status: APROVADO COM RISCO RESIDUAL BAIXO

## Evidencias objetivas de conformidade
1. Prepared Statements obrigatorios
- O wrapper aceita apenas SQL com placeholder `?`.
- Query sem placeholder e bloqueada com `invalid_query`.

2. Politica de parametros estrita
- Parametros devem vir em array denso (ordem posicional confiavel).
- Contagem de placeholders deve bater exatamente com quantidade de parametros.
- Tipos permitidos: `nil`, `boolean`, `number`, `string`.

3. Bloqueio de padroes inseguros
- Multi-statement com `;` e bloqueado para reduzir superficie de injecao.
- Queries fora da politica sao registradas em `nika_audit.log_security`.

4. Falhas de driver sem vazamento
- Erros de runtime do driver sao tratados com `pcall`.
- Falhas sao registradas via `nika_audit.log_error` e retornam erro seguro.

## Casos de validacao (pentest estatico)
1. Query concatenada sem placeholder
- Exemplo: `"SELECT * FROM users WHERE id = " .. user_id`
- Resultado no wrapper: bloqueado por `placeholders_required`.

2. Mismatch de placeholders
- Exemplo: SQL com dois `?` e apenas um parametro.
- Resultado: bloqueado por `placeholder_param_mismatch`.

3. Tentativa de multi-statement
- Exemplo: `SELECT ... ?; DROP TABLE users`
- Resultado: bloqueado por `multi_statement_not_allowed`.

4. Tipo de parametro nao suportado
- Exemplo: parametro `table`/`function`.
- Resultado: bloqueado por `invalid_param_type`.

## Lacunas e risco residual
1. Sem parser SQL completo
- A validacao e intencionalmente minimalista e nao parseia dialetos inteiros.
- Mitigacao recomendada: manter regra de placeholders obrigatorios e code review de queries criticas.

2. Dependencia do driver para semantica final
- O wrapper impõe contrato seguro, mas a execucao final depende do driver usado.
- Mitigacao recomendada: homologar driver por teste de integracao com vetores de SQLi.

## Conclusao de auditoria
- O `db.lua` atende a exigencia da Fase 4 para rejeitar query dinamica e aceitar apenas consulta parametrizada com valores posicionais, reduzindo efetivamente o risco de SQL Injection no MVP.
