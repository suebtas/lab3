const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 120000,
  expect: { timeout: 10000 },
  reporter: [
    ['list'],
    ['json', { outputFile: 'test-results/results.json' }],
    ['html', { outputFolder: 'playwright-report', open: 'never' }]
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://startup-hr-web:8080',
    actionTimeout: 10000,
    navigationTimeout: 30000,
    screenshot: 'on',
    trace: 'on',
    video: 'retain-on-failure',
    viewport: { width: 1280, height: 800 },
  },
  webServer: null,
  outputDir: 'test-results'
});
