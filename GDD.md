# GDD — Poke-HTMX: Jornada Bazaar + Ginásios

> Síntese de `poke-htmx/` (README, PRODUCT.md, DESIGN.md, STACK.md, REQUIREMENTS.md), `draft-futuro.md` e `reviews/*.md` (2026-09-13). Documento de design — sem código, sem alteração de arquivos existentes.

## 1. Visão
Auto-battler server-rendered (Sinatra + htmx, **sem JS próprio**) evolui do circuito fechado atual — `montar 6 → batalha 6v6 por rodadas → XP + moedas → Center/Mart → repete` — para uma **jornada estilo The Bazaar**: runs PvE com escolha de próximo oponente (fraco/médio/forte), chefes de ginásio temáticos como gates, lojas segmentadas entre combates, e PvP assíncrono (fantasma de times reais) no endgame. Cada ciclo continua legível ("entendo por que venci/perdi") e testável em fatias verticais finas.

## 2. Pilares
1. **Legível antes de profundo** — determinismo atual (melhor golpe por dano esperado, tipos ×2/×0.5/×0, STAB ×1.5, ordem por Speed, PP→Struggle) permanece; novidades explicam-se em 1 linha no log.
2. **Uma decisão por tela** — cada tela nova oferece 1 escolha significativa (oponente, loja, slot, item) e 1 CTA primário; nada de gerenciadores multi-tarefa.
3. **Server-render + CSS-only juice** — ERB/htmx + `DESIGN.md` tokens; animações via keyframes com `prefers-reduced-motion` off; sem libs de componente.
4. **Derrota ensina e paga pouco** — perder ainda progride (XP), mas moedas passam a escalar por dificuldade/streak (hoje lose 40/draw 50/win 100 é flat — ver §8).

## 3. Fantasia e audiência
Jogador casual desktop/mobile + dev que roda `./scripts/run`. Fantasia: "meu time fica mais forte e mais rico a cada luta, meu nome sobe no rank do ginásio". Voz pt-BR curta e lúdica, números sempre com unidade (HP, XP, ¥).

## 4. Loop futuro (Bazaar-like)
```
Onboarding (nome+avatar) → montar time (1 inicial ou pré-montado) → [escolher oponente: fraco/médio/forte → batalha resolve → recompensa (XP+moedas+drop)] × N → loja (1 de 3 segmentadas) → chefe de ginásio (gate temático) → próximo ginásio / PvP fantasma → rank
```
- **Core inegociável:** batalha → recompensa → reparo → próxima batalha. Setup (montar 6, filtros, gerenciar golpes) é suporte, não core — não alongar tempo-entre-batalhas além de ~2 navegações.
- **Fix mínimo já mapeado (reviews/loop-core):** botão primário **"Resolver batalha"** (loop de `play_round` até `finished?`, sem mudar domínio) + "Jogar rodada" como secundário; log vira replay com stagger `--log-delay`.
- **Escolha de oponente:** 3 cartas (fraco/médio/forte) com preview honesto (banda por nível médio do time, espécies filtradas por banda — fim do sorteio puro; oponente sempre re-rolado por confronto, nunca seed fixa por usuário).
- **PvP assíncrono:** fantasma = snapshot de time real (6 + moves + hold) + IA mesma do PvE; rank local/global já existe via `GET /history`, estender com temporada por ginásio.

## 5. Telas novas (uma fatia por tela)
1. **Onboarding** — nome + avatar (escolha entre N sprites, CSS-only). ~~Persiste em `user_state`~~ *(a tabela `user_state` foi removida na sessão 0089, 2026-09-16 — o onboarding precisa de um novo lar de persistência, a definir no refinamento; ver `docs/draft-backlog.md:344`)*. Empty-state modelo: copy convidativa + CTA único.
2. **Montagem de time** — duas vias: (a) escolher 1 a 1 do catálogo, (b) pegar time fechado (3 pré-montados por arquétipo: fogo/água/grama). Debate em aberto (decidir em sessão): começar com **1** e capturar/comprar o resto no caminho vs. manter 6 iniciais — GDD recomenda: **começar com 1 + 2 capturas/compras garantidas até o 1º ginásio**, teto segue 6.
3. **Escolha de oponente (PvE)** — 3 cartas forte/médio/forte com risco↔recompensa explícitos (moedas/XP escalam; derrota p/ fraco paga XP-only).
4. **Ginásio temático** — tela por líder (tipo dominante, cor via `--t-*`, arena 3col→1). Intro de chefe (banner + stagger, sem JS).
5. **Seleção de lojas** — após N vitórias, escolher 1 de 3 portas: **Pedras / Poções / Equips** (segmentação do draft). Oferta determinística 3/rodada (padrão atual das pedras: `hash(user_id)+battle_count`).
6. **Pós-batalha unificada** — recompensa + cura rápida inline (custo por membro visível, "curar tudo" 1 clique) — mata o "pedágio do Center" apontado nos reviews.

## 6. Batalha: posicionamento × time × estratégia
Hoje os 3 não conversam (alvo = primeiro vivo por slot). Proposta em camadas, cada uma 1 fatia:
- **L0 (atual):** slot = ordem de entrada; ▲/▼ já existe.
- **L1 — slots pesam:** linha de frente (slots 1-2) recebe/aplica +10%? Não: mais legível — **slot define ordem de entrada, nada mais**; documentar no log ("X entrou na posição 2").
- **L2 — sinergia simples:** bônus por par adjacente do mesmo tipo (+5% dano, texto no log) ou proteção (resistência +1 estágio se vizinho do tipo defensivo). Uma regra só por temporada, nunca stack invisível.
- **L3 (futuro) — IVs/EVs light:** IV = 0-31 rolado na captura (fixo, exibe 1 estrela se ≥28); EV = +1 no stat da categoria do oponente derrotado, cap 50/stat. Sem telas novas: só chips no detalhe. Fora do MVP.

## 7. Itens revitalizados (o ponto fraco atual)
Diagnóstico: poções entram sozinhas abaixo do limiar mas sem decisão; holds (choice-band/scarf) são invisíveis; pedras presas a 3/rodada.
- **Papéis claros:** Poção = decisão (escolher quem curar, 1 uso/batalha, slot de consumível visível); Hold = build (1 por membro, ícone + tooltip de stat); Pedra = evolução (loja própria, preço fixo 80, uso no Center).
- **Economia:** derrota = XP-only (sem moedas) vs. vitória escala por banda; streak +10%/vitória até +50%. Exige sessão SDD de economia — não hotfixar `RewardRule` fora de sessão.
- **Anti-perda:** remover membro devolve holds ao estoque (já resolvido sessão 0052 — manter invariante); fainted não remove sem curar (0064 — manter, mas exibir custo inline).

## 8. Lojas segmentadas
| Loja | Vende | Regra |
|---|---|---|
| Pedras | 6 clássicas | 3/rodada determinísticas, ¥80 fixo |
| Poções | cura/batalha | 1 tipo novo: Revive-½ (traz fainted a 50%) |
| Equips | holds | 1 por membro, swap devolve ao estoque |
Vitória desbloqueia 1 visita; escolher a porta = a decisão. Preço dinâmico e persistência de rotação ficam fora do MVP.

## 9. Animações (CSS-only, refs do draft)
Golpes (projétil `.shot` ≥900px + flash + número de dano), intro de chefe (banner overshoot `cubic-bezier` + stagger), cura no Center (wash verde + HP settle), evolução (flash branco + escala). Refs: blend-mode shaders, sprite-sheet `steps()`, Josh Comeau sprites. Restrições: durações 0.3–0.5s, projétil só desktop, `prefers-reduced-motion` desliga tudo, sem shake de arena (só card-local ±1px), sem som (decisão arquitetural — empilhar flash+shake+número+HP). Gaps a fechar em fatias: overshoot pop (banner/toast/número), tiers pequeno/grande/KO por `data-damage`, antecipação do atacante.

## 10. UX obrigatória (vinda dos reviews)
- **Empty-states:** history zero com CTA (montar time/batalhar); catálogo filtro-zero com bloco explícito + "Limpar filtros" primário (não ghost) + esconder paginação no zero; time 0/6 com CTA p/ catálogo + esconder `ul#roster` vazia + corrigir pill "Precisa de cura"; erro genérico vira mapeamento por status (transiente→Retry, 404→Home/Search); mart-venda vazia linka p/ compra; center vazio colapsa custo. Modelo de tom+CTA: tela Game-Over atual.
- **Segurança/tech (não-escopo do GDD, registrar p/ sessões):** `?as=` takeover, `session_secret` commitado, XSS `<%= %>` sem `escape_html`, `array_literal` de moves, TOCTOU de orçamento, loop sem `MAX_ROUNDS`, `Timeout.timeout`, pool `connection_registry`, handler 500→200, SRI do htmx CDN — ver `reviews/audit-baseline-2026-09-13.md`.

## 11. Regras duras herdadas
Sem JS próprio; mobile-first 920/700/600/480/375; a11y (alvos ≥44px, estado nunca só-cor, reduced-motion); tokens só via `DESIGN.md`; TDD red→green→commit, validação pelo usuário (fase 3), S1 (critério→teste) + S2 (tabela por critério) + S3 (ajuste = reabrir critério); migração idempotente; testes sem rede (stubs `PokeApi`).

## 12. Roadmap em fatias (1 tela = 1 sessão SDD)
1. Resolver-batalha (primário) + rodada secundária. 2. Onboarding nome+avatar. 3. Time fechado × 1-a-1 (com decisão 1-vs-6). 4. Escolha de oponente 3 cartas + recompensa escalada. 5. Loja segmentada (3 portas, 1 visita). 6. Ginásio 1 temático + intro. 7. Poção-decisão + Revive-½. 8. Holds visíveis + devolução. 9. Sinergia L2 (1 regra). 10. PvP fantasma + rank por ginásio. 11. Animações: pop-overshoot + tiers. 12. Empty-states (5 slices A–E dos reviews). Fora MVP: IV/EV full, preço dinâmico, CD/deploy.

## Fontes
`poke-htmx/README.md:22-40`, `PRODUCT.md`, `DESIGN.md`, `STACK.md`, `REQUIREMENTS.md` (RF-07/08/11/13/15/17, D2, RewardRule, limitações), `vaults/Projetos/poke-htmx/draft-futuro.md`, `reviews/audit-baseline-2026-09-13.md`, `reviews/loop-core-2026-09-13.md`, `reviews/loop-flow-nano-2026-09-13.md`, `reviews/ui-empty-state-2026-09-13.md`, `reviews/ui-feel-juice-2026-09-13.md`, `reviews/ui-game-feel-2026-09-13.md`, `reviews/ui-micro-team-nano-2026-09-13.md`.
