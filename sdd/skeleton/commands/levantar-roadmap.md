---
description: Levanta e consolida o roadmap — vasculha drafts/fontes em busca de ideias surgidas e anota em REQUIREMENTS.md/{{DRAFT_PATH}}. Não inicia sessão.
agent: build
---

Você está executando o **levantamento de roadmap do {{PROJETO}}** em modo
**somente-anotação**. Objetivo: consolidar as ideias/frentes que **surgiram**
(drafts, observações de sessão, requisitos não refinados) e dar ao usuário um
mapa para decidir a próxima sessão. Regras base: `AGENTS.md` (não-abrir-escopo:
nada de novo escopo no meio da sessão corrente). **Não** é início de sessão e
**não** abre novo escopo — apenas anota.

## 1. Levantamento

Se `$ARGUMENTS` trouxer uma ideia, registre-a como **candidata nova**.

Varra as fontes em busca de itens surgidos ainda fora do roadmap:

1. `{{DRAFT_PATH}}` — todas as entradas do draft único.
2. `REQUIREMENTS.md` — seções de limitações/pontos de refinamento, roadmap e
   qualquer requisito não `Done`.
3. `SESSIONS.md` — seção "Próxima sessão" e observações de sessões concluídas.
4. `sessions/*.md` — seções de observações e itens de "próximo passo sugerido".
5. `AGENTS.md` — lições que apontam melhorias futuras.

Para cada candidato, classifique:

| Categoria | Significado |
| --- | --- |
| **Já no roadmap** | Já listado na tabela `Roadmap` do `REQUIREMENTS.md` (mesmo que `Backlog`/`Draft`) |
| **Em draft** | Presente só no `{{DRAFT_PATH}}`, ainda não virou linha do roadmap |
| **Emerge** | Anotado em observações/limitações/sessões e **não** aparece nem no roadmap nem no draft (novo para o fluxo) |
| **Descartável** | Obsoleto, já feito ou sem ação (indique o porquê) |

## 2. Entrega — mapa de candidatos

Apresente um quadro consolidado agrupado pelas categorias acima, com **1–3
linhas por item** (id, título, de onde surgiu, status atual). No final, indique:

- **Provável próxima sessão sugerida** (respeitando a sequência: nada inicia
  antes da sessão corrente estar concluída/validada),
- Ordem sugerida de priorização (dependências) para decisão do usuário,
- Itens emergidos que merecem virar requisito antes dos demais.

## 3. Atualização dos fontes (somente anotar)

Registre as **candidatas novas confirmadas** (as que o usuário mandar manter):

- Em `REQUIREMENTS.md`: na seção de ideias/lista de pontos, mantendo as
  convenções existentes (`[ ]` / anotações). Não crie requisito formal nem linha
  de roadmap ainda — isso é refinamento de fase futura.
- Ideias que são decisões grandes de arquitetura/draft → `{{DRAFT_PATH}}`
  (seção própria), só com a nota de "aguarda sessão".
- Deixe intacto o fluxo: **não** criar `sessions/NNNN-*`, **não** tocar
  `SESSIONS.md` (progresso/next), **não** marcar requisito como `Done`.

Não apague itens existentes — apenas acrescente/atualize anotações. Ao final,
diga explicitamente **o que entrou no roadmap/draft** e o que ficou para o
usuário decidir.

## 4. Próximo passo

Ao concluir, diga: "Ideias consolidadas em `REQUIREMENTS.md`/`{{DRAFT_PATH}}`.
Quando quiser virar sessão, rode `/iniciar-sessao` (ou continue via `/sessao`
se uma estiver em andamento)". Não inicie a sessão nova agora.
