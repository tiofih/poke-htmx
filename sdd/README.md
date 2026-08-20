# SDD — Spec-Driven Development (kit portável)

Kit de **Spec-Driven Development em sessões**: especificação antes do código
(refinamento), TDD estrito e validação pelo dono do produto — com critérios de
aceite **verificáveis por teste** e documentação viva.

Este diretório é **auto-contido**: não referencia o projeto que o hospeda. Para
adotá-lo em outra base, copie o `PROTOCOL.md` + a pasta `skeleton/`; quando quiser
distribuir, este diretório pode virar um repo Git próprio sem ajustes.

## Conteúdo

| Caminho | Papel |
| --- | --- |
| `PROTOCOL.md` | Metodologia canônica: ciclo de 3 fases, donos, regras S1–S5, convenções de commit. **O ponto único de verdade do processo.** |
| `install.sh` | Instalador: copia o skeleton, substitui placeholders, anexa as regras no `AGENTS.md` e valida com o `check_docs` (idempotente). |
| `skeleton/` | Modelos para instanciar o SDD num projeto novo (copie e adapte). |
| `skeleton/AGENTS.md` | Bloco de regras para o agente/assistente seguir (cola no `AGENTS.md` do projeto). |
| `skeleton/REQUIREMENTS.md` | Stub da fonte da verdade dos requisitos (`{{PROJETO}}`). |
| `skeleton/SESSIONS.md` | Stub do registro de sessões (ciclo + tabela + "Próxima sessão"). |
| `skeleton/sessions/template.md` | Modelo do arquivo de cada sessão (as 6 seções + S1/S2). |
| `skeleton/scripts/check_docs` | Verificação de consistência (roda no host, só grep). |

## Instalação (recomendada — `install.sh`)

```bash
./sdd/install.sh /caminho/do/projeto --projeto "Meu App"
```

Cria `REQUIREMENTS.md`, `SESSIONS.md`, `sessions/` (template + sessão **0001** já
instanciada), `scripts/check_docs` e anexa as regras de workflow no `AGENTS.md` do alvo
— tudo idempotente (2ª execução pula o que existe; `--force` sobrescreve) e encerra
rodando o `check_docs` (instalação só é "sucesso" com docs consistentes).

Opções: `--proxima "texto"` (seção "Próxima sessão"), `--primeira "nome"` (nome da 1ª
sessão), `--no-agents`, `--force`. _Um diretório posicional primeiro (o alvo)._

## Instalação (manual, ~5 min)

1. Copie `skeleton/REQUIREMENTS.md`, `skeleton/SESSIONS.md` e `skeleton/scripts/` para a
   raiz do projeto novo.
2. Substitua `{{PROJETO}}` e `{{PRÓXIMA_SESSAO}}` pelos valores reais.
3. Copie `skeleton/sessions/template.md` → `sessions/0001-<slug>.md` (e mantenha o
   `template.md` como modelo para as próximas).
4. Cole o conteúdo de `skeleton/AGENTS.md` (seção "workflow rules") no `AGENTS.md`
   do projeto — ou use o `PROTOCOL.md` como guia manual.
5. Rode `./scripts/check_docs` a cada transição de fase (refinamento/validação).

## Criando a sessão N

1. Copie `template.md` → `sessions/NNNN-slug.md` (`NNNN` = próximo número da tabela).
2. No refinamento (fase 1): feche **Objetivo**, **Critérios de aceite** (apontando os
   **testes que provam** cada um — S1) e **Plano TDD**.
3. Commit do refinamento atualizando **também** `SESSIONS.md` (tabela + "Próxima
   sessão" — S4).