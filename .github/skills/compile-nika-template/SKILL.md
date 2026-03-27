---
name: compile-nika-template
description: 'Compila conteúdo de template .nika para Lua puro, gerando código otimizado com buffer via table.insert e função write para saída controlada.'
argument-hint: 'Cole o conteúdo completo do arquivo .nika para gerar a versão compilada em Lua.'
user-invocable: true
---

# Compile Nika Template

## O que esta skill produz
- String de código Lua compilado a partir de um template `.nika`.
- Saída otimizada para renderização com buffer (`table.insert`) e concatenação final (`table.concat`).
- Função `write` para escrita controlada no buffer.
- Compatibilidade com sintaxe ASP do Nika e baseline de segurança inspirado em Go templates.

## Quando usar
- Converter templates estáticos/dinâmicos do Nika em Lua puro para execução.
- Pré-compilar templates para reduzir custo em runtime.
- Revisar se a transformação preserva o fluxo do modelo ASP-like (`<% ... %>`, `<%= ... %>`).
- Evoluir comportamento de segurança em direção ao `html/template` e `text/template` (por fases).

## Entrada esperada
- String com o conteúdo integral do arquivo `.nika`.

## Gramática suportada
- Texto literal: emitido como `write("...")`.
- Bloco de código: `<% ... %>`.
- Expressão com saída: `<%= expr %>` (emitida como `write(escape(expr))` no baseline seguro).

## Procedimento
1. Tokenizar o template.
- Separar trechos literais, blocos de código (`<% ... %>`) e blocos de expressão (`<%= ... %>`).

2. Gerar estrutura base do compilado.
- Inicializar `local __buf = {}`.
- Declarar `local function write(v) table.insert(__buf, tostring(v)) end`.

3. Converter cada token.
- Literal: escapar conteúdo e gerar `write("...")`.
- Código (`<% %>`): inserir bloco Lua bruto no fluxo.
- Expressão (`<%= %>`): gerar `write(escape(expr))`.

4. Finalizar chunk compilado.
- Adicionar `return table.concat(__buf)` ao final.
- Garantir ordem e fidelidade dos trechos originais.

5. Aplicar otimizações seguras.
- Mesclar literais adjacentes em um único `write` quando possível.
- Evitar concatenação `..` em loop de renderização.
- Não alterar sintaxe para `{{ }}`; manter semântica ASP do Nika.

## Regras de decisão
- Se houver tag aberta sem fechamento (`<%` sem `%>`): retornar erro de compilação com posição aproximada.
- Se bloco de expressão estiver vazio (`<%= %>`): retornar erro de compilação.
- Se não houver nenhuma tag dinâmica: ainda gerar Lua com `write` + retorno final.
- Nunca gerar saída com escrita direta fora do buffer.

## Critérios de qualidade e conclusão
- Código resultante deve ser Lua válido e executável.
- Toda escrita de saída deve passar por `write`.
- Deve haver `table.insert` no buffer e `table.concat` no retorno.
- A transformação deve preservar a ordem de renderização do template original.
- Saída dinâmica em `<%= %>` deve preservar baseline de escape obrigatório.
- Quando solicitado contexto avançado (JS/URL/CSS), declarar status de aderência (`BASELINE` ou `PARCIAL`) e não prometer paridade 1:1 imediata.

## Formato de saída obrigatório
- Retornar somente uma string com código Lua compilado.
- Não incluir explicações fora do código.

## Exemplo de saída esperada
```lua
local __buf = {}
local function write(v)
    table.insert(__buf, tostring(v))
end

write("<h1>Olá ")
write(Request.nome)
write("</h1>")

return table.concat(__buf)
```

## Restrições
- Não introduzir dependências externas.
- Não executar o template durante compilação.
- Não misturar responsabilidades de sandbox nesta skill; foco exclusivo em compilação.
- Não migrar sintaxe do template para `{{ }}`.
