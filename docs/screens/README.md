# Screens — Poke-HTMX

> Documentação dos fragmentos **atuais** no formato wireframe (sketch ASCII + YAML).
> Formato definido em `docs/draft-backlog.md`. YAML é a fonte da verdade; o sketch é a
> anotação visual.
>
> **Desenho alvo (2026-08-22):** cada doc traz também uma seção "Desenho alvo" com o
> alvo visual proposto pela análise de UI/UX (`docs/draft-backlog.md`) — anotação, não
> estado atual. `history.md` documenta a tela existente e seu alvo no mesmo arquivo.

## Inventário dos fragmentos

| Alvo htmx | View | Rotas que re-renderizam | Doc |
| --- | --- | --- | --- |
| (shell) | `layout.erb` + `index.erb` | `GET /` | [nav-shell.md](nav-shell.md) |
| `#pokemon-list` | `pokemon_list.erb`, `pokemon_list_item.erb` | `GET /pokemons`, `GET /` | [pokemon-list.md](pokemon-list.md) |
| `#pokemon` | `pokemon.erb`, `pokemon_detail.erb`, `pokemon_close.erb` | `GET /pokemon?name=`, `GET /pokemon/:poke_id`, `GET /pokemon/close` | [pokemon-add.md](pokemon-add.md), [pokemon-detail.md](pokemon-detail.md) |
| `#team` | `team.erb`, `team_hp.erb` | `GET /team`, `POST /team`, `DELETE /team`, `POST /team/:id/move`, `POST /team/heal`, `POST /mart/buy` | [team.md](team.md) |
| `#team` (manage) | `team_manage.erb` | `GET /team/manage`, `POST /team/:id/moves` | [team-manage.md](team-manage.md) |
| `#battle` | `battle.erb`, `battle_close.erb` | `GET /battle`, `POST /battle/play`, `GET /battle/close` | [battle.md](battle.md) |
| `#history` | `history.erb`, `history_close.erb` | `GET /history`, `GET /history/close` | [history.md](history.md) |

Fragmentos vazios `pokemon_close.erb`/`battle_close.erb` limpam o alvo (swap `innerHTML`
para vazio) — usados como "fechar".