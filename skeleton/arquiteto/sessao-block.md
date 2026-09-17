<!-- sdd-arquiteto:bloco -->
## Fase 1b — desenho técnico (opcional; só com o perfil `--with-arquiteto`)

Vale **só** se `.opencode/agent/arquiteto.md` existir. Com o refinamento fechado e **antes** de
disparar `implementador-teste`: se a sessão cruzar **áreas do `STACK.md`** (ou a fronteira entre
elas), dispare `arquiteto` (read-only) e **injete o desenho no prompt** do implementador (e, se for
o caso, o despacho é o que o desenho recomendar na ordem). Sem o arquivo, ou em sessão de área
única/trivial, **pule a fase 1b** — refinamento → implementação, como sempre foi. O `arquiteto`
devolve o desenho no texto: não escreve arquivo, não commita, não marca critério e não reabre
decisão do usuário (S3) — se o desenho exigir decisão nova, ele devolve a pergunta e **você** a leva
ao usuário.
<!-- fim sdd-arquiteto:bloco -->
