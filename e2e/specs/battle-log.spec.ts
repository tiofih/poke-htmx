import { test, expect, type Page } from '@playwright/test';

// Sessao 0086 — battle-log legivel + juice-polish + consumo/recompensa visivel.
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

async function playOneRound(page: Page) {
  await page.getByRole('button', { name: 'Batalhar', exact: true }).click();
  await expect(page.locator('#battle-log')).toBeVisible();
}

// Advance until the play button is gone (finished) or the cap hits. Each click
// re-renders #battle-view via htmx, so wait on the round banner flipping.
async function playUntilDone(page: Page) {
  for (let i = 0; i < 40; i++) {
    const play = page.getByRole('button', { name: 'Batalhar', exact: true });
    if ((await play.count()) === 0) return;
    const before = (await page.locator('.turn-status').first().textContent()) ?? '';
    await play.first().click();
    await expect(page.locator('.turn-status').first()).not.toHaveText(before);
  }
}

// C1: log legivel por rodada — headers + data-round, chronological, chips.
test('round headers chronological with data-round and damage/KO chips', async ({ page }) => {
  await buildTeamOfSix(page);
  await page.goto('/battle');
  await expect(page.locator('#battle-view')).toBeVisible();
  await playOneRound(page);
  await playOneRound(page);

  const headers = page.locator('.log-round-head');
  const headerCount = await headers.count();
  expect(headerCount).toBeGreaterThanOrEqual(2);

  const rounds: number[] = [];
  for (let i = 0; i < headerCount; i++) {
    const attr = await headers.nth(i).getAttribute('data-round');
    expect(attr).toMatch(/^\d+$/);
    rounds.push(Number(attr));
    await expect(headers.nth(i)).toContainText(`Rodada ${attr}`);
  }
  expect([...rounds].sort((a, b) => a - b)).toEqual(rounds);

  const entries = page.locator('#battle-log .log__entry[data-round]');
  expect(await entries.count()).toBeGreaterThan(0);
  const headed = new Set(rounds.map(String));
  for (let i = 0; i < (await entries.count()); i++) {
    expect(headed.has((await entries.nth(i).getAttribute('data-round')) ?? '')).toBe(true);
  }

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
  await playOneRound(page);

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

// C3: consumo/recompensa visivel — stock chips when items were used, defeat
// copy iff the opponent won, participation (Derrota) vs win (ganhou) rewards.
test('consumption and reward copy', async ({ page }) => {
  await buildTeamOfSix(page);
  await page.goto('/battle');
  await playOneRound(page);

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
  if (badge.includes('Oponente')) {
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
