# Adapter: context-mode (optional include)

Companion to `../INDEX-FIRST.md`. Opt-in only, default off — do not
vendor the host's full routing block here (host- and version-specific).
Paste your snippet at install time under the marker below.

<!-- PASTE-YOUR-CONTEXT-MODE-ROUTING-HERE -->

## Minimal routing (when snippet is present)

1. **Think in Code.** Analyze/count/filter/transform data by writing
   code in the sandbox (`ctx_execute` / `ctx_execute_file`); only
   printed output enters context. Never read raw dumps into context.
2. **GATHER:** `ctx_batch_execute(commands, queries)` — one call runs
   all commands, auto-indexes output, returns matching sections.
3. **FOLLOW-UP:** `ctx_search(queries: [...])` — all follow-up
   questions as one array call.
4. **PROCESSING:** `ctx_execute` / `ctx_execute_file` — sandbox only.
5. **WEB:** `ctx_fetch_and_index(url, source)` then `ctx_search` —
   raw page bytes never enter context.

## Rules

- Shell stays for mutations and short fixed output (`git`, `mkdir`,
  `rm`, `mv`, `ls`); everything else routes through the sandbox.
- Reading to **edit** uses direct reads (exact bytes for matching);
  reading to **analyze/explore/summarize** uses `ctx_execute_file`.
- Direct web fetch / inline HTTP in sandbox is blocked — route via
  `ctx_fetch_and_index`, then search.
- Write artifacts to files; return path + 1-line description.
