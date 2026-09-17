#!/usr/bin/env bash
set -euo pipefail

# Instala o framework SDD (spec-driven development) num projeto.
# Copia o esqueleto de sdd/skeleton/, substitui os placeholders `{{...}}` e anexa as
# regras de workflow no AGENTS.md do alvo (idempotente).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKELETON_DIR="$SCRIPT_DIR/skeleton"
MARKER_START="# --- SDD workflow rules (SDD Kit) ---"
MARKER_END="# --- fim SDD workflow rules ---"

usage() {
  cat <<'EOF'
Uso: sdd/install.sh [DIR_ALVO] [opções]

Instala o framework SDD no projeto em DIR_ALVO (default: diretório atual).
Cria/atualiza: REQUIREMENTS.md, SESSIONS.md, STACK.md, sessions/ (template.md +
sessão 0001) e os scripts de apoio em scripts/ (check_docs, levantar-roadmap,
iniciar-sessao, levantar-sessao, levantar-requisito, levantar-testes, checar-sessao,
resumo-commit), e anexa as regras em AGENTS.md.

Opções:
  --projeto "Nome"    nome do projeto ({PROJETO}; default: basename do DIR_ALVO)
  --proxima "texto"   texto da seção "Próxima sessão" (default: "0001 — Incremento inicial")
  --primeira "nome"   nome da 1ª sessão (default: "Incremento inicial")
  --force             sobrescreve arquivos existentes
  --no-agents         não altera o AGENTS.md
  --with-indexing     instala tooling/INDEX-FIRST.md + adapters/graphify-cbm-zvec.md (opt-in)
  --with-context-mode instala tooling/adapters/context-mode.md + adapters/ai-memory.md (opt-in)
  --with-stack        (obsoleto — STACK.md já é instalado por padrão; flag no-op)
  --with-extra-commands instala commands/iniciar-sessao.md + levantar-roadmap.md e agents/optional/debugger.md (opt-in)
  --with-pr           instala o modo PR (entrega da sessão = PR/MR): docs/pr/ (template, exemplo,
                      README), scripts/checar-pr e abrir-pr, sessions/pr/ e os blocos de regras do
                      modo anexados a AGENTS.md e sessions/template.md (opt-in)
  -h, --help          mostra esta ajuda

Render: o install substitui os globais {{PROJETO}}, {{PRÓXIMA_SESSAO}}, {{ROOT}},
{{DRAFT_PATH}}, {{GOTCHAS_PATH}} e {{INDEX}} (derivados do alvo) — e NNNN/NOME/DATA/slug
na sessão 0001. Os tokens de área do STACK.md e os slots de prosa do sessions/template.md
são preenchidos à mão, por projeto.
EOF
}

TARGET=""
PROJETO=""
PROXIMA=""
PRIMEIRA=""
FORCE=0
DO_AGENTS=1
WITH_INDEXING=0
WITH_CONTEXT_MODE=0
WITH_STACK=0
WITH_EXTRA_COMMANDS=0
WITH_PR=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1 ;;
    --no-agents) DO_AGENTS=0 ;;
    --with-indexing) WITH_INDEXING=1 ;;
    --with-context-mode) WITH_CONTEXT_MODE=1 ;;
    --with-stack) WITH_STACK=1 ;;
    --with-extra-commands) WITH_EXTRA_COMMANDS=1 ;;
    --with-pr) WITH_PR=1 ;;
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

# --- valores derivados do alvo (globais de render, ver render()) ---
# Derivações do que o install sabe sozinho: sem elas os tokens ficavam literais no
# projeto instalado e eram preenchidos à mão — e o `--force` revertia o preenchimento.
ROOT="$TARGET"                                     # dir alvo, absoluto
DRAFT_PATH="$ROOT/docs/draft-backlog.md"           # catálogo fora do fluxo
GOTCHAS_PATH="$ROOT/gotchas/"                      # lições/pitfalls da sessão
INDEX="$PROJETO"                                   # nome do índice de código (ajuste por projeto)

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
    # Ordem definida: ROOT primeiro, depois os derivados dele (DRAFT_PATH/GOTCHAS_PATH).
    # Hoje DRAFT_PATH/GOTCHAS_PATH já chegam expandidos do shell, mas se um deles virar
    # literal '{{ROOT}}/...' a regra de ROOT tem de vir antes para o valor não sair
    # meio-substituído ('{{ROOT}}/docs/...' no arquivo instalado).
    printf 's#%s#%s#g\n' "$(esc_pattern '{{ROOT}}')" "$(esc_repl "$ROOT")"
    printf 's#%s#%s#g\n' "$(esc_pattern '{{DRAFT_PATH}}')" "$(esc_repl "$DRAFT_PATH")"
    printf 's#%s#%s#g\n' "$(esc_pattern '{{GOTCHAS_PATH}}')" "$(esc_repl "$GOTCHAS_PATH")"
    printf 's#%s#%s#g\n' "$(esc_pattern '{{INDEX}}')" "$(esc_repl "$INDEX")"
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
# STACK.md é default (não opt-in): o skeleton delega a ele ("conforme o STACK.md"),
# então instalá-lo só com --with-stack deixava AGENTS.md/agents apontando para um
# arquivo inexistente. Cria se faltar, mas NUNCA sobrescreve — nem com --force,
# que reverteria a especialização da stack do projeto.
if [ ! -e "$TARGET/STACK.md" ]; then
  echo "install> criando: $TARGET/STACK.md"
  render "$SKELETON_DIR/STACK.md" "$TARGET/STACK.md"
else
  echo "install> já existe, mantendo: $TARGET/STACK.md (template em skeleton/STACK.md)"
fi
# template.md fica como referência (NNNN/NOME/DATA/slug permanecem placeholders)
install_file "$SKELETON_DIR/sessions/template.md" "$TARGET/sessions/template.md"
# primeira sessão já instanciada (check_docs precisa dela + da linha 0001)
install_file "$SKELETON_DIR/sessions/template.md" \
  "$TARGET/sessions/0001-primeiro-incremento.md" \
  "NNNN=0001" "NOME=$PRIMEIRA" "DATA=$TODAY" "slug=primeiro-incremento"

mkdir -p "$TARGET/scripts"
for s in check_docs levantar-roadmap iniciar-sessao levantar-sessao \
         levantar-requisito levantar-testes checar-sessao resumo-commit; do
  install_file "$SKELETON_DIR/scripts/$s" "$TARGET/scripts/$s"
  chmod +x "$TARGET/scripts/$s" 2>/dev/null || true
done

# --- agents de papel (subagents do opencode) ---
mkdir -p "$TARGET/.opencode/agent"
for a in refinador implementador-teste revisor playtester; do
  install_file "$SKELETON_DIR/agents/$a.md" "$TARGET/.opencode/agent/$a.md"
done

# --- command orquestrador de sessão + skill sdd ---
mkdir -p "$TARGET/.opencode/commands" "$TARGET/.opencode/skills/sdd"
install_file "$SKELETON_DIR/commands/sessao.md" "$TARGET/.opencode/commands/sessao.md"
install_file "$SKELETON_DIR/skills/sdd/SKILL.md" "$TARGET/.opencode/skills/sdd/SKILL.md"

# --- perfis opt-in (default off = comportamento atual) ---
if [ "$WITH_INDEXING" -eq 1 ]; then
  mkdir -p "$TARGET/tooling/adapters"
  install_file "$SKELETON_DIR/tooling/INDEX-FIRST.md" "$TARGET/tooling/INDEX-FIRST.md"
  install_file "$SKELETON_DIR/tooling/adapters/graphify-cbm-zvec.md" "$TARGET/tooling/adapters/graphify-cbm-zvec.md"
fi

if [ "$WITH_CONTEXT_MODE" -eq 1 ]; then
  mkdir -p "$TARGET/tooling/adapters"
  install_file "$SKELETON_DIR/tooling/adapters/context-mode.md" "$TARGET/tooling/adapters/context-mode.md"
  install_file "$SKELETON_DIR/tooling/adapters/ai-memory.md" "$TARGET/tooling/adapters/ai-memory.md"
fi

if [ "$WITH_STACK" -eq 1 ]; then
  # --with-stack virou default (ver bloco "artefatos do projeto"). Flag mantida
  # como no-op para não quebrar invocações existentes.
  echo "install> --with-stack é o default agora (STACK.md sempre instalado); flag ignorada."
fi

if [ "$WITH_EXTRA_COMMANDS" -eq 1 ]; then
  install_file "$SKELETON_DIR/commands/iniciar-sessao.md" "$TARGET/.opencode/commands/iniciar-sessao.md"
  install_file "$SKELETON_DIR/commands/levantar-roadmap.md" "$TARGET/.opencode/commands/levantar-roadmap.md"
  mkdir -p "$TARGET/.opencode/agent/optional"
  install_file "$SKELETON_DIR/agents/optional/debugger.md" "$TARGET/.opencode/agent/optional/debugger.md"
fi

# --- AGENTS.md: cria se faltar, ou anexa as regras de workflow (idempotente) ---
# Nunca sobrescreve AGENTS.md (nem com --force): depois da primeira instalação ele é do
# usuário. Mas se o arquivo NÃO existe, ele é criado com as regras — instalar tudo menos
# a metodologia (S1–S7) e seguir em silêncio deixava o kit inerte.
if [ "$DO_AGENTS" -eq 1 ]; then
  AGENTS="$TARGET/AGENTS.md"
  if grep -qF "$MARKER_START" "$AGENTS" 2>/dev/null; then
    echo "install> AGENTS.md já contém as regras SDD, pulando."
  else
    agents_tmp="$(mktemp "${TMPDIR:-/tmp}/sdd-agents.XXXXXX")"
    render "$SKELETON_DIR/AGENTS.md" "$agents_tmp"
    if [ -e "$AGENTS" ]; then
      {
        printf '\n%s\n' "$MARKER_START"
        cat "$agents_tmp"
        printf '%s\n' "$MARKER_END"
      } >> "$AGENTS"
      echo "install> regras SDD anexadas ao fim de: $AGENTS"
    else
      {
        printf '%s\n' "$MARKER_START"
        cat "$agents_tmp"
        printf '%s\n' "$MARKER_END"
      } > "$AGENTS"
      echo "install> criando: $AGENTS (com as regras SDD)"
    fi
    rm -f "$agents_tmp"
  fi
else
  echo "install> --no-agents: AGENTS.md não foi alterado — as regras SDD NÃO foram gravadas nele."
fi

# --- perfil opt-in --with-pr (modo PR: a entrega da sessão é o PR/MR) ---
# Só com a flag: sem ela, nenhum arquivo, diretório ou script do modo entra no alvo.
if [ "$WITH_PR" -eq 1 ]; then
  mkdir -p "$TARGET/docs/pr" "$TARGET/sessions/pr"
  # create-only, mesmo padrão do STACK.md: template/exemplo/README já customizados pelo
  # projeto nunca são revertidos — nem com --force.
  for f in TEMPLATE-pr-body.md EXEMPLO-pr-body.md README.md; do
    if [ ! -e "$TARGET/docs/pr/$f" ]; then
      echo "install> criando: $TARGET/docs/pr/$f"
      render "$SKELETON_DIR/pr/$f" "$TARGET/docs/pr/$f"
    else
      echo "install> já existe, mantendo: $TARGET/docs/pr/$f (template em skeleton/pr/$f)"
    fi
  done
  for s in checar-pr abrir-pr; do
    install_file "$SKELETON_DIR/scripts/$s" "$TARGET/scripts/$s"
    chmod +x "$TARGET/scripts/$s" 2>/dev/null || true
  done

  # Blocos de regras: append sob os marcadores do próprio bloco, nunca rewrite (o
  # AGENTS-block.md já traz os delimitadores `# --- SDD/PR (--with-pr) ---`/fim).
  if [ "$DO_AGENTS" -eq 1 ]; then
    AGENTS="$TARGET/AGENTS.md"
    if grep -qF '# --- SDD/PR (--with-pr) ---' "$AGENTS" 2>/dev/null; then
      echo "install> AGENTS.md já contém o bloco do modo PR, pulando."
    else
      printf '\n' >> "$AGENTS"
      cat "$SKELETON_DIR/pr/AGENTS-block.md" >> "$AGENTS"
      echo "install> bloco do modo PR anexado ao fim de: $AGENTS"
    fi
  fi

  TPL="$TARGET/sessions/template.md"
  if [ ! -f "$TPL" ]; then
    echo "install> AVISO: $TPL não existe — bloco do modo PR não anexado." >&2
  elif grep -qF '<!-- sdd-pr:bloco -->' "$TPL"; then
    echo "install> sessions/template.md já contém o bloco do modo PR, pulando."
  else
    printf '\n' >> "$TPL"
    cat "$SKELETON_DIR/pr/sessions-template-block.md" >> "$TPL"
    echo "install> bloco do modo PR anexado ao fim de: $TPL"
  fi

  # Modo degradado honesto (aviso, não erro): o kit não detecta plataforma, então sem a
  # CLI da plataforma o abrir-pr imprime o comando exato em vez de abrir o PR.
  if ! command -v gh >/dev/null 2>&1; then
    echo "install> AVISO: 'gh' não está no PATH — ./scripts/abrir-pr vai operar em modo degradado" >&2
    echo "install>   (imprime o corpo e o comando exato). Para outra plataforma, ajuste a linha" >&2
    echo "install>   PR_CMD do bloco do modo PR em AGENTS.md (GitLab: glab)." >&2
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

# --- verificação do modo PR: o exemplo embarcado tem de passar no próprio portão ---
if [ "$WITH_PR" -eq 1 ] && [ -x "$TARGET/scripts/checar-pr" ]; then
  echo "install> verificando o corpo de PR de exemplo:"
  (cd "$TARGET" && ./scripts/checar-pr --exemplo) || {
    echo "install> ERRO: docs/pr/EXEMPLO-pr-body.md não passa em ./scripts/checar-pr --exemplo." >&2
    echo "install> corrija o exemplo (ou remova o arquivo) e rode o install de novo." >&2
    exit 1
  }
fi

echo "install> SDD instalado em $TARGET (projeto '$PROJETO')."
echo "install> Próximo: edite REQUIREMENTS.md (Visão/Stack), refine a sessão 0001 em sessions/0001-primeiro-incremento.md e commit o refinamento atualizando SESSIONS.md (S4)."

# Última saída do install: o modo PR sem o marcador em AGENTS.md é inerte, e o usuário
# não pode descobrir isso só quando o checar-pr falhar.
if [ "$WITH_PR" -eq 1 ] && [ "$DO_AGENTS" -eq 0 ]; then
  echo >&2
  echo "install> AVISO: --no-agents com --with-pr — o modo PR ficou INERTE." >&2
  echo "install>   O marcador '<!-- sdd-pr: ativo -->' em AGENTS.md é a única fonte de verdade do" >&2
  echo "install>   modo: sem ele, ./scripts/checar-pr e ./scripts/abrir-pr falham alto e nenhuma" >&2
  echo "install>   regra de PR vale. Cole o bloco de skeleton/pr/AGENTS-block.md à mão em AGENTS.md," >&2
  echo "install>   ou rode de novo: install.sh <DIR> --with-pr (sem --no-agents)." >&2
fi