# Adapter: graphify + codebase-memory (CBM) + zvec-grep (optional include)

Companion to `../INDEX-FIRST.md`. Use only when the project has these
indexes available; otherwise fall back to the tool-agnostic core alone.
Fill at install time: `{{ROOT}}` = absolute project root,
`{{INDEX}}` = code index name (use one value per tool when they differ).

## Priority

1. `search_graph` — find functions/classes/routes (keep limits small for flow queries).
2. `trace_path` — callers/callees (`inbound` / `outbound` / `both`).
3. `get_code_snippet` — exact source by `qualified_name`.
4. `check_index_coverage` — validate every cited path and every
   negative/exhaustive scope before trusting the graph; on
   partial/skipped/stale/unknown coverage, read or text-search the
   reported ranges first.
5. `query_graph` (multi-hop patterns) and `get_architecture` (overview).
6. **zvec-grep** (`root: {{ROOT}}`, index `{{INDEX}}`):
   - Literal, error message, config key, exhaustive occurrences →
     `zg query --rg` before native grep.
   - Diffuse concept, docs, past sessions ("where did we discuss X?") →
     `zg query` (hybrid search).
   - Exact symbol, flow, impact → CBM first (zvec returns no canonical definition).
7. **graphify** (when the graph output directory exists in `{{ROOT}}`):
   `graphify query "<question>"`, `graphify path "<A>" "<B>"`,
   `graphify explain "<node>"`. Never read the raw graph dump.

## Rules

- Never use raw file search to explore code when a graph or index query
  answers the question. File reads serve edits (exact bytes for matching),
  not exploration.
- Native grep covers only non-code files outside the index, or cases where
  CBM + zvec return insufficient results.
- On zvec calls always pass the absolute `root: {{ROOT}}` and respect the
  returned `freshness` / `background_refresh` status.
- Orchestrator runs `search_graph` + snippet + trace + coverage in the
  parent (plus `zg query` when docs/sessions or exhaustive scope apply)
  and injects the evidence into each child prompt. Children do not inherit
  tool sessions.
