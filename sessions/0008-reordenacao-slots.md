# Sessão 0008 — Reordenação manual de slots (RF-08, A1) — ordem de batalha definida pelo usuário

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-08 |
| Implementação | — |
| Validação | — |

---

## 1. Objetivo

Permitir que o usuário **reordene manualmente os membros do seu time** (slots 1..N),
usando botões ▲/▼ — hoje (sessão 0007) a posição só muda na **remoção** (reindexa).
A ordem resultante é o **input explícito do futuro game loop** (auto-battler):
`TeamRepository#all(user_id)` já retorna `ORDER BY slot`, e agora o usuário controla
essa ordem. Nenhuma mudança de schema é necessária (RF-07 já persistiu `slot` + índices).

## 2. Contexto (estado atual)

- `team_pokemons`: `id, user_id, name, sprite, number, slot, created_at` com
  `UNIQUE (user_id, number)` e `UNIQUE (user_id, slot)` (sessão 0007).
- `TeamRepository#add` preenche próximo slot livre; `#remove` recompacta
  (`UPDATE ... SET slot = slot - 1 WHERE slot > k`). **Não existe `#move`.**
- `views/team.erb` renderiza cada membro com badge `#slot`, sprite/nome clicáveis
  (detalhe, RF-06), form `hx-delete="/team"` (RF-04) com hidden `id`.
- `POST /team` (adicionar) e `DELETE /team` (remover) re-renderizam o fragmento `#team`.
- Armadilha da 0005: elementos dentro do form de remoção não podem ser
  `input type="image"`/submit — submetem o form de equipe. Os controles ▲/▼ serão
  **forms irmãos** do form de remoção (nunca aninhados).

## 3. Critérios de aceite

### Domínio (`TeamRepository#move`)

- [ ] `#move(user_id, id, new_slot)` move o membro para o slot `new_slot` (1..N) e
      **mantém slots contíguos 1..N** (reindexa os demais, como `#remove`).
- [ ] Move para **cima** (novo slot menor) e para **baixo** (novo slot maior):
      time [A,B,C,D] → move C(3)→1 dá [C,A,B,D]; move A(1)→4 dá [B,C,D,A];
      `#all` retorna a nova ordem.
- [ ] **Idempotente:** `new_slot` igual ao atual, fora de `1..size(time)`, ou id
      inexistente → **sem efeito** (time intacto, sem raise).
- [ ] **Isolamento (RF-05):** id de membro de outro usuário → no-op; o time do dono
      não muda (`WHERE id AND user_id`).
- [ ] **Unicidade preservada:** a reordenação não viola `UNIQUE (user_id, slot)`
      (transação com slot temporário para liberar a origem antes do shift).

### Camada web (htmx, RNF-01)

- [ ] `POST /team/:id/move` com `new_slot` re-renderiza o fragmento `#team` (200) na
      **ordem nova**; `new_slot` inválido/igual/outro usuário → 200 com time intacto
      (contrato htmx, sem `responseHandling`).
- [ ] `views/team.erb` ganha botões **▲/▼** por membro — cada um é um form
      `hx-post="/team/:id/move"` (hidden `new_slot = slot ∓ 1`, alvo `#team`,
      `innerHTML`), **irmão** do form de remoção (não aninhado).
- [ ] Botões sempre renderizados: ▲ no slot 1 e ▼ no último slot são **no-ops
      idempotentes** (novo slot 0 ou N+1 → 200, time intacto).
- [ ] Sem regressão: remoção (`hx-delete`), detalhe (links sprite/nome) e demais
      rotas seguem verdes.

### Garantias (RNF)

- [ ] Testes sem rede (stub), suíte completa verde (`./scripts/test`) e lint verde
      (`./scripts/lint`), commit a cada green (RNF-04).
- [ ] Sem migração de schema (RF-07 já cobre `slot`); sem regressão RF-01..RF-07.
- [ ] `REQUIREMENTS.md` (novo **RF-08 — Reordenação manual de slots**, A1 sai das
      "Ideias de auto-battler") e `SESSIONS.md` (0008) atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **API do repositório absoluta (`new_slot`), não direcional:** `#move(user_id, id, new_slot)`
  é mais geral e testável que `move_up/move_down`; a UI ▲/▼ apenas calcula
  `new_slot = slot ∓ 1` (o ▲ no slot 1 envia 0 → no-op; o ▼ no último envia N+1 → no-op).
- **Rota `POST /team/:id/move`** (verbo `POST` por consistência com `POST /team`;
  "PATCH" descartado — o recurso é o slot do membro e a reordenação é uma ação de time).
- **Controle ▲/▼ como forms irmãos do form de remoção** (decisão da 0005: nada de
  submit aninhado que dispare `hx-delete`); botões `type="submit"` nos próprios forms.
- **Botões sempre visíveis, no-op idempotente nas bordas** (em vez de esconder):
  mantém o contrato "200 + time intacto" e simplifica os testes — alinhado à
  filosofia de DELETE idempotente (RF-04) e aviso via fragmento (RF-07).
- **Sem migração de schema:** `slot`, `UNIQUE (user_id, slot)` e `UNIQUE (user_id, number)`
  já existem; a reordenação usa transação com slot temporário (-1) para não violar
  a unicidade durante o shift.
- **Mover para slot arbitrário com lacunas e drag & drop** ficam anotados como
  variantes futuras (draft A1) — fora do escopo desta sessão.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `#move(user_id, id, 1)` move para cima: [A,B,C,D] slots 1..4 → C(3)→1 → [C,A,B,D] slots 1..4 contíguos; `#all` na ordem nova | `lib/team_repository.rb`: `move` com transação (slot temporário + shift + fix) |
| 1 | `#move` para baixo: A(1)→4 → [B,C,D,A]; D(4)→2 → [A,D,B,C]; contiguidade | shift inverso no mesmo `#move` |
| 2 | `#move` idempotente: `new_slot` igual, < 1, > size, id inexistente → time intacto, sem raise | guardas no `#move` (no-op) |
| 3 | `#move` isolamento: id de membro de outro usuário → no-op (time do dono intacto) | `WHERE id AND user_id` (padrão 0003/0007; teste documental) |
| 4 | `POST /team/:id/move` (new_slot) → 200, fragmento `#team` na ordem nova | `server.rb`: rota `post "/team/:id/move"` |
| 5 | Rota idempotente: `new_slot` inválido/igual/outro usuário → 200, time intacto; sem regressão no DELETE | validação na rota (no-op) |
| 6 | `team.erb` exibe ▲/▼ (forms `hx-post="/team/:id/move"` com hidden `new_slot`, alvo `#team`); remoção/detalhe seguem verdes | `views/team.erb` |
| 7 | suíte completa verde + lint 0 offenses | checagem global |
| 8 | `REQUIREMENTS.md` (RF-08 + roadmap/A1) e `SESSIONS.md` (0008) atualizados | documento |

## 6. Observações e próximo passo

- `#move` na UI equivale a "uma casa": ▲/▼. O game loop (B1/B2/B3) consumirá
  `all(user_id)` já na ordem definida aqui.
- Após esta sessão, o time do usuário tem ordem **explícita e estável** — input
  direto do motor de batalha (draft fase B/C).
- Próximo passo sugerido: **B1 — modelo de batalha** (domínio puro) quando esta
  sessão for validada.

## 7. Validação

- (preenchido após a fase de validação — executada pelo usuário)
