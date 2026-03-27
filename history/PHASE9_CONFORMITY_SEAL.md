# Fase 9.3 - Selo de Conformidade Comportamental

## Escopo do selo
Este selo cobre a engine de templates do Nika no estado atual do repositorio, com sintaxe ASP (`<% %>`, `<%= %>`), incluindo:
- selecao deterministica de contexto
- escaping por contexto em modo `html`
- modo explicito `text`
- registry de funcoes (allow-list)
- parciais/blocos reutilizaveis (`include`, `partial`)
- hardening de sandbox e controles de erro seguro

## Resumo executivo
- Resultado: APROVADO
- Tipo de aprovacao: 1:1 comportamental por contrato de seguranca + diferencas conhecidas formalizadas
- Data de validacao: 2026-03-27

## Evidencias principais
1. Suite de equivalencia (9.1): `tests/template_equivalence_spec.lua`
2. Pentest final (9.2): `tests/template_pentest_final_spec.lua`
3. Regressao de seguranca: `tests/security_regression_spec.lua`
4. Determinismo de contexto: `tests/determinism_spec.lua`
5. Modo text/template: `tests/template_text_mode_spec.lua`
6. Registry de funcoes: `tests/template_functions_registry_spec.lua`
7. Parciais reutilizaveis: `tests/template_partials_spec.lua`
8. Matriz de contexto: `docs/TEMPLATE_CONTEXT_MATRIX.md`
9. Determinismo documentado: `docs/CONTEXT_SELECTION_DETERMINISM.md`

## Checklist de conformidade final
1. HTML_TEXT com auto-escape em modo `html`: PASS
2. HTML_ATTR_QUOTED com escape de atributo: PASS
3. URL_ATTR com bloqueio de esquemas inseguros: PASS
4. JS_STRING e CSS_STRING em modo `html` (hardening por bloqueio): PASS
5. Modo `text` explicito sem auto-escape implicito: PASS
6. Selecao de contexto reproduzivel em multiplas compilacoes: PASS
7. SSTI mitigado por sandbox (`_G`, `require`, `os`, `io`): PASS
8. Evasao por registry de funcoes reservadas: PASS
9. Abuso de parciais (ausente/recursao): PASS
10. Nao-vazamento de detalhes internos ao usuario final: PASS
11. Registro de eventos de seguranca em bloqueios: PASS
12. Sem dependencia externa adicionada no core: PASS
13. Contrato req/res agnostico preservado: PASS

## Diferencas conhecidas e justificadas
As diferencas abaixo estao formalizadas e cobertas em teste como decisao de hardening:
1. Em modo `html`, `JS_STRING` nao tenta escapar para executar; bloqueia com erro seguro.
2. Em modo `html`, `CSS_STRING` nao tenta escapar para executar; bloqueia com erro seguro.
3. Em modo `html`, URL perigosa (`javascript:`, `data:`) bloqueia com erro seguro.

Justificativa:
- Preferencia por seguranca deterministica e auditavel sobre conveniencia.
- Comportamento explicito e repetivel por contrato de teste.

## Criterios de aceite da fase 9.3
1. Documento de selo publicado em `docs/`: OK
2. Diferencas conhecidas documentadas com justificativa: OK
3. Evidencias tecnicas e suites referenciadas: OK
4. Decisao final explicitada: OK

## Decisao final
Selo de conformidade comportamental emitido para o estado atual da engine de templates.

Status final: APROVADO PARA OPERACAO
