// Hosted PWA release check. The local PWA uses pwa_update.js separately.
(() => {
  const app = document.querySelector('meta[name="gogdely-app"]')?.content;
  if (!app) return;
  const key = `gogdely-${app}-hosted-commit`;
  let checking = false;
  let lastSeen = null;

  async function checkRelease() {
    if (checking || document.visibilityState === 'hidden') return;
    checking = true;
    try {
      const response = await fetch('version.json', { cache: 'no-store' });
      if (!response.ok) return;
      const { commit } = await response.json();
      if (typeof commit !== 'string' || !/^[a-f0-9]{40}$/.test(commit)) return;
      let previous = lastSeen;
      try {
        previous ??= localStorage.getItem(key);
        localStorage.setItem(key, commit);
      } catch (_) {
        // Browser storage can be unavailable; the current session still checks.
      }
      lastSeen = commit;
      const currentUrl = new URL(window.location.href);
      if ((previous && previous !== commit) ||
          (currentUrl.searchParams.has('gogdely_release') &&
           currentUrl.searchParams.get('gogdely_release') !== commit)) {
        currentUrl.searchParams.set('gogdely_release', commit);
        window.location.replace(currentUrl.toString());
      }
    } catch (_) {
      // Offline users keep the last usable build until the host is reachable.
    } finally {
      checking = false;
    }
  }

  window.addEventListener('pageshow', checkRelease);
  document.addEventListener('visibilitychange', checkRelease);
  window.setInterval(checkRelease, 60_000);
})();
