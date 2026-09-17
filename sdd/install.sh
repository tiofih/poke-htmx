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
Cria se faltarem (e NUNCA sobrescreve, nem com --force): REQUIREMENTS.md, SESSIONS.md,
STACK.md, sessions/template.md e os arquivos de .opencode/ (agentes de papel, comando
/sessao e skill sdd).
Cria: sessions/ (a sessão 0001 só num projeto que ainda não tem sessões) e os scripts
de apoio em scripts/ (check_docs, levantar-roadmap, iniciar-sessao, levantar-sessao,
levantar-requisito, levantar-testes, checar-sessao, resumo-commit), e anexa as regras
em AGENTS.md.

Opções:
  --projeto "Nome"    nome do projeto ({PROJETO}; default: basename do DIR_ALVO)
  --proxima "texto"   texto da seção "Próxima sessão" (default: "0001 — Incremento inicial")
  --primeira "nome"   nome da 1ª sessão (default: "Incremento inicial")
  --force             sobrescreve os arquivos do kit já existentes — exceto
                      REQUIREMENTS.md, SESSIONS.md, STACK.md, AGENTS.md,
                      sessions/template.md e .opencode/**, que são create-only
                      (criados se faltarem, nunca sobrescritos)
  --no-agents         não altera o AGENTS.md
  --with-indexing     instala tooling/INDEX-FIRST.md + adapters/graphify-cbm-zvec.md (opt-in)
  --with-context-mode instala tooling/adapters/context-mode.md + adapters/ai-memory.md (opt-in)
  --with-stack        (obsoleto — STACK.md já é instalado por padrão; flag no-op)
  --with-extra-commands instala commands/iniciar-sessao.md + levantar-roadmap.md e agents/optional/debugger.md (opt-in)
  --with-pr           instala o modo PR (entrega da sessão = PR/MR): docs/pr/ (template, exemplo,
                      README), scripts/checar-pr e abrir-pr, sessions/pr/ e os blocos de regras do
                      modo anexados a AGENTS.md e sessions/template.md (opt-in)
  --with-arquiteto    instala o papel de desenho técnico (fase 1b, opcional, read-only):
                      skeleton/agents/optional/arquiteto.md → .opencode/agent/arquiteto.md
                      (create-only) + blocos de invocação anexados a .opencode/skills/sdd/SKILL.md
                      e .opencode/commands/sessao.md. Não toca AGENTS.md. As dependências estão
                      declaradas no próprio agente (## Dependências) — o install avisa o que falta,
                      sem falhar (opt-in)
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
WITH_ARQUITETO=0
# Destinos que o --force substituiu apesar de DIVERGIREM do conteúdo renderizado do kit
# (byte a byte). Ver install_file(): a divergência costuma ser adaptação local do projeto
# pós-instalação, que o kit genérico não tem. Resumo no fim do install.
FORCE_REPLACED=()

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
    --with-arquiteto) WITH_ARQUITETO=1 ;;
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
      # Compara o resultado RENDERIZADO com o arquivo instalado. Comparar o skeleton-fonte
      # não serve: os placeholders {{...}} só existem na origem e fariam TODO arquivo
      # parecer divergente. Byte a byte (cmp) basta e não precisa de dependência; igual =
      # nada a avisar, divergente = o --force vai trocar conteúdo (quase sempre adaptação
      # local pós-instalação) pelo texto genérico do kit.
      local probe
      probe="$(mktemp "${TMPDIR:-/tmp}/sdd-probe.XXXXXX")"
      render "$src" "$probe" "$@"
      if cmp -s "$probe" "$dst"; then
        echo "install> sobrescrevendo (--force): $dst"
      else
        echo "install> ATENÇÃO: $dst difere do kit instalado — substituindo (--force); a cópia atual será perdida"
        FORCE_REPLACED+=("$dst")
      fi
      rm -f "$probe"
    else
      echo "install> já existe, pulando: $dst (use --force para sobrescrever)"
      return
    fi
  else
    echo "install> criando: $dst"
  fi
  render "$src" "$dst" "$@"
}

# Create-only: cria se faltar, NUNCA sobrescreve (nem com --force). O destino é conteúdo
# do PROJETO depois da primeira instalação (slots de prosa preenchidos à mão, adaptação
# local dos papéis/comandos), e o --force o reverteria para o texto neutro do kit. Efeito
# colateral aceito: melhorias futuras do kit nesses arquivos NÃO chegam sozinhas — o
# projeto faz o merge à mão (o `sdd/` fica no repo via subtree justamente para isso).
install_create_only() { # src dst [key=value ...]
  local src="$1" dst="$2"
  shift 2
  if [ -e "$dst" ]; then
    echo "install> já existe, mantendo: $dst (template em ${src#"$SCRIPT_DIR"/})"
    return
  fi
  echo "install> criando: $dst"
  render "$src" "$dst" "$@"
}

# Anexa um bloco delimitado por marcador ao FIM de um arquivo já instalado, idempotente.
# Nunca reescreve o arquivo-base: só acrescenta o conteúdo do bloco (que já traz os próprios
# marcadores de abertura/fechamento) — é o único jeito de o papel/bloco aparecer num projeto
# que já tinha o kit (a cópia dele desses arquivos é create-only). `marker` é a âncora de
# idempotência. Destino ausente = aviso, não erro (o arquivo-base tem outro caminho de install).
install_block() { # src dst marker [rotulo]
  local src="$1" dst="$2" marker="$3" rot="${4:-$(basename "$2")}"
  if [ ! -f "$dst" ]; then
    echo "install> AVISO: $dst não existe — bloco '$rot' não anexado." >&2
  elif grep -qF "$marker" "$dst"; then
    echo "install> $rot já contém o bloco, pulando."
  else
    printf '\n' >> "$dst"
    cat "$src" >> "$dst"
    echo "install> bloco '$rot' anexado ao fim de: $dst"
  fi
}

# --- artefatos do projeto ---
mkdir -p "$TARGET/sessions"
# REQUIREMENTS.md/SESSIONS.md são do usuário depois da primeira instalação: é onde ele
# escreve os requisitos reais e o histórico das sessões. Mesmo tratamento do STACK.md
# (abaixo): cria se faltar, mas NUNCA sobrescreve — nem com --force, que trocava os
# arquivos maduros pelos stubs do skeleton (perda de requisitos e de histórico).
if [ ! -e "$TARGET/REQUIREMENTS.md" ]; then
  echo "install> criando: $TARGET/REQUIREMENTS.md"
  render "$SKELETON_DIR/REQUIREMENTS.md" "$TARGET/REQUIREMENTS.md"
else
  echo "install> já existe, mantendo: $TARGET/REQUIREMENTS.md (template em skeleton/REQUIREMENTS.md)"
fi
if [ ! -e "$TARGET/SESSIONS.md" ]; then
  echo "install> criando: $TARGET/SESSIONS.md"
  render "$SKELETON_DIR/SESSIONS.md" "$TARGET/SESSIONS.md"
else
  echo "install> já existe, mantendo: $TARGET/SESSIONS.md (template em skeleton/SESSIONS.md)"
fi
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
# template.md: create-only, como os quatro acima. A usage documenta que os slots de prosa
# dele são preenchidos À MÃO, por projeto — então o --force revertia texto do próprio
# projeto (2 slots preenchidos → 0). Trade-off aceito: melhorias do kit no template não
# chegam sozinhas ao projeto (merge à mão). Se um dia o kit precisar de trecho de template
# que DEVE refrescar, use o padrão que o --with-pr já usa nesta linha: bloco delimitado por
# marcador (`<!-- sdd-pr:bloco -->`) anexado ao fim, sem tocar na prosa acima.
install_create_only "$SKELETON_DIR/sessions/template.md" "$TARGET/sessions/template.md"
# primeira sessão já instanciada (check_docs precisa dela + da linha 0001) — mas só num
# projeto que ainda não tem sessões: num repo maduro a 0001 nasceria órfã, sem linha na
# tabela do SESSIONS.md, e ainda mexeria com a S5c, que exige a MAIOR sessão na seção
# "Próxima sessão". Condição = a MESMA glob que o check_docs usa para achar sessões.
created_0001=0
existing_sessions=("$TARGET/sessions"/[0-9][0-9][0-9][0-9]-*.md)
if [ ! -e "${existing_sessions[0]}" ]; then
  install_file "$SKELETON_DIR/sessions/template.md" \
    "$TARGET/sessions/0001-primeiro-incremento.md" \
    "NNNN=0001" "NOME=$PRIMEIRA" "DATA=$TODAY" "slug=primeiro-incremento"
  created_0001=1
else
  echo "install> já existem sessões, não criando a 0001: $TARGET/sessions/ (template em skeleton/sessions/)"
fi

mkdir -p "$TARGET/scripts"
for s in check_docs levantar-roadmap iniciar-sessao levantar-sessao \
         levantar-requisito levantar-testes checar-sessao resumo-commit; do
  install_file "$SKELETON_DIR/scripts/$s" "$TARGET/scripts/$s"
  chmod +x "$TARGET/scripts/$s" 2>/dev/null || true
done

# --- agents de papel (subagents do opencode) ---
# .opencode/** é create-only: num consumidor real esses arquivos carregam adaptação pesada
# que o kit neutro não tem (papel extra, prompt orquestrador, protocolo graph-first,
# model/permission por agente). O --force ali não é update, é REGRESSÃO — troca o arquivo
# adaptado pelo default do kit. Trade-off: melhoria do kit nos defaults dos papéis passa a
# exigir merge à mão.
mkdir -p "$TARGET/.opencode/agent"
for a in refinador implementador-teste revisor playtester; do
  install_create_only "$SKELETON_DIR/agents/$a.md" "$TARGET/.opencode/agent/$a.md"
done

# --- command orquestrador de sessão + skill sdd ---
mkdir -p "$TARGET/.opencode/commands" "$TARGET/.opencode/skills/sdd"
install_create_only "$SKELETON_DIR/commands/sessao.md" "$TARGET/.opencode/commands/sessao.md"
install_create_only "$SKELETON_DIR/skills/sdd/SKILL.md" "$TARGET/.opencode/skills/sdd/SKILL.md"

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
  install_create_only "$SKELETON_DIR/commands/iniciar-sessao.md" "$TARGET/.opencode/commands/iniciar-sessao.md"
  install_create_only "$SKELETON_DIR/commands/levantar-roadmap.md" "$TARGET/.opencode/commands/levantar-roadmap.md"
  mkdir -p "$TARGET/.opencode/agent/optional"
  install_create_only "$SKELETON_DIR/agents/optional/debugger.md" "$TARGET/.opencode/agent/optional/debugger.md"
fi

# --- perfil opt-in --with-arquiteto (fase 1b: desenho técnico, opcional) ---
# Só com a flag. O papel é um agente a MAIS (não muda regra S nem o PROTOCOL.md — fase 1b é
# passo opcional, sem portão) e por isso NÃO toca AGENTS.md. Ordem: arquivo do agente
# (create-only) → blocos de invocação (append sob marcador) → avisos de dependência.
if [ "$WITH_ARQUITETO" -eq 1 ]; then
  # create-only: depois da 1ª instalação o papel é do projeto (ele pode adaptar o prompt);
  # o --force NÃO o reverte (ver install_create_only). Vai FLAT em .opencode/agent/.
  install_create_only "$SKELETON_DIR/agents/optional/arquiteto.md" "$TARGET/.opencode/agent/arquiteto.md"

  # Invocação por bloco anexado sob os próprios marcadores `<!-- sdd-arquiteto:bloco -->`,
  # idempotente, sem tocar na tabela/prosa acima. Os blocos são autossuficientes (têm o
  # portão "só dispare se .opencode/agent/arquiteto.md existir").
  install_block "$SKELETON_DIR/arquiteto/SKILL-block.md" \
    "$TARGET/.opencode/skills/sdd/SKILL.md" '<!-- sdd-arquiteto:bloco -->' "skills/sdd/SKILL.md"
  install_block "$SKELETON_DIR/arquiteto/sessao-block.md" \
    "$TARGET/.opencode/commands/sessao.md" '<!-- sdd-arquiteto:bloco -->' "commands/sessao.md"

  # Aviso de dependência: NUNCA erro (exit != 0 por dependência ausente quebraria o install de
  # um projeto que legitimamente roda sem índice) e NUNCA claim de MCP alcançável — offline, um
  # shell só confere presença de arquivo/config no disco. Cada linha diz o que DEGRADA; o detalhe
  # canônico é o bloco `## Dependências` do próprio agente.
  aviso_arq() { echo "install> AVISO: $1 ausente — arquiteto: $2" >&2; }
  # Áreas = linha `**Paths:**` PREENCHIDA (sem placeholder `{{...}}`): o skeleton sem preencher
  # tem `- **Paths:** \`{{PATHS_*}}\`` e não conta — senão o aviso nunca sairia num projeto real.
  grep -E '^[-*]? ?\*\*Paths:\*\*' "$TARGET/STACK.md" 2>/dev/null | grep -qv '{{' \
    || aviso_arq "áreas no STACK.md" "devolve UMA fatia + 'areas: desconhecidas'"
  { [ -e "$TARGET/tooling/INDEX-FIRST.md" ] || [ -d "$TARGET/graphify-out" ] \
    || [ -d "$TARGET/.codebase-memory" ]; } \
    || aviso_arq "índice/grafo (--with-indexing)" "lê a fonte direto; 'descoberta: leitura direta, tier: Scout'"
  grep -q 'ai-memory:start' "$TARGET/AGENTS.md" "$TARGET/CLAUDE.md" 2>/dev/null \
    || aviso_arq "ai-memory (--with-context-mode)" "contexto só pelo prompt; não grava memória"
  grep -q 'context-mode' "$TARGET/AGENTS.md" "$TARGET/opencode.json" 2>/dev/null \
    || aviso_arq "context-mode (--with-context-mode)" "análise ampla entra crua; cita arquivo:linha"
  echo "install>   (detalhe por dependência: .opencode/agent/arquiteto.md § Dependências)" >&2
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

# Resumo do --force: quantos arquivos divergentes foram substituídos e quais. O aviso
# per-file do install_file aparece na hora, mas espalhado no log; este bloco fecha a
# execução com o número e a lista (a categoria já é o 1º segmento do caminho relativo).
if [ "${#FORCE_REPLACED[@]}" -gt 0 ]; then
  echo >&2
  echo "install> AVISO: --force substituiu ${#FORCE_REPLACED[@]} arquivo(s) que divergiam do kit:" >&2
  for f in "${FORCE_REPLACED[@]}"; do
    echo "install>   ${f#"$TARGET"/}" >&2
  done
  echo "install>   Divergir do kit costuma ser adaptação local pós-instalação; se ela era" >&2
  echo "install>   intencional, restaure-a (git/histórico) e faça o merge à mão. O kit não guarda backup." >&2
fi

echo "install> SDD instalado em $TARGET (projeto '$PROJETO')."
# A instrução depende do que ESTA execução fez: num projeto maduro a 0001 não é criada, e
# apontar para ela mandava editar um arquivo que não existe.
if [ "$created_0001" -eq 1 ]; then
  echo "install> Próximo: edite REQUIREMENTS.md (Visão/Stack), refine a sessão 0001 em sessions/0001-primeiro-incremento.md e commit o refinamento atualizando SESSIONS.md (S4)."
else
  echo "install> Próximo: abra a sessão da seção 'Próxima sessão' do SESSIONS.md (é um refresh — a 0001 não foi criada) e commit o refinamento atualizando o SESSIONS.md (S4)."
fi

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

# Fecha a lacuna da meia-ativação: o perfil PR não vive só nos arquivos dele — ele liga
# comportamento GATED A MARCADOR dentro de checar-sessao e iniciar-sessao (o marcador em
# AGENTS.md é a fonte de verdade; os scripts o consultam). Num projeto que JÁ tinha esses
# scripts, sem --force o install_file os pulou e o perfil ficou pela metade: AGENTS.md
# declara o modo, os scripts o ignoram — e o install reportava sucesso. O probe é o
# próprio literal do gate, que o kit já usa: sem dependência nova. Aviso, nunca erro (o
# install segue exit 0; a correção é re-rodar com --force).
if [ "$WITH_PR" -eq 1 ]; then
  pr_faltando=()
  for s in scripts/checar-sessao scripts/iniciar-sessao; do
    grep -qF '<!-- sdd-pr: ativo -->' "$TARGET/$s" 2>/dev/null || pr_faltando+=("$s")
  done
  if [ "${#pr_faltando[@]}" -gt 0 ]; then
    echo >&2
    echo "install> AVISO: modo PR NÃO está totalmente ativo — script(s) sem o bloco do perfil:" >&2
    for s in "${pr_faltando[@]}"; do
      echo "install>   $s" >&2
    done
    echo "install>   O marcador em AGENTS.md sozinho não liga o modo: quem o aplica são esses" >&2
    echo "install>   scripts. Atualize-os repetindo o install com --force:" >&2
    echo "install>   ./sdd/install.sh <DIR> --with-pr --force" >&2
  elif [ "$DO_AGENTS" -eq 1 ]; then
    echo "install> modo PR ativo: scripts checar-sessao/iniciar-sessao carregam o bloco do perfil."
  fi
fi