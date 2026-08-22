# Draft — Especificação de telas (wireframes em texto: sketch + YAML)

> **Fora do fluxo.** Metodologia de design/planejamento das telas do projeto, em texto
> puro (md + YAML) — o usuário não tem ferramenta de desenho e precisa indicar onde cada
> elemento fica na tela de forma legível e parseável pelo agente. Revisar ao crescer.
> Sessão de origem: refinamento alongado — apenas levantamento e anotações, **zero
> edição de código**.

---

## 1. Por que

- O projeto é fragmentos-htmx: cada "tela" é um **alvo** (`#team`, `#pokemon-list`,
  `#pokemon`, `#battle`) re-renderizado por `hx-swap="innerHTML"`.
- Hoje os ERB são o único registro visual — não há wireframe nem plano.
- A ferramenta precisa: (a) o usuário **indicar onde cada elemento fica** sem desenhar;
  (b) o agente **ler, compreender e aplicar** em HTML/htmx.

## 2. Formato (dupla complementar, mesmo arquivo)

**Fonte da verdade = YAML** (parseável, determinístico, espelha os fragmentos/htmx).
**Anotação visual = sketch ASCII** (blocos na tela escritos com caracteres).

> Regra: um documento de tela tem o sketch ASCII **por cima** (para o olho humano) e o
> YAML **embaixo** (para o agente). Se divergirem, o YAML vence.

## 3. Modelo do documento

```markdown
## Tela: <nome>   (fragmento <#alvo>)

```
┌─ título ─────────────────┐
│ [elemento] [elemento]    │
└─────────[ação]───────────┘
```

```yaml
fragment: "<#alvo>"              # alvo htmx (swap innerHTML)
refresh: <rota_get_refrescar>    # opcional; como a tela volta a carregar
blocks:
  - id: <id-máquina>
    type: <tipo básico>
    loop: <fonte_por_item>       # opcional: repetir por item (ex.: team)
    ...campos específicos do tipo...
```

## 4. Vocabulário — `types` básicos (v2: começar simples, crescer sob demanda)

| type | Campos | Para quê |
| --- | --- | --- |
| `list` | `loop`, `children` | Repetir bloco por item (ex.: Pokémon do time) |
| `panel` | `title`, `children` | Caixa agrupadora (ex.: "Seu Time" / "Oponente") |
| `text` | `source`, `text` | Texto/label (ex.: `member.name`) |
| `badge` | `source` | Selo curto (ex.: slot `#1`, HP `n/m`) |
| `sprite` | `source` | Imagem (ex.: `member.sprite`) |
| `img` | `src`, `alt` | Imagem genérica |
| `link` | `text`, `action` | `<a>` + navegação htmx |
| `button` | `text`, `action` | Botão que dispara ação htmx |
| `input` | `name`, `type` | Campo de entrada (text/hidden/checkbox) |
| `select` | `name`, `action`, `loop` | Dropdown (ex.: listagem de Pokémon, campo `q` no índice) |
| `form` | `action`, `fields`, `submit` | Formulário htmx (ex.: add/pesquisa) |
| `notice` | `source`, `text` | Aviso/erro (mensagens de retorno) |

### Regras de ação (campo `action`)

Tudo o que dispara requisição é `action` no formato `<method> <rota>`:

```
get /team
post /team/<member.id>/moves      # placeholders entre < > ligados ao `loop`
post /battle/play
delete /team
```

Atributos htmx derivados do `fragment` do documento + `action`:
`hx-<method>`, `hx-target="<fragment>"`, `hx-swap="innerHTML"`.

## 5. Exemplo aplicado (tela existente — Gerenciar time, `#team`)

```markdown
## Tela: Gerenciar time   (fragmento #team)

```
┌─ Gerenciar time ──────────────────────┐
│ #1 [sprite] bulbasaur                │
│    [moves form]            [▲] [▼]   │
│ #2 [sprite] pikachu                  │
│    [moves form]            [▲] [▼]   │
└─────────────────── [← Voltar] ───────┘
```

```yaml
fragment: "#team"
refresh: get /team/manage
blocks:
  - id: manage-members
    type: list
    loop: team
    children:
      - type: badge,   source: member.slot
      - type: sprite,  source: member
      - type: text,    source: member.name
      - type: form
        action: post /team/<member.id>/moves
        fields:
          - type: checkbox, loop: available_moves[member.id]
      - type: button, text: "▲", action: post /team/<member.id>/move new_slot=member.slot-1
      - type: button, text: "▼", action: post /team/<member.id>/move new_slot=member.slot+1
  - id: back
    type: link, text: "← Voltar", action: get /team
```

## 6. Decisões (2026-08-10)

- [x] Vocabulário: **começar com os tipos básicos da seção 4; crescer sob demanda**.
- [x] Ferramenta: **por ora o mais simples** — apenas md/YAML (nenhum renderer desenvolvido).
- [x] Se no futuro quisermos "ver" as telas, **`scripts/wireframe`** (Ruby, já no projeto)
      pode ler o YAML e gerar um HTML de preview estático — decisão adiada até ser necessária.
- [x] Documentos das telas: **`docs/screens/*.md`** (decisão 2026-08-10) — um por fragmento.

## 7. Candidatos de próximo passo (RNF-04)

- [x] Aplicar o formato nas telas atuais — feito em `docs/screens/*.md`, com
      **desenhos alvo** por tela (2026-08-22, análise `draft-ui-ux.md`).
- [ ] Se o formato provar valor, vira método padrão das próximas sessões de UI (refinamento).

---

## 8. Fluxo do gameloop (anotação 2026-08-22 — JN-5; desenha a navegação ponta a ponta)

> **Fora do fluxo.** Complementa os desenhos alvo: como as telas se encadeiam no
> circuito montagem → batalha → loja/cura → repetir (ideia anotada no
> `draft-auto-battler.md` como JN-5). Nada implementado.

```
                    ┌────────────────────────────┐
                    │ Listagem (+ iniciais 27)   │◄───────────────┐
                    │ busca · grid · Add         │                │
                    └──────────┬─────────────────┘                │
                     add até 6 │                                  │
                               ▼                                  │
                    ┌────────────────────────────┐                │
        ┌──────────►│ Time completo → gate aberto│                │
        │           │ (user_state OU time ≥ 6)   │                │
        │           └──────────┬─────────────────┘                │
        │                      ▼                                  │
        │           ┌────────────────────────────┐     recompensas│
        │           │ Batalha (rodadas/Jogar)    │────────────────┤
        │           └──────────┬─────────────────┘                │
        │                      ▼                                  │
        │           ┌────────────────────────────┐                │
        │           │ Poke Center / Poke Mart    │────────────────┘
        │           │ curar · comprar itens      │
        │           └────────────────────────────┘
        │
        │   sempre acessíveis (transversais):
        ├── Detalhe do Pokémon (qualquer sprite → #pokemon)
        ├── Histórico (#history)
        └── Gerenciar time (#team manage)
```

Matriz de gates (estado hoje + decisão pendente anotada):

| Área | Pré-jornada (<6) | Pós-jornada |
| --- | --- | --- |
| Listagem / Detalhe | livre | livre |
| Time (fragmento) | livre, com aviso n/6 | livre |
| Batalha / Mart / Center | **bloqueado** (fragmento amigável) | livre |
| Histórico | livre (decisão 0036) | livre |
| Gerenciar time | **livre (decisão 2026-08-22 — preparação)** | livre |

Recompensas do fim de batalha alimentam o loop: XP (nível/evolução/aprendizado),
dinheiro (Center/Mart) e HP persistido — os três consomem/voltam pela batalha.

**Pendências resolvidas (decisão do usuário em 2026-08-22):**
1. **Gerenciar pré-jornada: mantém-se LIVRE** — montar/ajustar o time inicial é
   preparação; itens já dependem do Mart (bloqueado). Gate permanece só para
   Batalha/Mart/Center.
2. **Contador n/6 mora em nav + listagem/team** — badge compacto no nav sempre
   visível + barra com CTA "Montar time" na listagem e no fragmento `#team`
   (desenhos alvo já refletem isso em `nav-shell.md`, `pokemon-list.md` e
   `team.md`).
3. **Ondas de UI (0–3) entram DEPOIS da fila fechada** (JN-2 → J3 → JN-1), na
   ordem proposta em `draft-ui-ux.md` §5.