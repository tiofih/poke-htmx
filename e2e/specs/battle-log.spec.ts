import { test, expect, type Page } from '@playwright/test';

// Sessao 0086 — battle-log legivel + juice-polish + consumo/recompensa visivel.
// Strike flow (T143): #play-btn rotulado "Batalhar" posta 1 golpe em
// POST /battle/strike (hx-swap="none") — cada clique faz append OOB de
// exatamente 1 .log__entry em #battle-log (sem re-render, sem replay).
// Harness: fresh context => fresh server session => empty team. Build 6 via the
// real catalog UI (nth(i) distinct cards; added cards relabel to "ja esta no
// time", so .first() would re-add), then drive /battle through its buttons.
// Role > accessible name for actions; CSS only for the log itself (no roles).
async function buildTeamOfSix(page: Page) {
  await page.goto('/');
  await expect(page.locator('#pokemon-list li.pcard').first()).toBeVisible();

  for (let i = 0; i < 6; i++) {
    await page.getByRole('button', { name: /Adicionar .* ao time/ }).nth(i).click();
    await expect(page.locator('#nav-badge')).toContainText(`${i + 1}/6`);
  }
}

async function strikeCount(page: Page) {
  return page.locator('#battle-log .log__entry').count();
}

// One Batalhar click = exactly 1 appended strike entry (OOB beforeend, no
// re-render). Assert count grows by 1 — this is the no-replay expectation:
// a full re-render/replay would reset or duplicate entries.
async function playOneStrike(page: Page) {
  const before = await strikeCount(page);
  await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
  await expect(page.locator('#battle-log .log__entry')).toHaveCount(before + 1);
}

// Advance strike-by-strike until the OOB result modal lands (finished) or the
// cap hits. Nothing re-renders (hx-swap="none"), so there is no banner flip
// to wait on — entry-count growth is the progress signal.
async function playUntilDone(page: Page) {
  for (let i = 0; i < 400; i++) {
    if ((await page.locator('#result-modal').count()) > 0) return;
    const before = await strikeCount(page);
    await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
    await expect(page.locator('#battle-log .log__entry')).toHaveCount(before + 1);
    if ((await page.locator('#result-modal').count()) > 0) return;
  }
}

// C1: log legivel por golpe — append-only (+1 por Batalhar), data-round
// chronological, chips. (Round headers so existem no render inicial com log;
// strikes fazem append so de .log__entry via OOB, sem headers.)
test('round headers chronological with data-round and damage/KO chips', async ({ page }) => {
  await buildTeamOfSix(page);
  await page.goto('/battle');
  await expect(page.locator('#battle-view')).toBeVisible();
  await playOneStrike(page);
  await playOneStrike(page);

  const entries = page.locator('#battle-log .log__entry[data-round]');
  expect(await entries.count()).toBeGreaterThanOrEqual(2);

  const rounds: number[] = [];
  for (let i = 0; i < (await entries.count()); i++) {
    const attr = await entries.nth(i).getAttribute('data-round');
    expect(attr).toMatch(/^\d+$/);
    rounds.push(Number(attr));
  }
  expect([...rounds].sort((a, b) => a - b)).toEqual(rounds);

  await expect(page.locator('.chip--dmg').first()).toContainText(/de dano/);
  for (let i = 0; i < (await page.locator('.chip--ko').count()); i++) {
    await expect(page.locator('.chip--ko').nth(i)).toContainText('KO!');
  }
});

// C2: juice CSS-only + reduced-motion — final net kills all juice (runtime
// proof via getComputedStyle; getAnimations() is empty after 0.3-0.5s).
test('reduced-motion disables juice', async ({ page }) => {
  await buildTeamOfSix(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/battle');
  await playOneStrike(page);

  const entry = page.locator('#battle-log .log__entry').first();
  await expect(entry).toBeVisible();
  expect(await entry.evaluate((el) => getComputedStyle(el).animationName)).toBe('none');

  const tail = await page.evaluate(async () => {
    const css = await (await fetch('/style.css')).text();
    return css.slice(css.lastIndexOf('@media (prefers-reduced-motion: reduce)'));
  });
  expect(tail).toContain('animation: none !important');
  for (const sel of ['.log__entry', '.log-round-head', '.log__entry--defeat']) {
    expect(tail).toContain(sel);
  }
});

// C7 auto-chain: check JOGAR-AUTO once, single Batalhar click drives to
// finish via HX-Trigger next-strike. Strike responde hx-swap="none" (sem
// re-render), entao o fim se prova pelo modal OOB (#result-modal), nao pelo
// banner .turn-status nem pela remocao do botao (ambos intactos no DOM).
test('auto toggle chains to finish without further clicks', async ({ page }) => {
  await buildTeamOfSix(page);
  await page.goto('/battle');
  await expect(page.locator('#battle-view')).toBeVisible();
  await page.locator('#auto-play').check();
  await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
  await expect(page.locator('#result-modal').first()).toBeVisible({ timeout: 15000 });
  await expect(page.locator('#result-box .winner-badge').first()).toBeVisible();
});
// C3: consumo/recompensa visivel — stock chips when items were used, defeat
// copy iff the opponent won, participation (Derrota) vs win (ganhou) rewards.
test('consumption and reward copy', async ({ page }) => {
  await buildTeamOfSix(page);
  await page.goto('/battle');
  await playOneStrike(page);

  for (let i = 0; i < (await page.locator('.chip--stock').count()); i++) {
    await expect(page.locator('.chip--stock').nth(i)).toContainText(/restam \d+/);
  }
  for (let i = 0; i < (await page.locator('.chip--empty').count()); i++) {
    await expect(page.locator('.chip--empty').nth(i)).toContainText('última unidade');
  }
  if ((await page.locator('.chip--stock').count()) > 0) {
    await expect(page.locator('#battle-log')).toContainText(/usou 1 .*restam \d+/);
  }

  await playUntilDone(page);
  const badge = (await page.locator('#result-box .winner-badge').first().textContent()) ?? '';
  // Derrota entra so no render full (battle.erb); strikes fazem append OOB
  // sem ela — asserta a copy so quando renderizada.
  if ((await page.locator('.log__entry--defeat').count()) > 0) {
    const defeat = page.locator('.log__entry--defeat');
    await expect(defeat).toBeVisible();
    await expect(defeat).toContainText(/Derrota.*Cure no Poke Center/);
  }
  if ((await page.locator('#result-box .rewards').count()) > 0) {
    const rewards = page.locator('#result-box .rewards').first();
    await expect(rewards).toContainText('XP');
    if (badge.includes('Oponente')) await expect(rewards).toContainText('Derrota');
    if (badge.includes('Seu Time')) await expect(rewards).toContainText('ganhou');
  }
});

// ---------------------------------------------------------------------------
// 0087 C6/D5 — chegada real do projetil (a unica prova de `cqi` e a pagina viva).
// O CSS estatico resolve var/calc, mas nao resolve `cqi` contra a largura da
// arena. Aqui o container e ancorado FORA do viewport (arena max-width 1200 num
// viewport 1600) para discriminar `cqi` de `vw`, e o destino do `.shot` e
// comparado com a borda proxima do card alvo.
// ---------------------------------------------------------------------------
const SHOT = '#jx-shot-track .shot';
const SHOT_W = 10;
const TRAVEL_PX = 42;
// Time barato (custo <= 450 do orcamento): o helper de 6 starters do topo
// estoura o orcamento neste seed e nao abre a arena.
const CHEAP_TEAM = ['caterpie', 'weedle', 'rattata', 'spearow', 'ekans', 'nidoran-f'];

async function buildBudgetTeam(page: Page) {
  await page.goto('/');
  await expect(page.locator('#pokemon-list li.pcard').first()).toBeVisible();
  for (const [i, name] of CHEAP_TEAM.entries()) {
    await page.getByRole('button', { name: `Adicionar ${name} ao time` }).click();
    await expect(page.locator('#nav-badge')).toContainText(`${i + 1}/6`);
  }
}

type Point = { x: number; y: number };
type SlotBox = { x: number; y: number; left: number; right: number };
type Arrival = {
  from: string | null;
  to: string | null;
  arenaWidth: number;
  attacker: Point; // centro medido do card do atacante
  target: SlotBox; // caixa medida do card do alvo
  origin: Point; // centro do .shot no keyframe `from`
  dest: Point; // centro do .shot no keyframe `to` (fim)
};

// Um Batalhar = 1 entrada OOB que troca o `.shot` da track. Espera o NOVO no
// (marca o anterior) e a animacao terminar. Depois SEGURA a animacao nos dois
// keyframes (`0` e `endTime`) para medir origem e destino reais — o eixo y so
// existe via --fx-dy/--fx-ox medidos no handler, entao a prova tem que vir do
// keyframe resolvido, nao do CSS estatico.
async function strikeAndMeasure(page: Page): Promise<Arrival | null> {
  await page.evaluate(() => document.querySelector('#jx-shot-track .shot')?.setAttribute('data-probe-old', '1'));
  await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
  await page
    .waitForFunction(() => {
      const s = document.querySelector('#jx-shot-track .shot');
      return !!s && !s.hasAttribute('data-probe-old');
    }, undefined, { timeout: 5000 })
    .catch(() => undefined);
  await page
    .waitForFunction(() => {
      const s = document.querySelector('#jx-shot-track .shot');
      const anims = s?.getAnimations() ?? [];
      return anims.length > 0 && anims.every((a) => a.playState === 'finished');
    }, undefined, { timeout: 5000 })
    .catch(() => undefined);

  return page.evaluate(() => {
    const shot = document.querySelector('#jx-shot-track .shot') as HTMLElement | null;
    const from = shot?.getAttribute('data-from-side');
    if (!shot || !from) return null;
    const to = shot.getAttribute('data-to-side');
    const card = (side: string | null, slot: string | null) =>
      document.querySelector(`.fighter[data-side="${side}"][data-slot="${slot}"]`) as HTMLElement | null;
    const attacker = card(from, shot.getAttribute('data-from-slot'));
    const target = card(to, shot.getAttribute('data-to-slot'));
    const anim = shot.getAnimations()[0];
    if (!attacker || !target || !anim) return null;
    const centre = (el: Element) => {
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    };
    anim.pause();
    anim.currentTime = 0; // keyframe `from` = origem do projetil
    const origin = centre(shot);
    anim.currentTime = anim.effect!.getComputedTiming().endTime as number; // `to` = destino
    const dest = centre(shot);
    anim.play();
    const ar = attacker.getBoundingClientRect();
    const tr = target.getBoundingClientRect();
    return {
      from,
      to,
      arenaWidth: (document.querySelector('.arena') as HTMLElement).getBoundingClientRect().width,
      attacker: { x: ar.x + ar.width / 2, y: ar.y + ar.height / 2 },
      target: { x: tr.x + tr.width / 2, y: tr.y + tr.height / 2, left: tr.left, right: tr.right },
      origin,
      dest,
    };
  });
}

test('projectile leaves the attacker slot and reaches the target slot (measured pair)', async ({ page }) => {
  await page.setViewportSize({ width: 1600, height: 900 });
  await buildBudgetTeam(page);
  await page.goto('/battle');
  await expect(page.locator('.arena')).toBeVisible();
  // Ancora o container longe do viewport: `cqi` mede 1200, `vw` mediria 1600.
  await page.addStyleTag({ content: '.arena { max-width: 1200px; }' });
  await expect(page.locator('.arena')).toHaveCSS('width', '1200px');

  const seen = new Set<string>();
  for (let i = 0; i < 12 && seen.size < 2; i++) {
    if ((await page.getByRole('button', { name: 'Batalhar', exact: true }).count()) === 0) break;
    const obs = await strikeAndMeasure(page);
    if (!obs || !obs.to) continue;
    seen.add(obs.from ?? '');

    expect(obs.arenaWidth).toBe(1200);
    expect(['0', '1']).toContain(obs.to);

    // 0088 C6 origem: o keyframe `from` tem que pousar no CENTRO do card do
    // atacante (x e y) — era o gap declarado no Passo 4 (saida no rail base).
    expect(Math.abs(obs.origin.x - obs.attacker.x), `origem x (from=${obs.from})`).toBeLessThan(2);
    expect(Math.abs(obs.origin.y - obs.attacker.y), `origem y (from=${obs.from})`).toBeLessThan(2);

    // 0088 C6 destino: par ordenado medido contra o slot REAL do alvo — y no
    // centro do card; x na borda proxima (o rail de 0087 segue dono do eixo x —
    // aqui a assercao e contra a caixa medida do card, nao contra uma constante).
    expect(Math.abs(obs.dest.y - obs.target.y), `destino y (to=${obs.to})`).toBeLessThan(2);

    if (obs.to === '0') {
      // Alvo = coluna esquerda; borda proxima = direita do card (atacante veio da direita).
      expect(obs.from).toBe('1');
      const gap = obs.dest.x - obs.target.right; // >=0 = chegou a borda; <0 = parou n px antes
      expect(gap).toBeGreaterThan(-40);
      expect(gap).toBeLessThanOrEqual(20);
    } else {
      // Alvo = coluna direita; borda proxima = esquerda do card.
      expect(obs.from).toBe('0');
      const gap = obs.dest.x - obs.target.left;
      expect(gap).toBeGreaterThan(-20);
      expect(gap).toBeLessThan(40);
    }
  }
  // O engine alterna atacante: as duas direcoes (ltr/rtl) precisam ser provadas.
  expect([...seen].sort()).toEqual(['0', '1']);
});

test('container gate disables projectile travel below 981px', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 900, height: 900 });
  await buildBudgetTeam(page);
  await page.goto('/battle');
  await expect(page.locator('.arena')).toBeVisible();

  let ok = false;
  for (let i = 0; i < 5 && !ok; i++) {
    await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
    ok = (await page.locator(`${SHOT}[data-from-side]`).count()) > 0;
    if (!ok) await page.waitForTimeout(300);
  }
  expect(ok).toBe(true);

  const arenaWidth = await page.locator('.arena').evaluate((el) => el.getBoundingClientRect().width);
  expect(arenaWidth).toBeLessThan(981);
  // Polling (nao medicao unica): logo apos o clique o htmx troca o .shot e a
  // locator pode casar o no JA DESTACADO — nesse estado o Chromium devolve
  // `getComputedStyle(el).display === ""` (nao "none"), o que e ruido de swap,
  // nao gate aberto. O poll tolera essa janela: em 900px o valor estavel e
  // sempre "none" e um gate quebrado devolveria "block" ate o timeout.
  await expect
    .poll(
      () =>
        page.locator(`${SHOT}[data-from-side]`).first().evaluate((el) => ({
          display: getComputedStyle(el).display,
          animation: getComputedStyle(el).animationName,
        })),
      { timeout: 5000 },
    )
    .toEqual({ display: 'none', animation: 'none' });

  // C9 (0088 Passo 5): coluna unica = no-op tambem no JS — o handler nao escreve
  // nenhuma var de origem/destino e nada estoura na pagina.
  const vars = await page.locator(`${SHOT}[data-from-side]`).first().evaluate((el) => ({
    ox: (el as HTMLElement).style.getPropertyValue('--fx-ox'),
    oy: (el as HTMLElement).style.getPropertyValue('--fx-oy'),
    dy: (el as HTMLElement).style.getPropertyValue('--fx-dy'),
  }));
  expect(vars).toEqual({ ox: '', oy: '', dy: '' });
  expect(errors).toEqual([]);
});

// C8 (0088 Passo 5): reduced motion mantem o comportamento atual — sem travel.
// O CSS final zera a animacao do .shot e o handler tambem e no-op explicito.
test('reduced motion keeps the projectile without travel', async ({ page }) => {
  await page.setViewportSize({ width: 1600, height: 900 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await buildBudgetTeam(page);
  await page.goto('/battle');
  await expect(page.locator('.arena')).toBeVisible();

  let ok = false;
  for (let i = 0; i < 5 && !ok; i++) {
    await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
    ok = (await page.locator(`${SHOT}[data-from-side]`).count()) > 0;
    if (!ok) await page.waitForTimeout(300);
  }
  expect(ok).toBe(true);

  await expect
    .poll(
      () => page.locator(`${SHOT}[data-from-side]`).first().evaluate((el) => getComputedStyle(el).animationName),
      { timeout: 5000 },
    )
    .toBe('none');
  const vars = await page.locator(`${SHOT}[data-from-side]`).first().evaluate((el) => ({
    ox: (el as HTMLElement).style.getPropertyValue('--fx-ox'),
    dy: (el as HTMLElement).style.getPropertyValue('--fx-dy'),
  }));
  expect(vars).toEqual({ ox: '', dy: '' });
});

// C7 (0088 Passo 5): SEM JavaScript o rail de 0087 continua — travel so no eixo
// x, sem as vars inline do handler. Sem JS o htmx nao roda (o golpe e dado no
// contexto normal), entao a mesma sessao (cookie = mesmo user_id / mesma batalha
// no registry) reabre o full render, que ja traz o .shot do ultimo strike; o
// gate e ligado por instrumentacao do teste, como o OOB do htmx ligaria.
test('without JavaScript the 0087 rail remains (x only, no inline vars)', async ({ page, browser }) => {
  await page.setViewportSize({ width: 1600, height: 900 });
  await buildBudgetTeam(page);
  await page.goto('/battle');
  await expect(page.locator('.arena')).toBeVisible();
  await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
  await expect(page.locator(`${SHOT}[data-from-slot]`)).toHaveCount(1);
  const state = await page.context().storageState();

  const noJs = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 1600, height: 900 },
    storageState: state,
  });
  const p = await noJs.newPage();
  await p.goto('/battle');
  await expect(p.locator('.arena')).toBeVisible();

  const rail = await p.evaluate(() => {
    const shot = document.querySelector('#jx-shot-track .shot') as HTMLElement | null;
    if (!shot) return null;
    document.querySelector('#jx-gates')?.setAttribute('data-jx-shot', 'on');
    const anim = shot.getAnimations()[0];
    if (!anim) return null;
    anim.pause();
    anim.currentTime = anim.effect!.getComputedTiming().endTime as number;
    const m = new DOMMatrixReadOnly(getComputedStyle(shot).transform);
    return {
      x: m.m41,
      y: m.m42,
      arena: (document.querySelector('.arena') as HTMLElement).getBoundingClientRect().width,
      from: shot.getAttribute('data-from-side'),
      vars: {
        ox: shot.style.getPropertyValue('--fx-ox'),
        oy: shot.style.getPropertyValue('--fx-oy'),
        dy: shot.style.getPropertyValue('--fx-dy'),
      },
    };
  });
  expect(rail, 'o full render deve trazer o .shot do ultimo strike').not.toBeNull();
  expect(['0', '1']).toContain(rail!.from);
  // Sem JS nao existe var inline: o keyframe cai inteiro no fallback.
  expect(rail!.vars).toEqual({ ox: '', oy: '', dy: '' });
  // fallback = rail de 0087: horizontal puro (y zerado) e o travel borda->borda.
  expect(rail!.y).toBe(0);
  const expected = 0.35 * rail!.arena + TRAVEL_PX + SHOT_W;
  expect(Math.abs(rail!.x)).toBeGreaterThan(expected - 2);
  expect(Math.abs(rail!.x)).toBeLessThan(expected + 2);
  await noJs.close();
});

// ---------------------------------------------------------------------------
// 0087 Passo 7 — guarda estrutural que faltava ao Passo 1.
// O defeito que escapou: a track nasceu filho DIRETO do .arena (grid de 3
// colunas) e so o `position:absolute` do Passo 5 a mantinha fora do fluxo do
// grid; sem essa regra ela virava o 4o item e deslocava todas as colunas
// (time ao centro, podium a direita, oponente abaixo-esquerda). Nenhum teste
// observava layout. Aqui a guarda mede o resultado ao vivo nas duas larguras:
//   - .arena com exatamente 3 filhos EM FLUXO (as 2 .battle-column + o .podium
//     sticky, que e in-flow: so absolute/fixed saem do fluxo); e
//   - #jx-shot-track absoluta E fora do .arena como filho (garantia estrutural).
// ---------------------------------------------------------------------------
test('arena keeps 3 in-flow columns and an out-of-flow projectile track', async ({ page }) => {
  await buildBudgetTeam(page);
  await page.goto('/battle');
  await expect(page.locator('.arena')).toBeVisible();

  for (const width of [1600, 900]) {
    await page.setViewportSize({ width, height: 900 });
    await expect(page.locator('.arena')).toBeVisible();

    const state = await page.locator('.arena').evaluate((arena) => {
      const cs = (el: Element) => getComputedStyle(el);
      const inFlow = [...arena.children].filter((c) => {
        const p = cs(c).position;
        return cs(c).display !== 'none' && p !== 'absolute' && p !== 'fixed';
      });
      const track = document.querySelector('#jx-shot-track') as HTMLElement | null;
      return {
        inFlowCount: inFlow.length,
        inFlowChildren: inFlow.map((c) => `${c.tagName}.${(c as HTMLElement).className}`),
        trackPosition: track ? cs(track).position : null,
        trackInArena: !!track && arena.contains(track),
        trackDirectChild: !!track && track.parentElement === arena,
      };
    });

    expect(
      state.inFlowCount,
      `em ${width}px o .arena tem ${state.inFlowCount} filhos em fluxo: ${state.inFlowChildren.join(', ')}`,
    ).toBe(3);
    expect(state.trackPosition, `em ${width}px a track do projetil`).toBe('absolute');
    // A track precisa continuar DENTRO do .arena (containing block + @container),
    // mas nunca como filho direto (senao volta a poder virar item do grid).
    expect(state.trackInArena, `em ${width}px a track esta dentro do .arena`).toBe(true);
    expect(state.trackDirectChild, `em ${width}px a track e filho direto do .arena`).toBe(false);
  }
});
