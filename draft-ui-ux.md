# Draft — Análise de UI/UX e pontos de melhoria (2026-08-22)

> **Fora do fluxo.** Análise + anotação, **zero edição de código** (RNF-04).
> Baseline: pós 0036/J1 validada (lista clicável, formas base, 27 iniciais,
> gate da jornada). Suíte 611/1936, lint 0. Revisar ao fechar fases.

---

## 1. Panorama

Página única htmx (`layout.erb`) com 5 alvos empilhados — `#pokemon-list`,
`#pokemon`, `#team`, `#battle`, `#history` — nav com 4 âncoras; estilos próprios
(86 linhas) sobre sakura.css (CDN). Fluxo novo da jornada (gate battle/mart/center
até time de 6) já coerente entre rotas e fragmentos.

## 2. Achados por tela

### 2.1 Navegação / IA (`layout.erb`)

- **Empilhamento** (já anotado — JN-1): os painéis acumulam um abaixo do outro;
  página cresce sem noção de "onde estou".
- **Sem estado ativo no nav** — nenhum indicador visual da seção corrente.
- **Hack de limpeza invisível:** `<span hx-trigger="click from:#nav-lista">` limpa
  `#history`; frágil, acoplado e não cobre os outros painéis (ex.: sair de Batalha
  para Time não limpa `#battle`).
- **Sem feedback de carregamento em nenhum request htmx** (nenhum `hx-indicator`
  na base): cliques "não respondem" em rede lenta.
- Âncora + `hx-get` no mesmo link (`href="#team"`) — comportamento duplo
  (salto + troca de fragmento).

### 2.2 Listagem (`index.erb`/`pokemon_list.erb`/`pokemon_list_item.erb`)

- Busca sem contagem de resultados nem estado vazio amigável: filtro sem matches
  simplesmente esvazia a lista (só existe notice quando a **fonte** está vazia).
- **Add sempre habilitado**: time cheio/duplicado só descobre depois do clique
  (notice de erro). Sem estado "já está no time"/"time cheio" nos itens.
- **Jornada invisível na listagem:** o usuário só descobre o requisito de 6 ao
  clicar Batalha/Mart/Center. Candidato: progresso persistente "Time n/6" (na
  listagem e/ou nav) conectando o bloco de iniciais à porta de entrada.
- Bloco "Iniciais" bom para onboarding, mas sem microcopy explicando o papel
  (por que esses 27?).
- Sprites sem `loading="lazy"` (27+20 imagens por carga); sem grid — itens
  empilham 1 por linha, lista longa.
- **BUG visual (anotado 2026-08-22, pós JN-1; **corrigido na sessão 0044, 2026-08-24**):** o item da lista mostra o ícone, um **grande espaço em branco** e depois o nome — alinhamento do sprite dentro do
  `<a>` de `pokemon_list_item.erb` (img inline + whitespace) sem estilos de
  item/grid; agrava a leitura da listagem. Corrigido junto do grid (cards
  `.list-item`/`.starter-item` com sprite `block`).
- **Visibilidade do time na Lista (decisão do usuário 2026-08-22):** "não tenho
  como saber quantos Pokémon tenho no time ou quais são sem ir para outra aba".
  Caminho A — **adicionar informações visuais na própria Lista** (contador n/6 +
  **strip com os sprites do time** + estado do botão Add); Caminho B — **juntar a
  Lista com o Time** na mesma tela. Escolha do usuário; baliza a Onda 1.
- Paginação textual ok ("Página X de Y"); Anterior/Próxima pequenos, sem salto
  direto de página.

### 2.3 Detalhe (`pokemon_detail.erb`)

- Evoluções renderizadas como texto+sprite **sem link** — navegação morta num
  momento de alta curiosidade do usuário.
- Sprite sem `alt`; tipos com chip cinza genérico (sem cor temática por tipo).
- Add duplica o da lista (ok); Fechar limpa `#pokemon` mas não devolve scroll/
  foco ao item de origem.

### 2.4 Time (`team.erb`/`team_hp.erb`)

- Pré-jornada: aviso único de texto, sem progresso n/6 nem CTA ligando à lista.
- Remove é destrutivo direto (sem confirmação); ▲▼ sem `aria-label`.
- HP como texto ("HP 100/200") também no Center — sem barra visual.

### 2.5 Gerenciar (`team_manage.erb`) — JN-2 já na fila

- Checkboxes de golpes ruins para listas longas (dezenas), sem busca/agrupamento.
- Página interminável: 6 membros × (golpes + item + segurável + mover), tudo
  vertical; sem feedback de "salvo" além do notice textual.

### 2.6 Batalha (`battle.erb`)

- Painéis Seu Time/Oponente **duplicam o mesmo markup** (manutenção; draft de
  padrões já aponta Presenter/partial).
- Estado da batalha difícil de ler: HP e PP só em texto; log mostra apenas a
  última rodada (o histórico completo existe no engine e se perde na UI).
- Gate pré-jornada funciona (fragmento amigável), mas o nav continua levando
  até lá — feedback tardio (liga com 2.2, progresso n/6).
- Fim de batalha: XP/dinheiro/evolução/aprendizado em listas de texto —
  informativo, mas denso; "Novo confronto" reinicia sem atrito (ok p/ loop).

### 2.7 Histórico (`history.erb`)

- Ranking exibe **UUID cru** como identidade — ilegível (cruza com limitação de
  identidade `?as=` já anotada; candidato: apelido/nome amigável).
- Vazio tem estado ✓ ("Você ainda não batalhou."); recentes/ranking com limite
  fixo, sem paginação (menor).

### 2.8 Global / visual / acessibilidade

- `.notice` vermelho para avisos **neutros** (jornada, histórico vazio) —
  falta hierarquia info/sucesso/erro; tudo parece falha.
- Copy misturada PT/EN ("Add to Team", "Remove from Team", "Filter by name" vs
  "Salvar golpes", "Curar").
- Acessibilidade: `alt` ausente em vários sprites (detalhe, time, manage);
  botões ▲▼ sem rótulo acessível; foco não gerenciado nas trocas de fragmento.
- Responsividade só a básica do sakura (sem grid próprio).

## 3. Pontos fortes (manter)

- Alvos htmx consistentes e fragmentos pequenos; trocas locais sem reload.
- Gate da jornada coerente entre rotas, fragmento e views (0036).
- Estados vazios existem em Histórico/Batalha; paginação com total correto.
- Onboarding tem âncora clara (bloco de iniciais).

## 4. Melhorias anotadas (candidatas — nenhuma entra na fila agora)

**Quick wins**
- `alt`/`aria-label` nos sprites e botões ▲▼; `loading="lazy"` nas imagens.
- Indicador global de loading (`hx-indicator` + CSS).
- Hierarquia de notices (info/erro/sucesso) + copy unificada pt-BR.
- Evoluções do detalhe viram links (mesmo alvo `#pokemon`).
- Barra/contador "Time n/6" visível na listagem (conecta jornada ao bloco Iniciais).

**Médios**
- Grid responsivo na listagem (2–3 colunas) — **feito (sessão 0044, 2026-08-24,
  ajustado na validação)**: grade **uniforme de 6 colunas com páginas cheias e
  paginação on-demand** — `PAGE_SIZE` 36 = grid 6×6, página 1 = 27 iniciais + 9
  comuns, cada página carrega só o próprio lote (scan `base_form?` em batchs;
  "Página X" sem total), iniciais só na 1ª página; cards `.list-item`/
  `.starter-item` corrigindo o bug visual do item.
- Barras visuais de HP/PP (battle + Center).
- Extrair partial/presenter dos painéis de batalha (remove duplicação).
- Estado ativo no nav + limpeza sistemática dos painéis (mata o hack do span).
- **Largura cheia nas demais telas (anotado 2026-08-23, durante validação da 0041):**
  a sakura limita `body` a `max-width: 38em`; a 0041 resolveu só na batalha
  (`body.page-battle { max-width: none }` + grid 3 colunas). **Aplicar o mesmo
  espaçamento/largura cheia em Lista, Time, Histórico, Detalhe e Manage** numa onda
  futura (fora de sessão — RNF-04). **Feito (sessão 0044, 2026-08-24):** Lista/`/`
  (0042) e Histórico (`body.page-history`, 0044) em largura cheia; Detalhe e Manage
  são fragmentos dentro da `/` já em largura cheia desde 0042.

**Juice / micro-interações (anotado 2026-08-22, pós JN-1 — usuário pediu "mais juice")**
- **Notificação ao incluir Pokémon:** hoje o add só troca o `#add-status` (texto);
  candidato a **toast** (sprite + nome, animação de entrada/saída) reutilizando os
  kinds de notice; explorar `HX-Trigger` para notificações de outros eventos.
- **Efeitos visuais nos botões** (hover/active/transição) em todas as telas —
  tokens em `draft-design-system.md`; preferência: CSS puro, sem lib JS.
- Animar trocas de painel/tela (fade/deslize) e estados de item (marcado no
  manage, selecionado na lista).

**Grandes (já mapeados na fila/rascunho — referência)**
- JN-1 telas próprias (fim do empilhamento), JN-2 golpes em lista, JN-4
  componentes Mart/Center, J3 ranking legível, J4 nome na entrada (identidade
  legível no ranking).

---

## 5. Priorização sugerida (2026-08-22 — execução a critério do usuário)

Ordem proposta por valor × esforço × dependência. Nenhuma onda abre escopo novo de
produto — são o desenho alvo virando implementação; cada onda pode virar **uma
sessão única** quando o usuário decidir encaixá-la (fora da ordem JN-2 → J3 → JN-1).

| Onda | Itens | Por quê nessa ordem |
| --- | --- | --- |
| **0 — quick wins** *(feita — sessão 0038, **concluída e validada em 2026-08-22**)* | `alt`/`aria-label`, `loading="lazy"`, indicador global (`hx-indicator`), hierarquia de notices + copy pt-BR, evoluções linkadas no detalhe | só view/CSS, baixo risco; base visual para tudo abaixo |
| **1 — jornada visível** *(feita — sessão 0042, **Caminho B: Lista+Time unificados**, **concluída e validada em 2026-08-24 — suíte 689/2184, lint 0**)* | contador/barra "Time n/6" + painel do time na própria Lista, **ou unificar Lista+Time** (decisão do usuário 2026-08-22; ver §2.2) | conecta o gate à descoberta; reusa `JourneyService`; precisa expor `@team_names`/`@journey_started` nos renders |
| **2 — leitura da batalha** *(feita — sessão 0041, **implementada em 2026-08-23, suíte 680/2132, lint 0; aguardando validação**)* | partial única dos painéis (+presenter), barras HP/PP, log das últimas N rodadas | mata duplicação antes de qualquer feature nova de batalha |
| **3 — estrutura** *(feita — sessão 0044, **implementada e validada em 2026-08-24 — suíte 694/2200, lint 0**)* | estado ativo no nav + limpeza sistemática de painéis, grid responsivo da listagem | polimento estrutural; depende só de CSS/markup |
| Dependentes da fila | JN-2 (golpes em lista), JN-1 (telas próprias), JN-4 (componentes Mart/Center), J3 (ranking S–F), J4 (nome/apelido) | ordem fechada em 2026-08-18 mantida |

Regras: cada onda = refinamento (fase 1) próprio quando virar sessão; wireframes
alvo em `docs/screens/` já servem de base para os critérios. Tokens visuais
necessários às ondas 0–2 estão anotados em `draft-design-system.md`.
**Decisão do usuário (2026-08-22):** ondas 0–3 entram **depois da fila fechada**
(JN-2 → J3 → JN-1), na ordem da tabela; contador n/6 em nav + listagem/team;
gerenciar time permanece livre pré-jornada (detalhes no `draft-wireframes.md` §8).
**Decisão do usuário (2026-08-24 — Onda 1/Caminho B):** unificar a Lista com o Time
na mesma tela (página única `/` de 2 colunas) em vez de contador/strip na lista
mantendo `/team` página própria — sessão 0042. A página `/team` deixa de ser página
(404 em navegação direta); vira fragmento htmx interno (`#team-view`).

---

## 6. Janelas flutuantes (Poke Center / Poke Mart) e gestão de golpes/itens (anotação 2026-08-25 — fora do fluxo, RNF-04)

> Ideias novas do usuário, **não refinadas** (RNF-04). Vão virar sessão própria após a
> 0048 concluir/validar — a critério do usuário. Hoje os CTAs do gameloop (JN-5, 0048)
> **levam à Lista** (`/`), onde `#team-view` mostra os partials `_center.erb`/`_mart.erb`.

- **Poke Center / Poke Mart como janelas flutuantes (modais)**: em vez de levar à
  tela de lista/time (`/`), os CTAs do circuito (fim de batalha / painel do time)
  abrem o Center/Mart em **janela flutuante** (overlay/modal) sobre a tela atual —
  mantendo o contexto (batalha terminada, painel do time) sem navegação. Cruz com o
  JN-5 (0048) que acabou de criar esses CTAs como links de navegação.
- **Gerenciar golpes no Poke Center e itens no Poke Mart**: estender Center/Mart para
  além de curar/comprar — **editar golpes dos pokes** (hoje no `team_manage`) e
  **gerenciar itens** (equipar/desequipar) dentro do circuito. Cruz com J2
  (personalização).
- **Reestruturar como gerenciamos os golpes dos pokes — esboço: 4 selects** para
  selecionar os golpes (um por slot, cap 4), em vez da lista clicável atual do
  `team_manage.erb` (JN-2). Refinamento futuro fechará modelo/UI.


## 7. Playtest 02 — Responsividade (2026-08-27, levantamento browser-harness)

> Levantamento fora do fluxo (RNF-04) — não abre escopo agora. Base: `playtest-02-responsividade.md` (medições CDP). Virará sessão `RESP-1` após M2b.

**Blocker P0:** falta `<meta viewport>` em `views/layout.erb` — mobile renderiza 980px desktop, media-queries 720/480 nunca disparam. Injeção de viewport fez `375→346px 1col` funcionar.

**Grid listagem (`public/style.css:18`):** `repeat(6)` até 720 quebra em `768` (6×42px inutilizável), `1024` (6×85px estreito). Proposta: `auto-fill minmax(140px,1fr)` ou breakpoints `1100:6 / 900:4 / 720:3 / 520:2 / 360:1`. `list-team-grid` colapsa em 720 mas `768` ainda é `319+396` espremido — subir para `960`.

**Filtros (`_filter_controls`):** 7 filhos `flex 1 1 8em` → `375:117px` (3 linhas), `320:165px` (4 linhas), `768:179px` (2-3 linhas). Falta `min-height 44px` p/ toque, agrupamento ou drawer.

**Lista+Time scroll:** `max-height 78vh` + `overflow:auto` cria duplo scroll em desktop; `min-height 420px` deixa buraco em mobile vazio.

**Batalha (`battle-layout 3×1fr`):** sem `@media` — em `<900` deve empilhar `1fr` e barras `120/80px` fluidas.

**Outros:** `team-column` border/padding fixos, `img` sem `max-width 100%`, `nav nowrap`, ranking UUID quebra.

Priorização anotada: P0 viewport+grid+team collapse 960; P1 filtros+battle; P2 barras fluidas+polimento.

