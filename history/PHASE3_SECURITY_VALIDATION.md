# Fase 3 - Validacao de Seguranca (Router e Hooks)

## Escopo analisado
- Roteador minimalista: `router.lua`
- Motor de hooks: `hooks.lua`

## Resultado
- Status: APROVADO COM RISCO RESIDUAL BAIXO

## Evidencias objetivas de conformidade
1. Mitigacao de Path Traversal
- O roteador normaliza e decodifica o path recebido.
- Segmentos `..` sao bloqueados explicitamente.
- NUL byte e padroes invalidos sao rejeitados.
- Em path invalido, ocorre log de seguranca e retorno seguro.

2. Roteamento seguro e previsivel
- Resolucao para arquivo `.nika` com fallback `index.nika`.
- Em recurso inexistente, retorno controlado `404 Not Found` sem vazar detalhes internos.

3. Execucao de hooks com isolamento de falhas
- Hooks executam em sequencia com `pcall`.
- Excecao em hook interrompe fluxo com resposta segura (`500`) e auditoria.

4. Short-circuit seguro
- Se hook retorna `true`, o fluxo e interrompido imediatamente.
- Fallback defensivo para `403`/`401` e corpo controlado quando hook nao preencher resposta.
- Evento de bloqueio e registrado em `nika_audit.log_security`.

5. Integracao de hook nativo de seguranca
- O motor de hooks expoe `register_default_hooks()` para carregar automaticamente `hooks/security_headers.lua` no estagio `after_request`.
- O carregamento e idempotente e auditado em caso de falha.

## Casos de validacao (estatico-funcional)
1. Path traversal por segmento relativo
- Entrada: `/../../etc/passwd`
- Resultado: bloqueado com `invalid_path` e log de seguranca.

2. Path traversal com encoding
- Entrada: `/%2e%2e/%2e%2e/secret`
- Resultado: bloqueado apos decode e normalizacao.

3. Hook de bloqueio
- Hook em `before_request` retorna `true` e define `res.status = 401`.
- Resultado: requisicao interrompida sem seguir para proximas etapas.

4. Hook com falha interna
- Hook dispara erro em runtime.
- Resultado: erro capturado, logado e resposta `500` controlada.

5. Hook nativo de Security Headers
- Registro via `register_default_hooks()`.
- Resultado: headers de seguranca aplicados em `after_request` sem short-circuit do fluxo.

## Lacunas e risco residual
1. Politica de assinatura e autenticidade de hooks externos
- `load_hook_from_file` carrega via `dofile` de caminho informado.
- Mitigacao recomendada: restringir diretorio permitido para hooks em fase de hardening.

2. Politica de permissao de sistema de arquivos
- Risco residual depende de ACL do ambiente de deploy.
- Mitigacao recomendada: permissao somente leitura para templates e hooks em producao.

## Conclusao de auditoria
- Router e motor de hooks atendem os requisitos da Fase 3 para controle de fluxo seguro, bloqueio de traversal e interceptacao confiavel por short-circuit, mantendo o contrato agnostico do framework.
