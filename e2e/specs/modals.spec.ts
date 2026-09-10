import { test, expect, type Page } from '@playwright/test';

// P0: modal open + close for manage / center / mart.
// Open trigger ladder: role(link) > accessible name. Close: role(button,
// "Fechar") scoped inside the dialog. Close swaps the modal slot back to an
// empty div (outerHTML), so the dialog must detach — asserted with
// toBeHidden (passes on detached nodes).

async function expectModalCycle(page: Page, openName: string, dialogName: string) {
  await page.goto('/');
  await expect(page.locator('#pokemon-list li.pcard').first()).toBeVisible();

  await page.getByRole('link', { name: openName, exact: true }).click();
  const dialog = page.getByRole('dialog', { name: dialogName });
  await expect(dialog).toBeVisible();

  await dialog.getByRole('button', { name: 'Fechar' }).click();
  await expect(dialog).toBeHidden();
}

test('manage modal opens and closes', async ({ page }) => {
  await expectModalCycle(page, 'Gerenciar time', 'Gerenciar Pokémon');
});

test('center modal opens and closes', async ({ page }) => {
  await expectModalCycle(page, 'Curar no Poke Center', 'Poke Center');
});

test('mart modal opens and closes', async ({ page }) => {
  await expectModalCycle(page, 'Poke Mart', 'Poke Mart');
});
