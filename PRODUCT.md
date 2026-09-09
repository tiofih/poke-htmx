# PRODUCT.md — verdade durável do produto (Poke-HTMX)

Fonte canônica de audiência, propósito, contexto de uso e voz. Skills de design
(`impeccable`, `stark`, `critique`) e o `refinador` leem este arquivo antes de
propor qualquer superfície nova. Tokens visuais vivem em `DESIGN.md`.

## O que é

Jogo web de montar time Pokémon (máx. 6), batalhar por turnos, progredir
(XP/nível/evolução), gerenciar economia (orçamento, Mart, Heal) e acompanhar
jornada/histórico — tudo numa página única servida por Sinatra + HTMX,
**sem JavaScript próprio** (interações via `hx-get/post/delete` + CSS-only:
`:target` modais, keyframes juice, `prefers-reduced-motion`).

## Audiência

Jogador casual de navegador desktop e mobile; desenvolvedor que abre o repo e
roda `./scripts/run`. Sessão anônima (`session[:user_id]`), sem contas.

## Propósito por superfície

| Superfície | Propósito | Medida de pronto |
|---|---|---|
| Lista/catálogo (`#pokemon`) | achar e adicionar Pokémon rápido, com filtros | add em ≤2 toques, toast confirma |
| Time (`#team`) | ver os 6, HP, nível, prontidão | estado do time legível de relance |
| Batalha | turnos legíveis, log rodada a rodada, recompensa clara | jogador entende por que venceu/perdeu |
| Jornada/mart/heal/history | progressão e economia persistidas | números batem com `RewardRule`/`ExperienceCurve` |

## Voz (pt-BR, sem exigir acento em commit)

Microcopy curta, lúdica sem infantilizar. Erros dizem o que aconteceu e o
próximo passo ("Time cheio (máx. 6)." não "Erro 422"). Números sempre com
unidade (HP, XP, ¥/moedas).

## Restrições duras (não negociar sem sessão SDD)

- Sem JS próprio; sem libs de componente (é o ponytail FULL aplicado a UI).
- Mobile-first real: breakpoints 920/700/600/480/375 já cobertos no CSS.
- Acessibilidade: `prefers-reduced-motion` desliga todo juice; alvos ≥44px;
  estados (ok/mid/low, win/loss/draw) nunca só por cor — sempre com texto.
- Tokens novos só via `DESIGN.md`; nada hardcoded fora de `--var`.
