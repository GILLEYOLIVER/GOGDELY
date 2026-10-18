// Hosted PWA release check. The local PWA uses pwa_update.js separately.
(() => {
  const app = document.querySelector('meta[name="gogdely-app"]')?.content;
  if (!app) return;
  const key = `gogdely-${app}-hosted-commit`;
  let checking = false;

  async function checkRelease() {
    if (checking || document.visibilityState === 'hidden') return;
    checking = true;
    try {
      const response = await fetch('version.json', { cache: 'no-store' });
      if (!response.ok) return;
      const { commit } = await response.json();
      if (typeof commit !== 'string' || !/^[a-f0-9]{40}$/.test(commit)) return;
      const previous = localStorage.getItem(key);
      localStorage.setItem(key, commit);
      if (previous && previous !== commit &&
          sessionStorage.getItem(`${key}-reload`) !== commit) {
        sessionStorage.setItem(`${key}-reload`, commit);
        window.location.reload();
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
