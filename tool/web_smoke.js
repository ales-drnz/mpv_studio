// Opens the web build the way GitHub Pages serves it and checks that it
// boots: a page that becomes cross-origin isolated through
// coi-serviceworker.js, with that worker as the only one of its scope, the
// libmpv web module of mpv_audio_kit loaded, and no uncaught error. Saves a
// screenshot, and says whether the demo stream answers a page of another
// origin (CORS), which the browser needs to play it.
//
// The site must be served without COOP and COEP headers, as Pages does, at
// <url>; tool/web_smoke.sh does that.
//
//   node tool/web_smoke.js <url> <screenshot.png>

const { chromium } = require('playwright');

const DEMO_STREAM = 'https://streams.radiomast.io/ref-128k-mp3-stereo';

(async () => {
  const [url, shot] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const failures = [];
  const module = new Map();
  page.on('pageerror', (e) => failures.push(`uncaught error: ${e.message}`));
  page.on('console', (m) => {
    console.log(`console.${m.type()}: ${m.text()}`);
    if (/PlayerInitException/.test(m.text())) failures.push(`player: ${m.text()}`);
  });
  page.on('response', (r) => {
    const name = r.url().split('/').pop();
    if (/^(libmpv\.(mjs|wasm)|mak_webaudio_processor\.js)$/.test(name)) {
      module.set(name, r.status());
    }
  });

  await page.goto(url);
  // The first visit registers the worker and reloads once.
  await page.waitForTimeout(25000);

  const state = await page.evaluate(async () => ({
    isolated: self.crossOriginIsolated,
    controller: navigator.serviceWorker.controller?.scriptURL ?? null,
    workers: (await navigator.serviceWorker.getRegistrations()).map(
      (r) => r.active?.scriptURL ?? null,
    ),
  }));
  console.log(JSON.stringify({ ...state, module: Object.fromEntries(module) }));

  if (!state.isolated) failures.push('the page is not cross-origin isolated');
  if (!state.controller?.endsWith('/coi-serviceworker.js')) {
    failures.push(`the page is controlled by ${state.controller}`);
  }
  if (state.workers.length !== 1) {
    failures.push(`${state.workers.length} service workers: ${state.workers}`);
  }
  for (const name of ['libmpv.mjs', 'libmpv.wasm']) {
    if (module.get(name) !== 200) {
      failures.push(`${name} answered ${module.get(name) ?? 'nothing'}`);
    }
  }

  // Informational: a stream without CORS headers cannot play in a page.
  const cors = await page.evaluate(async (u) => {
    const abort = new AbortController();
    setTimeout(() => abort.abort(), 10000);
    try {
      const r = await fetch(u, { signal: abort.signal });
      abort.abort();
      return `HTTP ${r.status}`;
    } catch (e) {
      return `refused (${e.name})`;
    }
  }, DEMO_STREAM);
  console.log(`demo stream from the page: ${cors}`);

  await page.screenshot({ path: shot });
  await browser.close();
  if (failures.length) {
    for (const f of failures) console.log(`::error::${f}`);
    process.exit(1);
  }
  console.log('the web build boots');
})();
