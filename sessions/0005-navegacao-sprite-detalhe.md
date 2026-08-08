# Sessão 0005 — Navegação pelo sprite para o detalhe (RF-06)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Em andamento |
| Implementação | — |
| Validação | — |

---

## 1. Objetivo

Corrigir a interação em que **clicar no sprite** do Pokémon submete os forms de equipe:
hoje os sprites são `<input type="image">`, que funcionam como **botões de submit** —
na equipe (`team.erb` num form `hx-delete`) o clique **remove** o Pokémon, e na listagem
(`pokemon.erb`, form `hx-post`) o clique **adiciona** à equipe. O comportamento correto
(RF-06) é: sprite e nome navegam ao detalhe (`GET /pokemon/:poke_id`, alvo `#pokemon`),
e a remoção/adicionar ficam restritas aos botões explícitos.

## 2. Contexto (estado atual)

- `views/team.erb`: cada membro rende `<input type="image" src=...>` dentro do form
  `hx-delete="/team"` → clique no sprite dispara `DELETE` (remoção inesperada).
- `views/pokemon.erb`: sprite igual dentro do form `hx-post="/team"` → clique adiciona.
- Passo 4 da sessão 0004 deixou os **nomes** clicáveis (`hx-get="/pokemon/:poke_id"`,
  alvo `#pokemon`), mas os sprites continuaram como submit buttons.
- Rota `GET /pokemon/:poke_id` e fragmento `pokemon_detail.erb` já existem (0004, passos 0-3).
- Bug reportado na validação manual da 0004: "clicar no sprite remove o Pokémon da equipe".

## 3. Critérios de aceite

- [ ] `GET /team` renderiza cada sprite como **link** `hx-get="/pokemon/{number}"`
      (alvo `#pokemon`, swap innerHTML) e **não** renderiza `<input type="image">`.
- [ ] `GET /pokemon?name=` renderiza o sprite como link `hx-get="/pokemon/{number}"`
      (alvo `#pokemon`) e **não** contém `<input type="image">`.
- [ ] Clicar no sprite **não** remove da equipe nem adiciona à equipe (sem submit).
- [ ] Detalhe ganha **botão "Fechar"/"Voltar"**: `hx-get` a uma rota que limpa o alvo
      `#pokemon` (swap innerHTML), apagando status e linda evolutiva da tela.
- [ ] Remover/adicionar seguem funcionais via botões ("Remove from Team" / "Add to Team").
- [ ] Sem JS customizado (RNF-01) — só atributos htmx.
- [ ] Suíte completa verde (`./scripts/test`), lint verde (`./scripts/lint`) e
      **commit a cada green** (RNF-04).
- [ ] `REQUIREMENTS.md` (RF-06 — sprite clicável) e `SESSIONS.md` (0005 em refinamento)
      atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **Causa raiz:** `<input type="image">` é um controle de submit implícito dentro do
  `<form>`; o clique submete independente do atributo `src`.
- **Solução:** substituir o `<input type="image">` por `<a href="#" hx-get=...><img ...></a>`
  (o mesmo padrão de link já aplicado aos nomes no passo 4 da 0004), mantendo padronização.
- **Alvo/swap:** `hx-target="#pokemon"` + `hx-swap="innerHTML"` (mesmo container do detalhe).
- **Botões preservados:** `Remove from Team` e `Add to Team` continuam como único submittion.
- **Sem server-side novo:** a rota de detalhe já existe; mudança é só nas views + testes.
- **Fechar/Voltar:** nova rota mínima `GET /pokemon/close` que responde fragmento vazio
  (swap `innerHTML` no alvo `#pokemon`); o botão no `pokemon_detail.erb` dispara com
  `hx-trigger="click"` — sem JS customizado (RNF-01).
- **Sem schema/DB:** nenhuma migração.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `GET /team` (com membro) não contém `input type="image"` e contém link `hx-get="/pokemon/{number}"` para o sprite | `views/team.erb`: sprite vira `<a href="#" hx-get=...><img ...></a>` (alvo `#pokemon`) |
| 1 | `GET /pokemon?name=` não contém `input type="image"` e contém link `hx-get="/pokemon/{number}"` no sprite | `views/pokemon.erb`: mesma troca |
| 2 | `GET /pokemon/close` responde fragmento vazio; detalhe contém botão "Fechar" com `hx-get="/pokemon/close"` | rota `get "/pokemon/close"` → erb vazio; botão no `pokemon_detail.erb` |
| 3 | ações de equipe sem regressão: botão Remove (submit) persiste; botão Add persiste | checagem da suíte completa + lint; sem alteração de rota |
| 4 | suíte completa + lint verdes; `REQUIREMENTS.md`/`SESSIONS.md` atualizados | ajustes finais e documento |

## 5b. Observações de TDD

- Os testes de assert negam `input type="image"` — prova de que o sprite deixou de ser
  submit. Os asserts de GET /team / GET /pokemon?name= continuam validando os existing flows
  (hx-delete do form nos botões via `test_post_team...`/`test_get_team_...` já existentes).
- Sem stub novo: `with_find` já cobre `pokemon.erb`.

## 6. Observações e próximo passo

- A sessão 0004 continua aguardando validação do usuário (fase 3); o bug de sprite vira
  esta sessão 0005 e não bloqueia a conclusão do restante da 0004.
- Próximo passo: **fase 2 (TDD)** — passo 0 (red): `GET /team` sem `input type="image"`.