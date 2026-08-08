# Sessão 0002 — Remoção semântica (`DELETE /team`), RF-04

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída (validada em 2026-08-08) |
| Implementação | Não iniciada |
| Validação | Não iniciada |

---

## 1. Objetivo

Migrar a remoção de membro da equipe de `GET /team?index=<id>` (rota ambígua, listada
em `REQUIREMENTS.md` como "Rota de remoção ambígua") para **`DELETE /team`** com a
chave do registro persistido (`team_pokemons.id`, definida na sessão 0001). Manter o
fluxo 100% htmx (RNF-01) e a re-renderização do fragmento `#team` como resposta.

## 2. Contexto (estado atual)

- Remoção hoje: `views/team.erb` usa `form hx-get="/team"` com campo oculto
  `name="index" value=<poke.id>`; `server.rb` expõe `get "/team"` que remove se
  `params[:index]`.
- `GET /team` acumula na mesma rota remoção por querystring e renderização — falta de
  verbo/recurso, ambígua e sinalizada em `REQUIREMENTS.md`.
- `TeamRepository#remove(id)` já existe (sessão 0001) e apaga por `id`.
- htmx 2.0.3 na CDN (`views/index.erb`).
- Testes atuais de remoção usam `get "/team", index: id` em `test/server_test.rb`.

## 3. Critérios de aceite

- [ ] `DELETE /team` com `id=<id>` remove o Pokémon persistido (`TeamRepository#remove`)
      e responde o fragmento `#team` **sem** o membro removido (HTTP 200).
- [ ] A view `team.erb` usa `hx-delete="/team"` (sem `hx-get`), mantendo o campo oculto
      `name="id"` com o id persistido.
- [ ] `DELETE /team` com `id` inexistente responde **200** e re-renderiza a equipe
      intacta (idempotente; sem erro).
- [ ] `DELETE /team` **sem** `id` não quebra: re-renderiza a equipe (200).
- [ ] A rota `GET /team` é **removida** do `server.rb` (remoção só via `DELETE /team`;
      a re-renderização vem das respostas dos POST/DELETE).
- [ ] Testes atualizados para o novo verbo; suíte completa verde sem rede
      (`./scripts/test`).
- [ ] Lint verde (`./scripts/lint`) e commit pós-green (RNF-04).
- [ ] `REQUIREMENTS.md` (RF-04 status e ponto de refinamento) e `SESSIONS.md`
      atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **Verbo/rota:** `delete "/team"` no Sinatra (método `delete`); htmx dispara com
  `hx-delete` na forma serializada (o `id` vai no body → `params[:id]`).
- **Chave na URL x body:** mantém-se a chave como `input hidden name="id"` dentro da
  forma (herdado da 0001) — `DELETE /team` sem rota segmentada, conforme decisão
  fechada ("DELETE /team + hx-delete").
- **Idempotência:** `id` inexistente ou ausente → 200 re-render (sem 404; tratamento de
  erro global fica para a fase futura "Tratamento de erros").
- **Remoção de `GET /team`:** a rota `get "/team"` sai; a re-renderização da equipe
  passa a vir apenas nas respostas de POST/DELETE.
- **View:** manter `form hx-delete` com `hx-target="#team"` e `hx-swap="innerHTML"`;
  trocar só o verbo e o nome do campo (`index` → `id`). Botão continua `submit`.
- **Migração dos testes:** `test_get_team_removes_pokemon_by_id` → DELETE; adicionar
  casos para `id` inexistente e sem `id`.
- **Sem ORM e sem nova infra:** reutiliza `TeamRepository#remove(id)` e `settings.team`.

## 5. Plano TDD (passes)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | Migrar teste GET→DELETE (`delete "/team"` ainda não existe → falha) | Sem código (base red) |
| 1 | `DELETE /team` com `id` apaga e re-render sem o membro | `delete "/team"` no `server.rb` chamando `settings.team.remove(params[:id])` e renderizando `team.erb` |
| 2 | Assert no HTML da view: contém `hx-delete="/team"` e `name="id"` | `views/team.erb`: `hx-delete="/team"`, `name="id"` |
| 3 | `DELETE /team` com `id` inexistente → 200 e equipe intacta | `remove` idempotente (DELETE sem match não falha) |
| 4 | `DELETE /team` sem `id` → 200 re-render | Guard: `remove` só se `params[:id]` presente |
| 5 | `GET /team` deixa de existir (404) | Remover rota; suíte completa + lint verdes |

## 6. Validação (por preencher)

## 7. Observações e próximo passo

### Validação do refinamento (concluída em 2026-08-08)

- [x] Critérios de aceite fechados (seção 3) e decisões de design registradas (seção 4).
- [x] Plano TDD com 5 passos red/green definidos (seção 5).
- [x] `REQUIREMENTS.md` (RF-04 "Em refino", roadmap) e `SESSIONS.md` (0002 em refinamento) atualizados no mesmo escopo.
- Próximo passo: **fase 2 (TDD)** — passo 1 (red): migrar teste de remoção para `delete "/team"`.
