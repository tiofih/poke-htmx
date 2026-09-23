# Testes do time estáveis entre jogadores e aviso sobre setup destrutivo do banco

> **Projeto:** poke-htmx · **Entrega:** 2026-09-22 · **Alteração proposta em:** branch `0092-t1-t2` (PR a ser aberto a partir dela)

## O que muda para quem usa o produto

Nada muda na tela nem no jogo: nenhuma função, regra ou visual do produto foi alterado.
O que muda é a confiabilidade dos testes do projeto e a documentação de um risco de dados.

**Antes:** a suíte de testes podia falhar sem motivo real, dependendo da ordem em que os testes rodavam, porque a consulta de teste não separava os times de jogadores diferentes.
**Depois:** a consulta de teste separa os times por jogador, a suíte passa em execuções consecutivas com ordens aleatórias distintas, e o risco de o setup do banco apagar times ficou documentado junto de uma proposta de proteção.

## O que foi implementado

- A consulta de teste que lê uma linha do time agora filtra pelo identificador do jogador, com filtro obrigatório: times de jogadores diferentes com o mesmo nome de Pokémon não se confundem mais durante os testes. Os 9 pontos de chamada nos 3 arquivos de teste foram atualizados para a nova assinatura.
- Um teste novo cobre exatamente esse isolamento: cria o mesmo Pokémon para dois jogadores diferentes e confirma que cada jogador enxerga só o próprio, além de confirmar que um jogador sem time não encontra nada.
- Respostas gravadas da API externa (arquivos de gravação de rede dos testes) foram trazidas para esta branch, para que a suíte rode sem depender da rede em nenhum momento.
- O comportamento destrutivo do comando de setup do banco ficou documentado no catálogo de pendências do projeto: `rake db:setup` (e o setup equivalente dos testes) reaplica todas as migrações a cada execução, e duas delas fazem `TRUNCATE team_pokemons CASCADE` — ou seja, apagam os times de todos os usuários a cada execução. Junto do registro entrou a proposta de proteção (um controle de migrações já aplicadas, ou um portão explícito para as migrações destrutivas); a proteção em si não foi implementada nesta entrega, é trabalho futuro.

## O que foi validado

- **Testes automatizados:** a suíte completa, em 3 execuções consecutivas com ordens aleatórias distintas (seeds 65331, 16461 e 40634) — todas com 1193 execuções, 6396 asserções, 0 falhas e 0 erros; o teste novo de isolamento entre jogadores está incluído nesse total — para rodar: `./scripts/test`
- **Verificado à mão durante a implementação:** leitura do item novo no catálogo de pendências (`docs/draft-backlog.md`, seção de Arquitetura / Infra / Performance), confirmando que descreve o `TRUNCATE` das duas tabelas e registra a proposta de proteção; e as 9 chamadas atualizadas conferidas por busca no repositório (nenhuma chamada antiga sobrou).
- **Só provável à mão:** o comportamento destrutivo do setup do banco em si não foi reproduzido de propósito nesta entrega (apagar dados de desenvolvimento é destrutivo); ele está documentado a partir da leitura direta das migrações `0003`/`0007` e do código do setup, sem simulação.

## O que NÃO foi validado (limites conhecidos)

- A proteção contra o setup destrutivo (controle de migrações já aplicadas / portão explícito) **não** foi implementada nem testada — só está proposta na documentação; o risco de perda de times ao rodar `rake db:setup` continua real.
- A suíte foi validada apenas neste ambiente (Docker local, banco PostgreSQL 16); não rodou em outro navegador, SO ou versão de banco.
- O filtro novo cobre separação por jogador; ele **não** ordena resultados, então um cenário hipotético de duas linhas do mesmo Pokémon para o mesmo jogador ainda devolveria a primeira sem ordenação garantida (não é possível hoje: o time é único por número por jogador).
- A gravação de rede dos testes vale para os dados gravados na data da entrega; se a API externa mudar respostas antigas fora do que foi gravado, a suíte pode pedir nova gravação.
- Nada de comportamento de produto (telas, regras de jogo) foi validado porque nada de produto mudou; a validação de produto da entrega é apenas a confirmação de ausência de regressão pela suíte completa.

## Como rodar e chegar ao estado inicial do teste

O caminho até o estado inicial do teste é o próprio script do projeto: ele sobe o banco e roda a suíte inteira, sem rede.

```bash
./scripts/test
```

Para apenas subir o app no navegador (opcional, não necessário para os testes):

```bash
./scripts/run
```

**Estado inicial:** `script` — `./scripts/test` sobe o container do banco e roda a suíte completa; não há estado de dados a montar antes.

## Roteiro de teste manual (o que fazer e o que observar)

| # | O que fazer | O que deve acontecer |
| --- | --- | --- |
| 1 | Rodar `./scripts/test` na raiz do projeto | A execução termina com `1193 runs, 6396 assertions, 0 failures, 0 errors, 0 skips` e mostra um `Run options: --seed <número>` diferente a cada execução |
| 2 | Rodar `./scripts/test test/seed_scripts_test.rb` | Todos os testes do arquivo passam, incluindo `test_team_row_filtra_por_user_id`, que cria o mesmo Pokémon para dois jogadores e vê cada um enxergar só o próprio |
| 3 | Repetir a linha 1 duas vezes | As 3 execuções seguidas terminam verdes; nenhum teste do arquivo de seeds falha em nenhuma ordem |
| 4 | Abrir `docs/draft-backlog.md` e localizar o item novo na seção "Arquitetura / Infra / Performance" | O item descreve que o setup do banco trunca `team_pokemons` e `team_pokemon_progress` a cada execução e registra a proposta de proteção como trabalho futuro |
| 5 | Rodar `./scripts/lint` | O lint termina com `136 files inspected, no offenses detected` |

## Comandos do projeto

```bash
./scripts/test   # testes
./scripts/lint   # lint
./scripts/run    # subir o app (porta 3000)
```

## Anexo — rastreabilidade interna (equipe)

<!-- Tudo abaixo é para quem trabalha no projeto. O texto acima é para quem não trabalha. -->

- Arquivo da sessão: `sessions/0092-t1-t2.md`
- Critérios e o teste que prova cada um:
  - C1 → `test/seed_scripts_test.rb` (`test_team_row_filtra_por_user_id` novo + `test_team_evolucao_seeds_near_evolution_thresholds`); 9 chamadores atualizados em `test/seed_scripts_test.rb`, `test/team_repository_test.rb`, `test/seed_team_test.rb`
  - C2 → `manual` — 3× `./scripts/test` verdes com seeds 65331, 16461, 40634 (prints `Run options: --seed`)
  - C3 → `manual` — leitura de `docs/draft-backlog.md` §2 (item novo: TRUNCATE documentado)
  - C4 → `manual` — mesmo item (proposta guard/once registrada, não implementada — decisão D1)
  - G1 → suíte 1193/6396 0 falhas + lint 0 em todo green; commit por passo
  - G2 → sem dependência nova, sem mudança de schema, testes sem rede, sem supressão de lint
  - G3 → `SESSIONS.md` atualizado no commit do refinamento; `REQUIREMENTS.md` intocado
- Rastreabilidade de requisitos: nenhum RF/RNF novo; fecha T1 e T2 do `TODO.md` (infra de teste + documentação de dívida). `REQUIREMENTS.md` não alterado.
- Commits desta entrega: `cba84be` (refinamento), `7975c91` (Passo 1: cassetes VCR), `04f981b` (Passo 2: `team_row` filtra por `user_id`), `a5098f0` (Passo 3: doc do setup destrutivo) + este commit do corpo do PR.
