# Screens — Poke-HTMX

> Documentação dos fragmentos **atuais** no formato wireframe (sketch ASCII + YAML).
> Formato definido em `draft-wireframes.md`. YAML é a fonte da verdade; o sketch é a
> anotação visual.

## Inventário dos fragmentos

| Alvo htmx | View | Rotas que re-renderizam | Doc |
| --- | --- | --- | --- |
| (shell) | `layout.erb` + `index.erb` | `GET /` | [nav-shell.md](nav-shell.md) |
| `#pokemon-list` | `pokemon_list.erb` | `GET /pokemons`, `GET /` | [pokemon-list.md](pokemon-list.md) |
| `#pokemon` | `pokemon.erb`, `pokemon_detail.erb`, `pokemon_close.erb` | `GET /pokemon?name=`, `GET /pokemon/:poke_id`, `GET /pokemon/close` | [pokemon-add.md](pokemon-add.md), [pokemon-detail.md](pokemon-detail.md) |
| `#team` | `team.erb` | `GET /team`, `POST /team`, `DELETE /team`, `POST /team/:id/move` | [team.md](team.md) |
| `#team` (manage) | `team_manage.erb` | `GET /team/manage`, `POST /team/:id/moves` | [team-manage.md](team-manage.md) |
| `#battle` | `battle.erb`, `battle_close.erb` | `GET /battle`, `POST /battle/play`, `GET /battle/close` | [battle.md](battle.md) |

Fragmentos vazios `pokemon_close.erb`/`battle_close.erb` limpam o alvo (swap `innerHTML`
para vazio) — usados como "fechar".