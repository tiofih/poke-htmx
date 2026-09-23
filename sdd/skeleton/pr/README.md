# Modo PR (`--with-pr`)

Instalado por `install.sh --with-pr`. Com ele, **a entrega de toda sessão é um PR/MR** e a fase 3
(validação) passa a ser a **revisão do PR** — o validador continua sendo o usuário. O corpo do PR
é escrito para quem não trabalha no projeto: o que muda para quem usa o produto, o que foi
implementado, o que foi validado, o que **não** foi validado e como chegar ao estado inicial do
teste. Rastreabilidade interna fica no `## Anexo` do fim.

## O que este perfil instala

- `docs/pr/README.md` — este arquivo.
- bloco anexado ao `AGENTS.md` (marcador `sdd-pr: ativo`) — as regras do modo, autossuficientes.
- bloco anexado ao `sessions/template.md` — as declarações `Reprodução`/`E2E`/`Revisão` e onde vai o link do PR.
- `scripts/abrir-pr` (abertura do PR; sem portão de texto — o corpo é gerado do arquivo da sessão).

## Desligar o modo

Remova o bloco entre `# --- SDD/PR (--with-pr) ---` e `# --- fim SDD/PR rules ---` do `AGENTS.md`
e o script `abrir-pr` de `scripts/`. Nada nos seus docs é reescrito: `docs/pr/` e `sessions/pr/` são
aditivos e podem ficar como histórico.
