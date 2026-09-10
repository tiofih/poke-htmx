import { test, expect } from '@playwright/test';

// P0: remove-from-team.
// Setup goes through the real UI (add first), so the remove path is
// exercised against a member the app itself rendered. Fresh browser
// context => fresh server session => empty team at start.
test('remove-from-team drops the member and resets the badge', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#pokemon-list li.pcard').first()).toBeVisible();

  const addBtn = page.getByRole('button', { name: /Adicionar .* ao time/ }).first();
  const label = (await addBtn.getAttribute('aria-label')) ?? '';
  const name = label.replace(/^Adicionar /, '').replace(/ ao time$/, '');
  expect(name.length).toBeGreaterThan(0);

  await addBtn.click();
  const member = page.locator('#roster li.member', { hasText: name });
  await expect(member).toBeVisible();
  await expect(page.locator('#nav-badge')).toContainText('1/6');

  // Remove scoped to the member row (stable when the list re-renders via OOB).
  await member.getByRole('button', { name: 'Remover do time' }).click();

  await expect(page.locator('#roster')).not.toContainText(name);
  await expect(page.locator('#nav-badge')).toContainText('0/6');
});
