const { test, expect } = require('@playwright/test');

// Application resource URLs that must load successfully for the app to work.
// FontManifest.json is the engine's index of bundled app fonts (§17.2.6).
const ASSETS_REQUIRED = [
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/assets/FontManifest.json',
];

// Wait until the Flutter app has really rendered: the engine host element is
// attached, engine-created layers/canvas are present and the title is applied.
// Locator-only (no eval/Function) so the production CSP is untouched.
async function waitForAppReady(page) {
  const flutterView = page.locator('flutter-view').first();
  await expect(flutterView).toBeAttached({ timeout: 30000 });
  const canvas = page.locator('flutter-view canvas').first();
  await expect(canvas.or(page.locator('flt-glass-pane canvas').first()))
    .toBeVisible({ timeout: 30000 });
  await expect(page).toHaveTitle(/startup.?hr/i, { timeout: 30000 });
}

test.describe('startup_hr Flutter Web smoke test', () => {
  test('loads the app, boots Flutter, renders routes, and stays error-free', async ({ page }) => {
    const baseURL = process.env.BASE_URL || 'http://startup-hr-web:8080';
    const faults = [];

    // Register listeners BEFORE page.goto() so nothing escapes capture:
    // console errors (incl. CSP violations), uncaught page errors /
    // unhandled rejections, failed requests and HTTP responses >= 400.
    page.on('console', (msg) => {
      if (msg.type() === 'error') faults.push(`console.error: ${msg.text()}`);
    });
    page.on('pageerror', (err) => faults.push(`pageerror: ${err.message}`));
    page.on('requestfailed', (req) => {
      const failure = req.failure();
      const detail = failure ? failure.errorText : 'unknown';
      faults.push(`requestfailed: ${req.url()} (${detail})`);
    });
    page.on('response', (res) => {
      const status = res.status();
      if (status >= 400) faults.push(`http ${status}: ${res.url()}`);
    });

    // Track which application resources actually loaded (HTTP 200).
    const loadedAssets = new Set();
    page.on('response', (res) => {
      if (res.status() === 200) {
        const path = new URL(res.url()).pathname;
        for (const asset of ASSETS_REQUIRED) {
          if (path === asset) loadedAssets.add(asset);
        }
      }
    });

    // Runtime health endpoint must answer 200 with body "ok".
    const health = await page.request.get(`${baseURL}/healthz`);
    expect(health.status(), 'healthz must answer 200').toBe(200);
    expect((await health.text()).trim(), 'healthz body must be "ok"').toBe('ok');

    // Load the app entry point.
    const response = await page.goto(`${baseURL}/`, { waitUntil: 'domcontentloaded' });
    expect(response).not.toBeNull();
    expect(response.status()).toBe(200);

    // The shell HTML title is delivered by index.html; Flutter later replaces
    // it with the MaterialApp title ("Startup HR"). Wait for the full
    // application-ready signal: engine host + engine-created canvas + title.
    await waitForAppReady(page);

    // Client-side routing: /payroll must load with 200, survive a reload and
    // still render. Each navigation fully boots before the next one starts,
    // so no in-flight request is cancelled by the page reload.
    await page.goto(`${baseURL}/payroll`, { waitUntil: 'domcontentloaded' });
    await expect(page).toHaveTitle(/startup.?hr/i, { timeout: 30000 });
    await waitForAppReady(page);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);

    // Screenshot the rendered app for the test report (also taken on failure
    // via the reporter config's screenshot: 'on').
    await page.screenshot({ path: 'test-results/smoke-flutter-app.png', fullPage: true });

    await page.waitForTimeout(2000);

    // Key runtime assets must have loaded from the image (HTML-200 proof that
    // the bootstrap, engine and renderer assets are actually served).
    for (const asset of ASSETS_REQUIRED) {
      expect(loadedAssets.has(asset), `${asset} must be served (HTTP 200)`).toBe(true);
    }

    // Every console error, page exception, failed request and HTTP >= 400 is
    // a failure: the app must boot and route cleanly. No failures are
    // tolerated or suppressed — each navigation fully boots before the next,
    // so no in-flight request is cancelled by the reload.
    expect(faults, 'browser reported console/page/network faults:\n' + faults.join('\n'))
      .toEqual([]);
  });
});