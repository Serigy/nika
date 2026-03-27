---
name: audit-template-injection
description: 'Analisa código Lua/HTML de templates do Nika para detectar vetores de SSTI e XSS, classificar risco e retornar mitigação objetiva. Use quando precisar auditoria rápida de injeção em template.'
argument-hint: 'Cole o trecho de template ou renderização Lua que deve ser auditado para SSTI/XSS.'
user-invocable: true
---

# Audit Template Injection

## O que esta skill produz
Retorna uma saída estruturada com:
- vulnerable (boolean)
- risk_level (LOW, MEDIUM, HIGH ou CRITICAL)
- mitigation_suggestion (string curta e acionável)
- parity_status (BASELINE, PARCIAL ou BLOQUEADO)

## Quando usar
- Revisão de trechos Lua/HTML do Nika com renderização dinâmica.
- Dúvidas sobre escape HTML, sandbox de template e execução de código em template.
- Triagem rápida de risco de SSTI ou XSS antes de merge.
- Avaliar lacunas entre baseline atual do Nika e comportamento esperado de `html/template`/`text/template` do Go.

## Entrada esperada
- String com código fonte do template, do compilador de template ou do ponto de renderização.

## Procedimento
1. Classificar o trecho recebido.
- Template misto (marcação com blocos de script), HTML puro com interpolação, ou Lua de renderização.

2. Procurar superfícies de ataque de XSS.
- Interpolação dinâmica sem escape.
- Uso de escrita direta em resposta sem codificação contextual.
- Uso de dados de request/query/body em saída HTML sem sanitização.

2.1. Mapear contexto de saída (Go-inspired).
- HTML texto
- atributo HTML
- URL
- JavaScript
- CSS
- Se contexto avançado for detectado sem escaping específico, elevar risco e marcar lacuna de paridade.

3. Procurar superfícies de ataque de SSTI.
- Execução dinâmica com load/loadstring/string.dump sem ambiente restrito.
- Ambiente de template com acesso a _G, require, io, os, debug ou funções perigosas.
- Concatenação de entrada do usuário em código compilado de template.

4. Avaliar explorabilidade.
- Verificar se há caminho plausível de dados externos até sink de execução/renderização.
- Se houver controle parcial do atacante + sink executável, elevar risco.

5. Definir risco e mitigação mínima.
- LOW: padrão inseguro sem caminho claro de exploração.
- MEDIUM: falta de defesa em ponto relevante, exploração condicionada.
- HIGH: caminho prático para XSS persistente/refletido ou SSTI parcial.
- CRITICAL: execução arbitrária no servidor, escape de sandbox ou cadeia de RCE.

6. Definir status de aderência Go-inspired.
- BASELINE: escape obrigatório em saída dinâmica e sandbox consistente.
- PARCIAL: há controles básicos, mas faltam escapes por contexto.
- BLOQUEADO: há risco ativo (XSS/SSTI) ou promessa de paridade sem controle técnico.

## Regras de decisão
- Se qualquer interpolação dinâmica em HTML não usar escape contextual: vulnerable = true.
- Se template puder acessar globais sensíveis ou funções de sistema: vulnerable = true.
- Se load/loadstring executar conteúdo derivado de input sem sandbox estrita: vulnerable = true.
- Se não houver evidência de risco real após checagem dos sinks: vulnerable = false e mitigation_suggestion com hardening preventivo.

## Critérios de qualidade e conclusão
- A análise deve citar pelo menos um ponto técnico observado no trecho.
- A saída deve ser somente um objeto JSON válido.
- mitigation_suggestion deve propor correção mínima alinhada ao Nika (simplicidade, allow-list, escape obrigatório, sandbox estrita).
- A saída deve indicar `parity_status` sem alegar paridade 1:1 imediata sem evidência.

## Formato de saída obrigatório
```json
{
  "vulnerable": true,
  "risk_level": "HIGH",
  "mitigation_suggestion": "Aplique escape HTML em toda interpolação dinâmica e execute templates em ambiente allow-list sem acesso a _G, io, os e require.",
  "parity_status": "PARCIAL"
}
```

## Restrições
- Não sugerir dependências externas sem necessidade clara.
- Não ampliar escopo para auditoria geral de arquitetura: foco exclusivo em SSTI/XSS de template.
- Priorizar correções mínimas e auditáveis.
