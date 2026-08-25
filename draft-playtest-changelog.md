# Draft — Changelog de playtest (experiência e melhorias)

> **Fora do fluxo (RNF-04).** Registro cumulativo de sessões de playtest: cada
> sessão anota o que foi testado, a experiência real jogando e as melhorias que
> saíram dela. Não gera critérios de aceite nem plano TDD na hora; revisar ao
> fechar as fases correntes. Jogo é **auto-battler** (decisão do usuário):
> a estratégia vive no pré-combate (moveset, itens, seguráveis), a batalha
> resolve sozinha.

---

## Sessão 1 — 2026-08-25 (playtest via browser-harness)

> Execução: agente navegou o app real em Chrome (CDP) e jogou ~15+ batalhas.
> Time subiu até nível 5; comprou itens no Mart, curou no Center, montou moveset
> (draft + salvar) e equipou itens/seguráveis.

### 1.1 O que foi testado

- Conectividade: `GET /`, `/battle`, `/history` respondendo; `/team` é 404 em
  navegação direta (virou fragmento htmx interno — esperado pós-0042).
- Lista: filtro por nome (htmx), paginação "Próxima", modal de detalhe.
- Loop do time: adicionar Pokémon, gerenciar golpes (draft/marcar/salvar),
  equipar item, equipar segurável, mover slots (▲/▼), remover.
- Mart: compra de poções/seguráveis debita saldo e adiciona ao inventário.
- Center: cura cobra custo proporcional ao HP faltante e debita saldo.
- Batalha: rodadas automáticas, uso automático de item equipado, resultado
  com XP/dinheiro, "Novo confronto".

### 1.2 Experiência (o que o jogador sente)

- **O loop base funciona e é legível**: batalhar → XP + dinheiro → curar/comprar
  → batalhar de novo. Feedback imediato no fim ("ganhou 50 XP e 100 de dinheiro").
- **A batalha é 100% automática** (auto-battler confirmado): o jogador só clica
  "Jogar". A estratégia real está em montar o moveset e equipar itens/seguráveis
  antes. Isso **não é comunicado ao jogador** — a UI parece que vai pedir uma
  decisão a cada turno, e nunca pede.
- **Dificuldade não escala**: oponentes sempre nível 1; só o pool de espécies
  varia (bunnelby → delibird → meditite…). Com time nível 5 + cura, o jogo
  vira rotina; não há incentivo a continuar além do lvl ~4–5.
- **Perder ainda recompensa** (20 XP / 40 dinheiro) — bom para não frustrar,
  mas achatado: vitória e derrota são sempre a mesma recompensa fixa, sem bônus
  por rodadas/KOs.
- **Progressão de golpes por nível é o coração do jogo** e funciona
  (vine-whip N3, ember N4, smokescreen N4…). É a única decisão com peso real.

### 1.3 Melhorias anotadas (playtest)

| # | Achado | Impacto | Área |
| --- | --- | --- | --- |
| P1 | **CRÍTICO — vazamento de conexões PG**: cliques rápidos em sequência derrubam o app com `PG::ConnectionBad — too many clients already` (ConnectionRegistry cacheia por `[owner, thread_id]` sem limite/reciclagem) | Impede uso real contínuo | Infra/back |
| P2 | Batalha automática não é comunicada — sem onboarding/ajuda do modelo auto-battler | Expectativa errada do jogador | UX/conteúdo |
| P3 | Oponentes não escalam (sempre lvl 1); falta curva por nível/time | Gameplay estagna | Game design |
| P4 | Recompensa fixa (100/50); sem bônus por performance | Auto-battler sem camada de skill | Game design |
| P5 | Painel do time tem dois modos (home: Center/Mart+cards / "Gerenciar": edição) e **some** saldo/Mart/Center no modo edição; sem caminho de volta claro | Navegação confusa | UX |
| P6 | Status de item/segurável invisível no gerenciar (select mostra "Nenhum" mesmo equipado); info só no battle screen ("carrega:/segura:") | Falta de visibilidade do estado | UX |
| P7 | Sem estado vazio: batalha inicia com time HP 0 (Pokémon lutam "mortos"); sem aviso "cure seu time" | Confuso | UX |
| P8 | Ranking global com seeds competindo no topo ("seed-shop 21 vitórias") | Desmotiva (bot invencível) | Game design |

### 1.4 Acelerar o ciclo de playtest (propostas)

Ideias para reduzir o custo de cada sessão de playtest futura:

- **TP-1 — Playbook reutilizável**: script `browser-harness` com helpers prontos
  (add_team, heal, buy, equip, fight_x_rounds, assert_state) salvos em
  `agent_helpers.py` do harness; cada playtest vira um roteiro curto que
  reaproveita os mesmos passos.
- **TP-2 — Estado determinístico por sessão**: seed/endpoint dev para resetar o
  estado do jogador (saldo, time, inventário) e sortear oponentes fixos — playtest
  sempre começa igual e é reprodutível.
- **TP-3 — Log estruturado da batalha**: além do log textual, expor JSON por
  rodada (ações, dano, PP, itens usados) para análise automatizada (ex.: balanço
  de dificuldade) sem ler tela.
- **TP-4 — Sandbox de balanceamento**: parametrizar XP/dinheiro/dificuldade por
  env (ex.: `PLAYTEST_XP_MULT`, `OPPONENT_LEVEL_FLOOR`) para testar curvas sem
  tocar código.
- **TP-5 — Checagem de robustez antes do playtest**: rodar o jogo com rajadas de
  cliques rápidos (rate de htmx) para pegar vazamentos/500 cedo — evitaria o
  crash da sessão 1 (P1).

---

<!-- registros futuros adicionados abaixo -->