const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const apps = ['cliente', 'gestao', 'entregador'];
const oldSha = 'a'.repeat(40);
const newSha = 'b'.repeat(40);

async function checkApp(app) {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'apps', app, 'web', 'release_update.js'),
    'utf8',
  );
  const listeners = {};
  const storage = new Map();
  const session = new Map();
  let remoteSha = oldSha;
  let reloads = 0;
  vm.runInNewContext(source, {
    document: {
      visibilityState: 'visible',
      querySelector: () => ({ content: app }),
      addEventListener: (name, handler) => { listeners[name] = handler; },
    },
    window: {
      addEventListener: (name, handler) => { listeners[name] = handler; },
      setInterval: () => 1,
      location: { reload: () => { reloads += 1; } },
    },
    localStorage: {
      getItem: (key) => storage.get(key) ?? null,
      setItem: (key, value) => storage.set(key, value),
    },
    sessionStorage: {
      getItem: (key) => session.get(key) ?? null,
      setItem: (key, value) => session.set(key, value),
    },
    fetch: async (_url, options) => {
      assert.equal(options.cache, 'no-store');
      return { ok: true, json: async () => ({ commit: remoteSha }) };
    },
  });
  await listeners.pageshow();
  assert.equal(reloads, 0);
  remoteSha = newSha;
  await listeners.visibilitychange();
  assert.equal(reloads, 1);
  await listeners.visibilitychange();
  assert.equal(reloads, 1);
}

Promise.all(apps.map(checkApp)).then(
  () => console.log('Hosted PWA release checks passed'),
  (error) => { console.error(error); process.exitCode = 1; },
);
