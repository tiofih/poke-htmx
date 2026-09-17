# Modo PR (`--with-pr`)

Instalado por `install.sh --with-pr`. Com ele, **a entrega de toda sessão é um PR/MR** e a fase 3
(validação) passa a ser a **revisão do PR** — o validador continua sendo o usuário. O corpo do PR
é escrito para quem não trabalha no projeto: o que muda para quem usa o produto, o que foi
implementado, o que foi validado, o que **não** foi validado e como chegar ao estado inicial do
teste. Rastreabilidade interna fica no `## Anexo` do fim.

## O que este perfil instala

- `docs/pr/TEMPLATE-pr-body.md` — modelo do corpo do PR. Copie para `sessions/pr/NNNN-pr-body.md`.
- `docs/pr/EXEMPLO-pr-body.md` — exemplo preenchido ponta a ponta (passa em `checar-pr --exemplo`).
- `docs/pr/README.md` — este arquivo.
- bloco anexado ao `AGENTS.md` (marcador `sdd-pr: ativo`) — as regras do modo, autossuficientes.
- bloco anexado ao `sessions/template.md` — as declarações `Reprodução`/`E2E` e onde vai o link do PR.
- `scripts/checar-pr` (portão do corpo) e `scripts/abrir-pr` (abertura do PR).

## Desligar o modo

Remova o bloco entre `# --- SDD/PR (--with-pr) ---` e `# --- fim SDD/PR rules ---` do `AGENTS.md`
e os dois scripts de `scripts/`. Nada nos seus docs é reescrito: `docs/pr/` e `sessions/pr/` são
aditivos e podem ficar como histórico.
