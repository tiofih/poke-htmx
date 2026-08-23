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
- Grid responsivo na listagem (2–3 colunas).
- Barras visuais de HP/PP (battle + Center).
- Extrair partial/presenter dos painéis de batalha (remove duplicação).
- Estado ativo no nav + limpeza sistemática dos painéis (mata o hack do span).

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
| **1 — jornada visível** | contador/barra "Time n/6" (listagem + nav + team), estados do botão Add (default / "No time ✓" / cheio) | conecta o gate à descoberta; reusa `JourneyService`; precisa expor `@team_names`/`@journey_started` nos renders |
| **2 — leitura da batalha** | partial única dos painéis (+presenter), barras HP/PP, log das últimas N rodadas | mata duplicação antes de qualquer feature nova de batalha |
| **3 — estrutura** *(parcial — nav ativo + fim do hack de limpeza feitos via JN-1/sessão 0039, **validados em 2026-08-22**; grid responsivo pendente)* | estado ativo no nav + limpeza sistemática de painéis, grid responsivo da listagem | polimento estrutural; depende só de CSS/markup |
| Dependentes da fila | JN-2 (golpes em lista), JN-1 (telas próprias), JN-4 (componentes Mart/Center), J3 (ranking S–F), J4 (nome/apelido) | ordem fechada em 2026-08-18 mantida |

Regras: cada onda = refinamento (fase 1) próprio quando virar sessão; wireframes
alvo em `docs/screens/` já servem de base para os critérios. Tokens visuais
necessários às ondas 0–2 estão anotados em `draft-design-system.md`.
**Decisão do usuário (2026-08-22):** ondas 0–3 entram **depois da fila fechada**
(JN-2 → J3 → JN-1), na ordem da tabela; contador n/6 em nav + listagem/team;
gerenciar time permanece livre pré-jornada (detalhes no `draft-wireframes.md` §8).

---
