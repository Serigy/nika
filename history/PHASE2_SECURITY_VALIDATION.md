# Fase 2 - Validacao de Seguranca (Parser e Sandbox)

## Escopo analisado
- Parser de templates: `parser.lua`
- Motor de sandbox: `sandbox.lua`

## Resultado
- Status: APROVADO COM RISCO RESIDUAL BAIXO

## Evidencias objetivas de conformidade
1. Mitigacao de XSS no output dinamico
- O parser converte `<%= expr %>` para `write(escape(expr))`.
- Isso garante output encoding por padrao no ponto de renderizacao dinamica.

2. Mitigacao de SSTI por literalizacao segura
- Trechos HTML literais sao emitidos com `string.format("%q", literal)`.
- Entrada maliciosa em HTML vira string literal Lua, sem virar codigo executavel.

3. Sandbox restrito
- O motor carrega template com ambiente controlado (`load(..., env)` ou `setfenv`).
- Simbolos perigosos (`_G`, `require`, `os`, `io`, `package`, `debug`) nao sao expostos.
- Acesso fora da allow-list gera erro e log interno.

4. Resiliencia e nao exposicao de detalhes
- Falhas de carga ou execucao de template retornam erro generico ao usuario.
- Erros tecnicos sao registrados via `nika_audit.log_error` quando disponivel.

## Casos de validacao (pentest estatico)
1. Payload de XSS refletido em expressao
- Entrada: `<p><%= Request.query.nome %></p>`
- Compilado esperado: `write(escape(Request.query.nome))`
- Resultado: APROVADO

2. Tentativa de injecao via bloco literal com aspas e fechamento de tag
- Entrada: `<p>\"</p><% os.execute('id') %>` em bloco literal HTML
- Com `%q`, o trecho literal vira string escapada, sem execucao implicita.
- Resultado: APROVADO

3. Tentativa de escape de sandbox
- Codigo de template tentando usar `os.execute`/`require`.
- Ambiente sandbox nao expoe esses simbolos; acesso e negado.
- Resultado: APROVADO

## Lacunas e risco residual
1. Politica de allow-list por modulo
- Atualmente, a allow-list adicional vem por `opts.api`.
- Mitigacao recomendada: padronizar lista por fase (MVP) e revisar por code review.

2. Cobertura de testes automatizados
- A validacao acima e estatico-funcional.
- Mitigacao recomendada: adicionar suite de testes com payloads regressivos na fase de integracao.

## Conclusao de auditoria
- O parser e o sandbox atendem os objetivos de seguranca da Fase 2 para prevencao de XSS/SSTI no modelo Nika, mantendo simplicidade, auditabilidade e compatibilidade com Lua 5.1/5.2+.
