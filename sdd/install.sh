#!/usr/bin/env bash
set -euo pipefail

# Instala o framework SDD (spec-driven development) num projeto.
# Copia o esqueleto de sdd/skeleton/, substitui {{TOKENS}} e anexa as regras de
# workflow no AGENTS.md do alvo (idempotente).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKELETON_DIR="$SCRIPT_DIR/skeleton"
MARKER_START="# --- SDD workflow rules (SDD Kit) ---"
MARKER_END="# --- fim SDD workflow rules ---"

usage() {
  cat <<'EOF'
Uso: sdd/install.sh [DIR_ALVO] [opções]

Instala o framework SDD no projeto em DIR_ALVO (default: diretório atual).
Cria/atualiza: REQUIREMENTS.md, SESSIONS.md, sessions/ (template.md + sessão 0001),
scripts/check_docs e anexa as regras em AGENTS.md.

Opções:
  --projeto "Nome"    nome do projeto ({PROJETO}; default: basename do DIR_ALVO)
  --proxima "texto"   texto da seção "Próxima sessão" (default: "0001 — Incremento inicial")
  --primeira "nome"   nome da 1ª sessão (default: "Incremento inicial")
  --force             sobrescreve arquivos existentes
  --no-agents         não altera o AGENTS.md
  -h, --help          mostra esta ajuda
EOF
}

TARGET=""
PROJETO=""
PROXIMA=""
PRIMEIRA=""
FORCE=0
DO_AGENTS=1

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1 ;;
    --no-agents) DO_AGENTS=0 ;;
    --projeto) PROJETO="${2:-}"; shift ;;
    --proxima) PROXIMA="${2:-}"; shift ;;
    --primeira) PRIMEIRA="${2:-}"; shift ;;
    -*) echo "opção desconhecida: $1" >&2; usage; exit 2 ;;
    *)
      if [ -z "$TARGET" ]; then
        TARGET="$1"
      else
        echo "muitos argumentos posicionais: $1" >&2; usage; exit 2
      fi
      ;;
  esac
  shift
done

TARGET="${TARGET:-.}"
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

if [ -z "$PROJETO" ]; then
  if [ -t 0 ]; then
    printf 'Nome do projeto (%s): ' "$(basename "$TARGET")"
    read -r PROJETO
  fi
  PROJETO="${PROJETO:-$(basename "$TARGET")}"
fi
PROXIMA="${PROXIMA:-0001 — Incremento inicial}"
PRIMEIRA="${PRIMEIRA:-Incremento inicial}"
TODAY="$(date +%Y-%m-%d)"

# --- renderização de templates (delimitador sed '#') ---
esc_pattern() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//#/\\#}"
  printf '%s\n' "$s"
}
esc_repl() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//&/\\&}"
  s="${s//#/\\#}"
  printf '%s\n' "$s"
}

render() { # src dst [key=value ...]
  local src="$1" dst="$2"
  shift 2
  local tmp="$(mktemp "${TMPDIR:-/tmp}/sdd-render.XXXXXX")"
  {
    printf 's#%s#%s#g\n' "$(esc_pattern '{{PROJETO}}')" "$(esc_repl "$PROJETO")"
    printf 's#%s#%s#g\n' "$(esc_pattern '{{PRÓXIMA_SESSAO}}')" "$(esc_repl "$PROXIMA")"
    local kv key val
    for kv in "$@"; do
      key="${kv%%=*}"; val="${kv#*=}"
      printf 's#%s#%s#g\n' "$(esc_pattern "{{$key}}")" "$(esc_repl "$val")"
    done
  } > "$tmp"
  sed -f "$tmp" "$src" > "$dst"
  rm -f "$tmp"
}

install_file() { # src dst [key=value ...]
  local src="$1" dst="$2"
  shift 2
  if [ -e "$dst" ]; then
    if [ "$FORCE" -eq 1 ]; then
      echo "install> sobrescrevendo (--force): $dst"
    else
      echo "install> já existe, pulando: $dst (use --force para sobrescrever)"
      return
    fi
  else
    echo "install> criando: $dst"
  fi
  render "$src" "$dst" "$@"
}

# --- artefatos do projeto ---
mkdir -p "$TARGET/sessions"
install_file "$SKELETON_DIR/REQUIREMENTS.md" "$TARGET/REQUIREMENTS.md"
install_file "$SKELETON_DIR/SESSIONS.md" "$TARGET/SESSIONS.md"
# template.md fica como referência (NNNN/NOME/DATA/slug permanecem placeholders)
install_file "$SKELETON_DIR/sessions/template.md" "$TARGET/sessions/template.md"
# primeira sessão já instanciada (check_docs precisa dela + da linha 0001)
install_file "$SKELETON_DIR/sessions/template.md" \
  "$TARGET/sessions/0001-primeiro-incremento.md" \
  "NNNN=0001" "NOME=$PRIMEIRA" "DATA=$TODAY" "slug=primeiro-incremento"

mkdir -p "$TARGET/scripts"
install_file "$SKELETON_DIR/scripts/check_docs" "$TARGET/scripts/check_docs"
chmod +x "$TARGET/scripts/check_docs" 2>/dev/null || true

# --- AGENTS.md: anexa as regras de workflow (idempotente) ---
if [ "$DO_AGENTS" -eq 1 ]; then
  AGENTS="$TARGET/AGENTS.md"
  if grep -qF "$MARKER_START" "$AGENTS" 2>/dev/null; then
    echo "install> AGENTS.md já contém as regras SDD, pulando."
  elif [ -f "$AGENTS" ]; then
    agents_tmp="$(mktemp "${TMPDIR:-/tmp}/sdd-agents.XXXXXX")"
    render "$SKELETON_DIR/AGENTS.md" "$agents_tmp"
    {
      printf '\n%s\n' "$MARKER_START"
      cat "$agents_tmp"
      printf '%s\n' "$MARKER_END"
    } >> "$AGENTS"
    rm -f "$agents_tmp"
    echo "install> regras SDD anexadas ao fim de: $AGENTS"
  else
    echo "install> AGENTS.md não existe — ignorado. Cole manualmente skeleton/AGENTS.md se quiser."
  fi
fi

# --- verificação ---
if [ -x "$TARGET/scripts/check_docs" ]; then
  echo "install> verificando consistência:"
  (cd "$TARGET" && ./scripts/check_docs) || {
    echo "install> AVISO: check_docs não passou — preencha a seção 'Próxima sessão'/" >&2
    echo "install> a tabela de progresso do SESSIONS.md para bater com a sessão 0001." >&2
    exit 1
  }
fi

echo "install> SDD instalado em $TARGET (projeto '$PROJETO')."
echo "install> Próximo: edite REQUIREMENTS.md (Visão/Stack), refine a sessão 0001 em sessions/0001-primeiro-incremento.md e commit o refinamento atualizando SESSIONS.md (S4)."