import { test, expect } from '@playwright/test';

// P0: catalog search + add-to-team.
// Evidence: aria-label of the add button, #roster text, #nav-badge count,
// and the #add-status confirmation — no subjective asserts.
test('catalog search filters and add-to-team lands in roster', async ({ page }) => {
  await page.goto('/');

  // Catalog boots with cards (starters + first commons page).
  const search = page.getByLabel('Buscar no arquivo');
  await expect(search).toBeVisible();
  await expect(page.locator('#pokemon-list li.pcard').first()).toBeVisible();

  // Search narrows the catalog. NOTE: the search input uses
  // hx-trigger="keyup changed delay:300ms", so real keystrokes are required —
  // fill() dispatches no keyup and the debounced request never fires.
  // 'bulbasaur' is a base form, so it survives the base-form-only filter.
  await search.click();
  await search.pressSequentially('bulbasaur', { delay: 50 });
  await expect(page.locator('#pokemon-list')).toContainText('bulbasaur');

  // Add the first matching card; derive the expected name from its
  // accessible label ("Adicionar <name> ao time") — codegen-style ladder:
  // role > accessible name, no CSS for the action itself.
  const addBtn = page.getByRole('button', { name: /Adicionar .* ao time/ }).first();
  const label = (await addBtn.getAttribute('aria-label')) ?? '';
  const name = label.replace(/^Adicionar /, '').replace(/ ao time$/, '');
  expect(name.length).toBeGreaterThan(0);

  await addBtn.click();

  // Objective asserts: confirmation text, roster membership, badge count.
  await expect(page.locator('#add-status')).toContainText('Adicionado ao time.');
  await expect(page.locator('#roster')).toContainText(name);
  await expect(page.locator('#nav-badge')).toContainText('1/6');
});
