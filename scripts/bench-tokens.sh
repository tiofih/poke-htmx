#!/bin/sh
# bench-tokens.sh — snapshot de consumo do opencode.db para o benchmark de ferramentas.
# Uso: ./scripts/bench-tokens.sh before:<rotulo> | after:<rotulo>
# Roda no HOST (não no container). Acrescenta linha em docs/bench-log.csv
# O delta before→after do mesmo rótulo = custo da tarefa. Roda `oc-cost` junto p/ o dia.
# Ex.: ./scripts/bench-tokens.sh before:cce-p1 && <tarefa> && ./scripts/bench-tokens.sh after:cce-p1
set -u
DB="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"
CSV="docs/bench-log.csv"
LABEL="${1:-manual}"

if [ ! -f "$DB" ]; then echo "DB ausente: $DB" >&2; exit 1; fi
if [ ! -f "$CSV" ]; then echo "ts,label,tokens_in,tokens_out,cost" > "$CSV"; fi

ROW=$(sqlite3 -readonly "$DB" "select coalesce(sum(tokens_input),0), coalesce(sum(tokens_output),0), coalesce(sum(cost),0) from session;" 2>/dev/null)
IN=${ROW%%|*}; REST=${ROW#*|}; OUT=${REST%%|*}; COST=${REST##*|}
TS=$(date -u +%FT%TZ)
echo "$TS,$LABEL,$IN,$OUT,$COST" >> "$CSV"
echo "$TS $LABEL in=$IN out=$OUT cost=$COST (delta = after-before do mesmo rotulo)"
