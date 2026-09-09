# Benchmark de ferramentas — protocolo e resultados

Objetivo: manter só o que economiza de verdade no nosso fluxo SDD.
Método: `./scripts/bench-tokens.sh before:<rotulo>` → tarefa → `after:<rotulo>`; delta = custo.

## Sondas fixas

| Sonda | Tarefa | O que mede |
|---|---|---|
| P1-recall | "fluxo POST /team → TeamRepository.add, quem chama e onde" via cada retrieval (CBM Scout, zvec hybrid, zvec rg, graphify, CCE `cce search`, ai-context `locate`) | tokens/input por ferramenta + acertou o símbolo? |
| P2-tdd | Micro-tarefa real de TDD (1 critério pequeno) com `implementador-teste`, com e sem ponytail ultra | diff (LOC) + tokens + suíte verde? |
| P3-review | Mesmo diff no `revisor`, com e sem lente ponytail | achados reais vs ruído + tokens |
| P4-prosa | Mesma pergunta explicativa com/sem caveman | output tokens |

## Baseline já medido (2026-09-09, bytes→tokens ≈ /4)

| Ferramenta | Custo | Acerto |
|---|---|---|
| grep cirúrgico | ~235 | literal só |
| zvec rg | ~193 | literal agrupado |
| zvec hybrid CLI | ~495 | docs+sessões, sem símbolo exato |
| CBM Scout | ~875 | símbolo exato + callers |
| graphify query 1500 | ~1241 | arquitetura, truncado |
| CCE `cce search` | ~163 | só git-log (commits), sem símbolo — recall fraco p/ P1 |
| ai-context router CLI | ~37 | vazio (`__ROUTER__:none`) — precisa do MCP `locate`, não wirado |
| graph.json bruto | ~1M | nunca ler |

## Stack local (pós-restart 2026-09-09)

Mantidos (100% locais, sem conta): CBM, graphify, zvec-grep, ponytail (plugin),
caveman (skills), CCE (MCP `context-engine`), ai-context Simple,
hive-mcp, chrome-devtools-mcp.
MCPs confirmados carregados: `hive`, `context-engine` (+ `zvec_grep` pré-existente).

## Removidos em 2026-09-09

- ogcode: binário `~/.local/bin`, `~/.ogcode/`, `.ogcode/` do poke, checkouts /tmp.
- Tessl: pacote + `~/.local/share/tessl`, `.tessl/`, `tessl.json`, `.github/mcp.json`,
  `.codex/` do poke.
- Ruler: pacote npm + `.ruler/` do poke.

## Cortes já decididos (só local — diretriz do usuário)

- Cloud/conta: CodeMesh comercial, HoneyHive, Firecrawl, Packmind, Xanther cloud, Bito, ogcode
  (roteia `ollama/...` pelo proxy próprio `ogcode-openrouter`, 401 sem conta) — fora.
- Clade MCP: bug upstream (`Server` sem `list_tools`) — sem wiring até corrigirem.
- Ruler: candidato a corte — sync cross-agent sem consumidor (só opencode aqui);
  `ruler apply` com o placeholder **destruiria o AGENTS.md**, então NÃO rodar apply.
  Reavaliar se adotarmos 2º agente.
- `@pyalwin/codemesh`: build nativo (gyp) quebra nesta máquina — fora.

## Resultados

Micro-tarefa `TeamRepository#count(user_id)` (diff benchmark revertido após medição).
CBM MCP caiu no meio da sessão (`Connection closed`) — P2/P3 rodaram com zvec+read.

| Data | Sonda | Ferramenta/config | in | out | $ | Veredito |
|---|---|---|---|---|---|---|
| 2026-09-09 | P2a | implementador SEM ultra | 463.923 | 2.678 | 0,0495 | controle: lib +7 (SQL duplicado), teste +14, verde |
| 2026-09-09 | P2b | implementador COM ultra | 74.017 | 2.220 | 0,0111 | **MANTER**: lib +4 (`count` delega a `team_size` privado existente), teste +17, verde — ladder degrau 2 achou reuso que P2a não viu |
| 2026-09-09 | P3a | revisor SEM lente | 75.979 | 4.129 | 0,0123 | `VEREDITO: Aprovado`, 2 sugestões |
| 2026-09-09 | P3b | revisor COM lente+ caveman | 73.509 | 2.182 | 0,0106 | `Requer ajuste` (YAGNI: `count` sem chamador nem critério SDD) + out −47% — **P4 respondida aqui**: mesma base, prosa tersa ≈ metade do output |
| 2026-09-09 | P2/P3 | overhead de subagent | — | — | — | input por sonda 73–464k: o custo do filho domina; economia de output (P4) é real mas pequena no total |

Notas: (1) P2a×P2b input difere 6× — confundido por exploração/caching do 1º filho, não só pelo ultra; o ganho sólido do ultra é qualidade (reuso), não os tokens. (2) A lente do revisor rejeitou código sem chamador — correto p/ YAGNI, mas em SDD real o critério S1 ancorado blinda o diff (o próprio P3b item 2 diz isso). (3) `TeamProgressTest` erro `ProgressionRepository` pré-existente em execução parcial, alheio às sondas.

## Critério de corte

Mantém se: economiza ≥20% vs baseline **sem** perder acerto, ou acha o que as outras não acham.
Corta se: overhead (input próprio) > economia, ou só duplica recall existente.
Gated (precisam de conta/chave do usuário): CodeMesh, HoneyHive, Firecrawl, Packmind,
Xanther, Bito — instalar quando houver chave.
