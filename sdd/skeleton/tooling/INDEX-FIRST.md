# INDEX-FIRST — index-first discipline core (optional include)

Tool-agnostic core. Concrete tool names, index names, paths, and measured
numbers live in `tooling/adapters/*.md` — never here. Include this file when
the project has any code index; skip it when working index-free.

## Rules

1. **Definitions before text search.** Resolve symbols via the index first
   (definition lookup), then callers/callees, then the exact snippet for each
   cited symbol. Brute text search is the last resort, for literals, error
   messages, configs, and non-code files only.
2. **Coverage check before trust.** Validate every cited path and every
   negative/exhaustive claim against the index coverage report. On
   partial/skipped/stale/unknown coverage, read or text-search the reported
   ranges before relying on index results. Absence of a gap flag is not proof
   of completeness.
3. **Orchestrator injects context into children.** Child agents do not inherit
   tool sessions. Before dispatching, the orchestrator runs the index queries
   in the parent and injects into the child prompt: evidence tier, pagination
   state, qualified symbol names, paths, call-chain findings, coverage
   evidence, and unresolved questions.

## Evidence tiers

- **Scout:** quick positive lookup, few calls, targeted source checks.
  Provisional; no negative or exhaustive claims.
- **Verify (default):** task-directed evidence, relevant call directions,
  exact snippets for material claims, relevant pagination.
- **Auditor:** bounded-scope full verification, complete pagination, both
  call directions, every limitation disclosed.
