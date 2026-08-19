# Sessão 0034 — D1 parcial: nível de aprendizado de golpes

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões do usuário em 2026-08-19 (confirmado iniciar o refinamento) |
| Implementação | Pendente |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

**D1 parcial — nível de aprendizado de golpes** (2ª da ordem fechada em 2026-08-18 —
ver `draft-auto-battler.md`:418-425): trazer o **nível de aprendizado**
(`learnable_moves` com `level_learned_at`, sessão 0024) para a **UI de gerenciamento de
time**. Ao **subir de nível**, o Pokémon passa a ter **acesso progressivo** ao golpe da
`learnable_moves` da species — o manage (RF-17) passa a **oferecer apenas golpes com
`level <= nível` do membro**, exibindo o nível de aprendizado de cada um, e a **troca de
golpes é manual** (tela de times) — sem substituição automática quando o cap 4 está cheio.

**Escopo fechado pelo usuário (2026-08-19):**
1. **Gating no manage por nível** — checkboxes só dos golpes com `level <= nível` do membro.
2. **Exibir `level_learned_at` na UI** — "Nível N" ao lado de cada golpe no manage.
3. **Troca manual preservada** — o jogador troca os golpes na tela de times (checkbox da
   RF-17); **não** há substituição automática no cap cheio.
4. **Aprendizado automático no `:finished` inalterado** — mantém a regra atual
   (aprende **todos** os `learnable_moves` com `level <= nível novo`, até o cap 4);
   **0 mudança** no `BattleService`.

## 2. Contexto (estado atual — diagnóstico)

- `learnable_moves(number)` já existe no gateway (`PokeApiMoves#learnable_moves`,
  `lib/gateways/poke_api_moves.rb:24-33`) — `[{level:, name:}]` por move, `level-up`
  somente, ordenado `[level, name]`, decorado com cache (E1-B) e stubável
  (`PokeApiStub.with_learnable_moves`).
- Aprendizado **automático** no `:finished` já usa `learnable_moves` e aprende todos os
  `level <= nível novo` de uma vez, cap 4 (`BattleService#learn_moves_for_member`/
  `#try_learn`, `lib/battle_service.rb:191-203`) — **regra mantida** nesta sessão.
- **Montagem** já dá apenas golpes de nível 1 (`pokemon_with_level_one_moves`,
  `server.rb:126-132`).
- **Manage (RF-17) lista COMPLETA sem gating**: `TeamService#manage_data` devolve
  `available_moves = api.available_move_names(number)` (`lib/team_service.rb:56-58`) —
  o jogador pode escolher qualquer golpe da species, **independente do nível**
  (liberdade apontada como candidata a restrição na sessão 0024).
- `save_moves` valida contra essa lista completa (`team_service.rb:60-68`): só checa
  limite de 4 + nome presente em `available_moves`.
- `team_manage.erb` renderiza checkbox por `@available_moves[poke.id]` marcando
  `checked` quando `poke.moves.include?(move_name)` (`views/team_manage.erb:16-24`).
- `TeamService` **não conhece o nível** dos membros (hoje injeta `api`/`team`/
  `inventory`/`wallet` apenas — `server.rb:422-424`); nível vive em
  `ProgressionRepository#get` → `{level:, xp:, hp_max:, hp_current:}`.
- Stubs atuais de manage usam `PokeApiStub.with_available_move_names(...)` —
  serão migrados para `with_learnable_moves(...)` com níveis.

## 3. Escopo

### Produção — `TeamService` (`lib/team_service.rb`)

- Nova dep injetada **`progression`** (já existe `settings.progression`).
- `manage_data(user_id)` passa a devolver `available_moves` por membro como
  **lista gated com nível**: `[{level:, name:}, ...]` a partir de
  `api.learnable_moves(member.number)` filtrando `level <= member_level`, **unido**
  com os nomes já salvos do membro (`member.moves` — preserva golpes legados/açima do
  nível, permitindo removê-los; se não estiverem em `learnable_moves`, sem `level`).
  `member_level = progression.get(user_id, member.id)&.fetch(:level) || 1`.
- `save_moves(user_id, member, selected, available_moves)` valida `selected` contra os
  **nomes** de `available_moves[member.id]` (lista gated) — golpe **acima do nível** (ou
  fora do `learnable_moves`) → aviso, não salva. Limite de 4 mantido.
- `moves_for` (privado) deixa de usar `available_move_names` (fica órfão na UI; mantido
  no gateway sem remoção — 0 regressão de interface).

### Produção — `server.rb`

- `set :team_strategy, TeamService.new(..., progression: deps[:progression])`
  (`configure`, `server.rb:422-424`).
- Contrato de rotas intacto (`GET /team/manage`, `POST /team/:id/moves`).

### Produção — `views/team_manage.erb`

- Checkbox por golpe da lista gated: `<input value="<name>" ...>` + rótulo
  `"<name> — Nível N"` (quando `level` presente; sem nível → só o nome) e
  `checked` quando `poke.moves.include?(name)`.
- Demais blocos (item/segurável/slots/Voltar) intactos.

### Testes

- Migrar stubs `with_available_move_names` → `with_learnable_moves` nos testes de
  manage (team_routes_test, team_strategy_routes_test).
- Novos testes: gating (nível 1 vê só nível 1; membro de nível maior vê mais), aviso ao
  salvar golpe acima do nível, nível exibido na UI, golpes salvos legados permanecem
  visíveis/removíveis, isolamento por usuário.

### Fora de escopo (RNF-04 — não abrir)

- Troca automática de golpes no cap 4 (substituição) — decisão do usuário: jogador troca
  **manualmente** na tela de times.
- `BattleService`/`BattleEngine`/`learn_moves_for_member` — aprendizado do `:finished`
  **inalterado** (regra atual).
- Exibir nível no `battle.erb` (painel de batalha) — `BattlePokemon`/`Move` não carregam
  `level_learned_at`; tocar o motor sairia do escopo. Anotado como candidato futuro
  (JN-2 "golpes em lista").
- Remover `available_move_names` do gateway (mantido, sem chamador de UI).

## 4. Critérios de aceite

### Resultado

- [ ] **Gating no manage por nível:** `team_manage.erb` só oferece **checkboxes de
      golpes com `level <= nível` do membro** (fonte `learnable_moves`), substituindo a
      lista completa de `available_move_names` (RF-17); membros de níveis diferentes veem
      listas diferentes consistentes com o próprio nível.
- [ ] **Nível exibido na UI:** cada golpe oferecido aparece como `"<name> — Nível N"`
      (do `level_learned_at` de `learnable_moves`); golpes salvos não presentes em
      `learnable_moves` aparecem sem nível (legado, removível).
- [ ] **Validação gated:** `POST /team/:id/moves` com golpe **acima do nível** do membro
      → aviso (`@notice`), **não salva**; limite de 4 e validação de existência mantidos.
- [ ] **Troca manual preservada:** com a lista salva cheia (4), o jogador **desmarca um
      golpe e marca outro** da lista gated para trocar (cap/`set_moves`/RF-17 intactos);
      golpes salvos continuam aparecendo `checked`; sem substituição automática em
      hipótese alguma.
- [ ] **Aprendizado automático `:finished` inalterado:** `BattleService#learn_moves_for_
      member` continua aprendendo todos os `learnable_moves` com `level <= nível novo`
      (cap 4) — nenhuma mudança de comportamento (suíte de batalha existente verde sem
      edição).
- [ ] **Isolamento por usuário mantido (RF-05):** o manage de um usuário nunca exibe/
      valida golpes de membros de outro usuário.

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (559 runs/1696 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão
      RF-01..RF-18/Eco.
- [ ] Sem novas gems; sem mudança de schema; testes sem rede (`PokeApiStub.
      with_learnable_moves`); sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` (roadmap item 25 — D1 parcial executado; status `Planejada` até
      validação), `SESSIONS.md` (0034 em fase 2 + próximas J1/JN-2/J3/JN-1) e
      `draft-auto-battler.md` (ordem fechada — D1 parcial feito) atualizados no mesmo
      escopo; *status de validação* só após o usuário validar.

## 5. Decisões de refinamento (fechadas com o usuário)

- **D1 parcial = "nível de aprendizado na UI"** — a fonte do aprendizado (`learnable_moves`)
  já existe desde 0024; o que falta é **restringir o manage ao nível** e **informar o
  nível** de cada golpe. Escopo fechado pelo usuário em 2026-08-19.
- **Gating substitui a liberdade da RF-17:** o jogador não escolhe mais golpe acima do
  nível (antes permitido). É o comportamento desejado do "nível de aprendizado"; a troca
  de golpes acima do nível deixa de ser possível.
- **União com moves salvos:** `available_moves` = gated ∪ `member.moves` — para que
  golpes salvos em níveis anteriores (sempre `<= nível` na prática) e eventuais legados
  permaneçam visíveis/editable (desmarcáveis). Sem isso, um golpe fora da lista gated
  ficaria preso (não daria para remover).
- **Troca manual em vez de auto-substituição:** decisão do usuário — quando o cap 4 está
  cheio e um novo golpe de nível alcançado chega, o aprendizado automático **não** salva
  (regra atual, sem aviso de substituição) e o jogador decide **manualmente** no manage
  quais golpes ficam. A anotação da 0024 ("troca automática como candidato") fica
  **descartada** por decisão do usuário.
- **Apresentação do golpe:** `"<name> — Nível N"` no manage (sem alterar o formato
  `"<name> — PP n"` do `battle.erb`, que é alvo da futura JN-2).
- **`available_move_names` órfão na UI:** deixa de ser chamado pelo `TeamService`; o
  método permanece no gateway (interface pública/testes) — remoção seria sessão própria
  (fora de escopo).
- **Ordem sugerida:** TeamService (gating + dep `progression`) → validação gated →
  `team_manage.erb` (nível na UI) → migração de stubs e novos testes de rota → docs.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0034: refinamento concluido — D1 parcial (nivel de aprendizado de golpes): gating do manage por nivel, nivel na UI, troca manual, :finished inalterado` |
| 1 | **TeamService com dep `progression` + `manage_data` gated:** `red` — teste difícil novo falha (TeamService sem gating): membro nível 1 vê só golpes `level: 1` no body do `GET /team/manage` (stub `with_learnable_moves` com níveis 1/5); membro de nível maior (grant de XP) vê os de `level <= nível`. `green` — injeção da dep + `member_level` via `progression.get` + `moves_for` com `learnable_moves` filtrado por `level` | suíte completa verde + lint 0, commit `Passo 1:` |
| 2 | **Validação gated no `save_moves`:** `red` — `post /team/:id/moves` com golpe de `level` acima do nível do membro → aviso + `moves` do membro intacto (mesmo limite de 4). `green` — `move_choice_error` valida contra os nomes da lista gated | suíte completa verde + lint 0, commit `Passo 2:` |
| 3 | **`team_manage.erb` com nível na UI + união com moves salvos:** `red` — manage exibe `"<name> — Nível N"`; golpe salvo fora da lista gated continua visível (legado) e `checked`; sem `<html>`. `green` — ERB com rótulo + união em `available_moves` | suíte completa verde + lint 0, commit `Passo 3:` |
| 4 | **Migração de stubs + suíte de regressão do manage:** migrar `with_available_move_names` → `with_learnable_moves` nos testes existentes (team_routes/team_strategy) preservando asserts; adicionar casos: membro nível alto vê mais golpes, isolamento por usuário, gating não afeta item/segurável/slots | suíte completa verde **559/1696+** + lint 0, commit `Passo 4:` |
| 5 | **Docs:** `REQUIREMENTS.md` (roadmap item 25 — D1 parcial executado, status `Planejada` até validação), `SESSIONS.md` (0034 fase 2 + próximas J1→JN-2→J3→JN-1), `draft-auto-battler.md` (ordem fechada — D1 parcial feito) | suíte verde + lint 0, commit `Passo 5:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar `Done`/commitar conclusão antes. |

## 7. Validação (executada pelo usuário)

**Pendente.** Ao final da fase 2, o usuário roda `./scripts/test` (suíte completa) e
`./scripts/lint`, confere o comportamento manualmente (manage: subir de nível e ver novos
golpes liberados/noção de nível; trocar golpes com cap cheio; aprender via batalha) e
verifica os critérios de aceite (seção 4). Resultado e status preenchidos aqui após o
feedback.

## 8. Observações

- **Próximas sessões (ordem fechada 2026-08-18):** J1 (seleção inicial) → JN-2 (golpes em
  lista) → J3 (ranking S–F) → JN-1 (telas próprias) → organizar o resto (JN-3, JN-4, JN-5,
  J2, J4, D4).
- **Candidato futuro anotado:** exibir nível de aprendizado no `battle.erb` e tornar o
  seletor de golpes uma lista (JN-2) — hoje o gating/`level_learned_at` fica só no manage.
- **`available_move_names` órfão:** manter no gateway sem chamador de UI; remoção em
  respiro futuro se desejado.