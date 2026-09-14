import { defineConfig, devices } from '@playwright/test';

// P0 e2e foundation for poke-htmx. App under test runs via ./scripts/run
// (docker compose) at http://localhost:3000. Headless by default.
// Traces retained on failure (attach to report); screenshots only on failure.
export default defineConfig({
  testDir: './specs',
  timeout: 90_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: 'line',
  use: {
    baseURL: 'http://localhost:3000',
    channel: 'chrome',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 15_000,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
