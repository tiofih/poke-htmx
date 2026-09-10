import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// A11y smoke: axe scan on home, critical + serious only.
test('home has no critical/serious a11y violations', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#pokemon-list li.pcard').first()).toBeVisible();

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();

  const blocking = results.violations.filter((v) =>
    ['critical', 'serious'].includes(v.impact ?? ''),
  );
  expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
});
