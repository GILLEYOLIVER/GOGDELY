// Local PWA only: the endpoint is absent in other environments.
(() => {
  const endpoint = '/api/v1/local/pwa-version';
  const storageKey = 'gogdely-client-pwa-version';
  let currentVersion = null;
  let checking = false;
  let unavailable = false;

  async function checkVersion() {
    if (checking || unavailable || document.visibilityState === 'hidden') return;
    checking = true;
    try {
      const response = await fetch(endpoint, { cache: 'no-store' });
      if (response.status === 404) {
        unavailable = true;
        return;
      }
      if (!response.ok) return;
      if (!(response.headers.get('content-type') || '').startsWith('text/plain')) {
        unavailable = true;
        return;
      }
      const nextVersion = (await response.text()).trim();
      if (!nextVersion) return;

      let previousVersion = currentVersion;
      if (previousVersion === null) {
        try { previousVersion = localStorage.getItem(storageKey); } catch (_) {}
      }
      currentVersion = nextVersion;
      try { localStorage.setItem(storageKey, nextVersion); } catch (_) {}
      if (previousVersion && previousVersion !== nextVersion) {
        window.location.reload();
      }
    } catch (_) {
      // Keep the currently open app usable if the local computer is offline.
    } finally {
      checking = false;
    }
  }

  window.addEventListener('pageshow', checkVersion);
  document.addEventListener('visibilitychange', checkVersion);
  window.setInterval(checkVersion, 60_000);
})();
