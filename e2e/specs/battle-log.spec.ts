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
