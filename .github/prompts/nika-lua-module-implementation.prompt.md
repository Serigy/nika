---
name: "Nika Lua Module Implementation"
description: "Implementa módulos Lua no Nika com foco em contrato req/res, simplicidade, segurança e auditabilidade sem dependências externas."
argument-hint: "Informe nome do módulo e contexto/assinatura aprovada para implementação."
agent: "Nika Principal Lua Developer"
---

@Nika Principal Lua Developer

**Tarefa:** Implementar o módulo {{nome_do_modulo}}.

**Contexto:**
{{contexto_implementacao}}

Gere o código Lua respeitando estritamente as regras do Nika:
1. O fluxo deve seguir o contrato agnóstico (se for handler, receber req e retornar res).
2. Utilizar table.concat para manipulação massiva de strings.
3. Não utilizar dependências externas (apenas standard library do Lua).
4. Aplicar pcall em áreas de risco e injetar logs (nika_audit.log_error / nika_audit.log_security) em falha de validação ou erro de sistema.

Template Safety Parity (Go-inspired, por fases):
5. Manter sintaxe ASP do Nika (`<% %>`, `<%= %>`). Não migrar para `{{ }}`.
6. Buscar equivalência comportamental progressiva com `html/template` e `text/template` do Go:
- Fase atual: escape obrigatório em toda saída dinâmica de HTML.
- Fase seguinte: separar estratégia por contexto (HTML text, atributo, URL, JS, CSS) sem perder simplicidade.
7. Se implementar ou alterar parser/renderização de template, incluir validação com payloads de injeção (ex.: `\"><img src=x onerror=alert(1)>`, `</script><script>alert(1)</script>`).
8. Se não for possível garantir segurança de contexto na mudança proposta, bloquear a implementação e sugerir caminho mínimo seguro.

Formato obrigatório da resposta:
1. Código Lua completo.
2. Justificativa de segurança curta (XSS, SQLi, isolamento e tratamento de erros quando aplicável).
3. Status de aderência Go-inspired (`BASELINE`, `PARCIAL`, `BLOQUEADO`) com 1 linha de justificativa.

Restrições:
- Evitar over-engineering e abstrações desnecessárias.
- Preservar legibilidade e auditabilidade.
- Se faltar contexto crítico para implementação segura, assumir defaults mínimos e sinalizar no comentário TODO dentro do código.
- Não alegar paridade 1:1 imediata com Go templates sem implementação comprovada de escaping por contexto.

Referências:
1. https://pkg.go.dev/html/template
2. https://pkg.go.dev/text/template
