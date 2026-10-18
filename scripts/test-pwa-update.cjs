const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '..', 'apps', 'cliente', 'web', 'pwa_update.js'),
  'utf8',
);
const events = {};
const storage = new Map();
let serverVersion = 'build-1';
let reloads = 0;
const context = {
  document: {
    visibilityState: 'visible',
    addEventListener: (name, listener) => { events[name] = listener; },
  },
  window: {
    addEventListener: (name, listener) => { events[name] = listener; },
    setInterval: () => 1,
    location: { reload: () => { reloads += 1; } },
  },
  localStorage: {
    getItem: (key) => storage.get(key) ?? null,
    setItem: (key, value) => storage.set(key, value),
  },
  fetch: async (_url, options) => {
    assert.equal(options.cache, 'no-store');
    return {
      ok: true,
      status: 200,
      headers: { get: () => 'text/plain; charset=utf-8' },
      text: async () => serverVersion,
    };
  },
};

async function main() {
  vm.runInNewContext(source, context);
  await events.pageshow();
  assert.equal(reloads, 0);
  serverVersion = 'build-2';
  await events.visibilitychange();
  assert.equal(reloads, 1);
  await events.visibilitychange();
  assert.equal(reloads, 1);
  const htmlEvents = {};
  let htmlReloads = 0;
  vm.runInNewContext(source, {
    document: {
      visibilityState: 'visible',
      addEventListener: (name, listener) => { htmlEvents[name] = listener; },
    },
    window: {
      addEventListener: (name, listener) => { htmlEvents[name] = listener; },
      setInterval: () => 1,
      location: { reload: () => { htmlReloads += 1; } },
    },
    localStorage: context.localStorage,
    fetch: async () => ({
      ok: true,
      status: 200,
      headers: { get: () => 'text/html' },
      text: async () => '<html>not a version</html>',
    }),
  });
  await htmlEvents.pageshow();
  assert.equal(htmlReloads, 0);
  console.log('PWA update check passed');
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
