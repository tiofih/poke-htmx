# Botão Batalhar atualiza sozinho ao mexer no time

> **Projeto:** poke-htmx · **Entrega:** 2026-09-21 · **Alteração proposta em:** branch `0090-cta-oob` (URL após abertura)

## O que muda para quem usa o produto

O botão "Batalhar" do cabeçalho (com o cadeado e a dica de texto) agora reage na hora
sempre que o time muda: adicionar ou remover um Pokémon, curar no Poke Center, comprar
ou vender no Poke Mart e recomeçar a jornada atualizam o botão e a dica sem recarregar
a página.

**Antes:** o botão ficava desatualizado até um F5 — mostrava "Monte seu time" mesmo
depois de adicionar membros, ou liberado mesmo com o time vazio após uma remoção.
**Depois:** cada ação no time entrega junto a versão atual do botão, que se troca na
tela pelo mecanismo de atualização parcial já usado no resto do app.

## O que foi implementado

- O botão e a dica saíram do molde geral da página para um trecho próprio com
  identificador estável, reutilizado tanto na página cheia quanto nas respostas
  parciais das cinco ações (adicionar com ou sem bloqueio de orçamento, remover,
  curar, recomeçar a jornada, comprar/vender).
- A lógica do cadeado e das três dicas ("jornada encerrada", "monte seu time",
  "cure o time") foi movida para dois métodos no servidor, sem mudar nenhuma regra:
  mesmos estados, mesmos textos.
- Testes novos conferem, no corpo de cada resposta parcial, a presença do trecho do
  botão com o estado certo (bloqueado com a dica de cura ao adicionar, dica de montar
  o time ao esvaziar, etc.).

## O que foi validado

- **Testes automatizados:** suíte completa `1192 testes / 6381 asserções`, zero falha,
  lint zero — para rodar: `./scripts/test` e `./scripts/lint`
- **Ponta a ponta:** rodada completa no navegador (15 cenários): 12 passaram. Os 3 que
  falharam foram repetidos na árvore sem esta mudança e falham igual — contraste de cor
  em elementos antigos da home, um seletor defasado no teste do modal do Center (o
  teste procura um link, a tela tem um botão) e um cenário de adição sensível ao estado
  compartilhado do banco de desenvolvimento (passa isolado). Nenhuma falha nova.
- **Só provável à mão:** o clique de verdade no navegador seguindo o roteiro abaixo
  (feito pelo revisor deste PR).

## O que NÃO foi validado (limites conhecidos)

- Clique manual do roteiro ainda não executado por ninguém (é o roteiro abaixo).
- Só testado em Chromium desktop; sem teste em mobile, outros navegadores ou com dois
  usuários simultâneos.
- Banco de desenvolvimento compartilhado: cenários de ponta a ponta podem oscilar com
  o estado deixado por execuções anteriores.

## Como rodar e chegar ao estado inicial do teste

```bash
./scripts/run   # sobe o app em http://localhost:3000 (sobe o banco junto)
```

**Estado inicial:** `manual` — abrir `http://localhost:3000` com o time vazio (recomeçar
a jornada zera o time, se preciso).

## Roteiro de teste manual (o que fazer e o que observar)

| # | O que fazer | O que deve acontecer |
| --- | --- | --- |
| 1 | Com o time vazio, adicionar 1 Pokémon pela lista | O botão destrava na hora, sem recarregar; some a dica "Monte seu time para batalhar" |
| 2 | Remover esse Pokémon | O botão volta a bloqueado na hora, sem recarregar, com a dica "Monte seu time para batalhar" |
| 3 | Com o time cheio e machucado, curar no Poke Center | O botão destrava na hora, sem recarregar |
| 4 | Comprar e vender um item no Poke Mart; recomeçar a jornada | Botão e dica acompanham cada ação, sem recarregar; após recomeçar, dica de montar o time |
| 5 | Em nenhum passo | A pílula de estado do time ("Pronto p/ batalhar", "Precisa de cura", etc.) não muda de comportamento |

## Comandos do projeto

```bash
./scripts/test   # testes
./scripts/lint    # lint
./scripts/run   # subir o app (http://localhost:3000)
```

## Anexo — rastreabilidade interna (equipe)

<!-- Tudo abaixo é para quem trabalha no projeto. O texto acima é para quem não trabalha.
     O Anexo existe para a trilha requisito → sessão → passos → commits; ele NÃO é o lugar
     de guardar a explicação — o que explica está acima. -->

- Arquivo da sessão: `sessions/0090-cta-oob.md`
- Critérios e o teste que prova cada um: adicionar/bloqueio → `test/team_routes_test.rb`
  (`test_post_team_includes_cta_slot_out_of_band_swap`,
  `test_post_team_blocked_still_includes_cta_slot_oob`); remover →
  `test/team_routes_test.rb` (`test_delete_team_includes_cta_slot_out_of_band_swap`);
  curar → `test/modal_routes_test.rb`
  (`test_heal_success_includes_cta_slot_out_of_band_swap`); recomeçar →
  `test/journey_routes_test.rb`
  (`test_restart_journey_includes_cta_slot_out_of_band_swap`); comprar/vender →
  `test/mart_routes_test.rb` (`test_mart_buy_includes_cta_slot_out_of_band_swap`,
  `test_mart_sell_includes_cta_slot_out_of_band_swap`); pílula intacta → testes
  existentes de layout e do time.
- Rastreabilidade de requisitos: item T5 do `TODO.md` (achado pós-validação da sessão
  de polimento visual, consequência aceita do escopo dela).
- Commits desta entrega: `717485f` (refinamento), `fe0c225`, `4dcc548`, `fb4b24a`,
  `8bd2abc` (implementação em três frentes mais ajuste de lint).
