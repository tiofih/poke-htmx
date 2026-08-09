# Sessão 0015 — Golpes (moves) e PP (D1, RF-15)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-09 |
| Implementação | Em andamento — plano TDD da seção 5 |
| Validação | Pendente — executada pelo usuário |

---

## 1. Objetivo

Dar **multi-move** à simulação de batalha (D1 do `draft-auto-battler.md`, roadmap
item 15): em vez de cada ataque ser apenas o "melhor tipo do atacante" (B3), cada
`BattlePokemon` passa a ter uma **lista de golpes** (nome, tipo, poder, precisão,
PP). O `BattleEngine` **escolhe deterministicamente** qual golpe usar (maior dano
esperado), aplica o **poder do golpe** no cálculo de dano, **decai o PP** a cada uso
e, quando todos os golpes estão com PP zerado (ou não há golpes utilizáveis), entra
em **Struggle** (dano fixo baixo, tipo do atacante, sem PP). Sem RNG — a escolha
continua determinística e testável (nota RNG do draft fica anotada para iteração
futura). A batalha web (C1/RF-13) passa a **carregar os golpes** de cada Pokémon
(jogador e oponente) e exibi-los: log mostra o golpe usado e cada painel mostra os
golpes do fighter com o PP restante.

Esta sessão **revisita B3** (motor) e **toca C1** (battle.erb + `GET /battle`) — mas
**sem regressão**: `BattlePokemon` sem `moves` (tests de B3) mantém o caminho legado
(o ataque por melhor tipo com dano `A−D` e mesmo formato de log), garantindo 0
regressão nas suítes 0011/0013/0014.

## 2. Contexto (estado atual)

- `BattleEngine` (B3/0011): `act` escolhe `move_type_for` = melhor tipo do atacante
  contra o alvo; dano = `max(1, A−D)` × multiplicador (efetividade × STAB, melhor tipo
  imune → neutro); log por ação = `{round, attacker, move_type, damage, ko}`.
- `BattlePokemon` (B1/0009): Dry::Struct `number/name/sprite/types/stats/hp_max/hp_current`;
  `from(pokemon)` funcional e `take_damage` imutável. **Sem golpes hoje.**
- `PokeApi.detail(poke_id)` já busca stats/typhes/evoluções; a PokéAPI expõe os golpes
  em `GET /pokemon/:id` → `moves[]` (nome + URL do `/move/:name`). Sem cache de moves.
- `OpponentGenerator` (B4/0012): `team` monta `[BattlePokemon]` via `fetcher`
  (default `PokeApi.detail`) — **sem golpes**.
- `GET /battle` (C1/0013): `BattlePokemon.from(PokeApi.detail(member.number))` e
  `OpponentGenerator.new(names:).team` → engine → `battle.erb`; `battle.erb` mostra
  HP por fighter, log do último round (`move_type`, dano, KO) e vencedor.
- `PokeApiStub` (test_helper) tem `with_find`, `with_detail`, `with_all_names`,
  `with_type` — falta stub para moves.
- RNF-04: TDD (red → green → commit), suíte via `./scripts/test`, lint `./scripts/lint`.

## 3. Critérios de aceite

### Modelo de golpe (D1 — domínio puro, sem rede)

- [ ] `lib/move.rb`: `Move < Dry::Struct` com `name`, `type`, `power` (Integer ou nil —
      golpes de status), `accuracy` (Integer ou nil) e `pp` (Integer).
- [ ] `BattlePokemon` ganha a attribute `moves` (`Array.of(Move)`, default `[]` —
      `from(pokemon, moves:)` aceita a lista; sem `moves` → `[]` e caminho legado).

### Fonte dos golpes (PokéAPI, com cache e stub)

- [ ] `PokeApi.move(name)` → `Move` (fetch `GET /move/:name`, memoizado por nome).
- [ ] `PokeApi.moves_for(number)` → até **4 golpes** do Pokémon (via
      `pokemon_data(id)["moves"]`, os **04 últimos** da lista da API), memoizado por
      número; usa `Move` puros.
- [ ] Golpes sem dano (power `nil`/`0`) são carregados como `Move` mas ficam
      **inutilizáveis** pelo motor (não escolhidos para atacar).

### Motor com golpes (B3 revisitada — determinística)

- [ ] `BattleEngine` escolhe o golpe **deterministicamente**: o de **maior dano
      esperado** = `power × effectiveness(move.type) × STAB(move.type)` contra o alvo;
      desempate → maior `power`; empate → primeira posição na lista.
- [ ] Dano do golpe = `max(1, Attack − Defense) × (power / 50) × multiplicador do
      tipo do golpe` (arredondado), mínimo 1; `move_type` no log = tipo do golpe usado.
- [ ] **PP decai em 1** a cada uso (funcional: novo Move com `pp−1` substituído no
      `BattlePokemon`); golpe com `pp == 0` deixa de ser escolhido.
- [ ] Sem golpe utilizável (todos `pp == 0` ou só golpes de status) → **Struggle**:
      dano fixo baixo (`power` = 10), tipo do atacante, **sem custo de PP**, entra no log.
- [ ] Pokémon **sem `moves`** (`[]`) → **caminho legado preservado**: exatamente o
      ataque por melhor tipo de B3 (dano `A−D`, multiplicador, mesma shape de log)
      — suíte 0011 continua verde **sem edição** (0 regressão).
- [ ] Log de ação com golpe usado ganha a chave **`move`** (nome do golpe);
      entries legado continuam com `round/attacker/move_type/damage/ko`.
- [ ] `Accuracy` **não é aplicada** neste escopo (dados preservados no `Move`, uso em
      iteração futura com RNG) — anotado.

### Batalha web (C1) exibe os golpes

- [ ] `GET /battle` carrega os golpes dos dois lados: jogador via `moves_for` por membro;
      oponente via `moves_for` por membro do `OpponentGenerator` (síntese de Struggle
      quando `moves_for` vier vazio → `moves_for` nunca devolve `[]` na rota).
- [ ] `battle.erb`: cada fighter mostra seus golpes com **PP restante** (`move — PP n`);
      log do round mostra o **nome do golpe** usado (+ Struggle quando for o caso).
- [ ] Sem JS customizado (RNF-01); testes de rota sem rede (stubs existentes +
      `PokeApiStub.with_moves_for`/`with_move`).

### Garantias (RNF)

- [ ] Testes **sem rede**; suíte completa verde (`./scripts/test`) e lint 0; commit a
      cada green.
- [ ] 0 regressão: RF-01..RF-14 seguem verdes (0011 em especial, sem editar
      `battle_engine_test.rb`).
- [ ] `REQUIREMENTS.md` (**RF-15 — Golpes/PP (D1)**), `SESSIONS.md` (0015) e
      `draft-auto-battler.md` (D1) atualizados no mesmo escopo.

## 4. Decisões de refinamento (fechadas com o usuário em 2026-08-09)

- **Escolha do golpe: estratégia determinística** (decisão do usuário). O motor
  escolhe o golpe de **maior dano esperado** (`power × efetividade × STAB`); desempate
  por power/ordem. **Sem RNG** neste escopo — a nota RNG do draft (B3) permanece
  anotada para iteração futura (variação de partidas/falhas de golpe).
- **Fallback: Struggle determinístico** (decisão do usuário): quando todos os golpes
  estão com PP zerado (ou não há golpe com dano), o Pokémon usa **Struggle** (dano
  fixo `power: 10`, tipo do atacante, sem PP). Pokémon sem `moves` (tests B3 diretos)
  mantêm o **caminho legado** → 0 regressão na suíte 0011.
- **UI: log + PP no painel** (decisão do usuário): `battle.erb` mostra o nome do golpe
  usado no log e cada fighter exibe a lista de golpes com PP restante. **Sem seletor
  de golpe** (a escolha é do motor, não do jogador).
- **Fonte:** `PokeApi.moves_for(number)` (4 últimos da lista `moves` de
  `GET /pokemon/:id`, memoizado) + `PokeApi.move(name)` (`GET /move/:name`,
  memoizado). Para a rota, se `moves_for` vier vazio a rota sintetiza **Struggle** —
  o motor em produção nunca vê `moves == []`.
- **Fórmula de dano:** `max(1, A−D) × (power/50) × multiplicador do tipo do golpe`
  (redondo, min 1). Um golpe de power 50 ≈ dano do caminho legado por unidade base.
- **Accuracia é dados, não mecânica:** preservada no `Move`; não aplicada nos
  cálculos (sem RNG neste escopo).
- Fora do escopo: RNG/variação de partida, golpes de status com efeito, escolha do
  golpe pelo jogador, persistência de moves (não é estado persistente), accuracy
  efetiva, XP (D2), histórico/rank (D3).

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `Move` Dry::Struct (name/type/power/accuracy/pp); `BattlePokemon` aceita `moves` (default `[]`) e `from(pokemon, moves:)` incorpora | `lib/move.rb` + attribute `moves` em `BattlePokemon` |
| 1 | `PokeApi.move(name)` → `Move` memoizado; `PokeApi.moves_for(number)` → 4 últimos golpes memoizado (stubs `with_move`/`with_moves_for`) | `PokeApi.move` / `moves_for` + cache `@moves`; stubs no `PokeApiStub` |
| 2 | motor: escolhe maior dano esperado e usa o **power** no dano; `move_type` vira o tipo do golpe; `move` no log; PP decai no `BattlePokemon` funcional | `BattleEngine.act` com seleção de golpe + `use_move`/pp no `BattlePokemon` |
| 3 | motor: sem golpe utilizável → **Struggle** (tipo do atacante, power 10, sem PP, log `move: "Struggle"`) | fallback Struggle no motor |
| 4 | regressão: suíte 0011 continua verde **sem editar** `battle_engine_test.rb`; B3 aceita `pokemon without moves` (legado) | — (garantido por desenho; rodar suíte) |
| 5 | `GET /battle` carrega golpes (jogador + oponente) e `battle.erb` mostra PP por fighter + nome do golpe no log | rotas `get "/battle"` + `views/battle.erb` (helper moves) |
| 6 | suíte completa `./scripts/test` + `./scripts/lint` 0 | checagem geral |
| 7 | docs: `REQUIREMENTS.md` (RF-15 D1), `SESSIONS.md` (0015), `draft-auto-battler.md` (D1) | documento |

## 6. Observações e próximo passo

- **0 regressão em B3:** o caminho legado (sem `moves`) reutiliza exatamente
  `move_type_for`/`damage_for` atuais — `battle_engine_test.rb` (0011) não precisa
  ser editado. Novos testes de golpe ficam em arquivo próprio (`test/move_test.rb`,
  `test/move_engine_test.rb` ou casos adicionais) para não tocar os existentes.
- **Escolha deterministic:** avaliar o melhor golpe por alvo a cada ação — sem estado
  de "preferência" persistente entre rounds (só o PP decai).
- **PP como dado imutável:** usar a mesma filosofia do `take_damage` (retorna nova
  instância). `BattleEngine` reatribui no slot a cada ação.
- **Custo de rede:** `GET /battle` passa a fazer `4 × N` requests a mais (1 por move);
  memoizado por número → repetição do mesmo confronto não rebusca. Anotado como custo
  aceito (padrão RF-06/RF-13).
- Após 0015 validada: **D2 (XP/evolução)**, **D3 (histórico/rank)** e **D4 (draft
  temático)** seguem como candidatos; a **refatoração dos `rubocop:disable`** nos
  testes permanece anotada (draft pós-0007).

## 7. Validação (a preencher pelo usuário)

- Pendente — executada pelo usuário após a fase 2 (implementação TDD, suíte/lint verdes) concluída.