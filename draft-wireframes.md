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

- [ ] Aplicar o formato nas telas atuais (inventário de fragmentos: `#pokemon-list`,
      `#pokemon`, `#team`, `#battle`, `#team/manage`) como forma de "ler" o layout existente.
- [ ] Se o formato provar valor, vira método padrão das próximas sessões de UI (refinamento).