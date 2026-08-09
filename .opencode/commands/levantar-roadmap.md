---
description: Levanta e atualiza o roadmap — vasculha drafts/fontes em busca de ideias que surgiram e consolida no `REQUIREMENTS.md`; também aceita uma ideia nova por argumento. Não inicia sessão (RNF-04).
---

Você está executando o **levantamento de roadmap do Poke-HTMX**. Objetivo: consolidar
todas as ideias/frentes que **surgiram** (em drafts, observações de sessão e
requisitos não refinados) e dar ao usuário um mapa para decidir a próxima sessão.
**Não** é início de sessão e **não** abre novo escopo — apenas anota (RNF-04).

## 1. Levantamento

Se o usuário digitou uma ideia (via `$ARGUMENTS`), registre-a como **candidata nova**.

Varra as fontes em busca de itens que surgiram e ainda não estão no roadmap:

1. `draft-auto-battler.md` — todas as entradas (A, B, C, D, refatorações, notas RNG).
2. `REQUIREMENTS.md` — seções "Limitações Conhecidas / Pontos de Refinamento",
   "Ideias de auto-battler", "Roadmap", e qualquer requisito `Draft`/não `Done`.
3. `SESSIONS.md` — seções "Próxima sessão" e observações de sessões concluídas.
4. `sessions/*.md` — seções **6. Observações** e itens "próximo passo sugerido".
5. `AGENTS.md` — notas de lições que apontam melhorias futuras.

Para cada candidato, classifique:

| Categoria | Significado |
| --- | --- |
| **Já no roadmap** | Já listado na tabela `Roadmap` do `REQUIREMENTS.md` (mesmo que `Backlog`/`Draft`) |
| **Em draft** | Presente só no `draft-auto-battler.md`, ainda não virou linha do roadmap |
| **Emerge** | Anotado em observações/limitações/sessões e **não** aparece nem no roadmap nem no draft (novo para o fluxo) |
| **Descartável** | Obsoleto, já feito, ou sem ação (indique o porquê) |

## 2. Entrega — mapa de candidatos

Apresente ao usuário um quadro consolidado, agrupado pelas categorias acima, com
**1–3 linhas por item** (id, título, de onde surgiu, status atual). No final, indique:

- **Provável próxima sessão sugerida** (respeitando sequência rígida: nada inicia antes
  da sessão corrente ser concluída/validada),
- Ordem sugerida de priorização (dependências) para a decisão do usuário.
- itens Emergidos que merecem virar requisito antes dos demais.

## 3. Atualização dos fontes (somente anotar)

Registre as **candidatas novas confirmadas** (as que o usuário disser para manter):

- Em `REQUIREMENTS.md`: na seção "Ideias de auto-battler" ou Lista de pontos,
  mantendo as convenções existentes (`[ ]` / anotações). Não crie requisito formal
  nem linha de roadmap ainda — isso é refinamento de fase futura (RNF-04).
- Ideias que são decisões grandes de arquitetura/draft → `draft-auto-battler.md`
  (seção própria), somente com a nota de "aguarda sessão".
- Deixe intacto o fluxo: **não** criar `sessions/NNNN-*`, **não** tocar em
  `SESSIONS.md` (progresso/next), **não** marcar requisito como `Done`.

Não apague itens existentes — apenas acrescente/atualize anotações. Ao final, diga
explicitamente **o que entrou no roadmap/draft** e o que ficou para o usuário decidir.

## 4. Próximo passo

Ao concluir, diga: "Ideias consolidadas em `REQUIREMENTS.md`/`draft-auto-battler.md`.
Quando quiser virar sessão, rode `/iniciar-sessao` (ou continue a sessão corrente se
uma estiver em andamento)". Não inicie a sessão nova agora.