/* Rebrand: replace every OPENS3 logo variant with MinIO branding.
   - Full ApplicationLogo wordmark (svg viewBox 0 0 375 112.5): sidebar + login.
   - Collapsed sidebar icon (.collapsedIcon svg viewBox 0 0 300 300): square mark.
   Keys off SVG viewBox (not the minified bundle hash), so it survives console
   rebuilds. A MutationObserver re-applies on React re-renders. */
(function () {
  function swapFull(g) {
    g.dataset.minioSwapped = '1';
    g.style.display = 'none';
    var img = document.createElement('img');
    img.src = '/minio-logo-white.svg';
    img.alt = 'MinIO';
    img.style.height = 'auto';
    img.style.display = 'block';
    img.style.cursor = 'pointer';
    if (g.closest('.menuLogoContainer')) {
      img.style.width = '150px';   // sidebar: left-aligned
      img.style.margin = '6px 0';
    } else {
      img.style.width = '170px';   // login: centered
      img.style.margin = '6px auto';
    }
    g.parentElement.insertBefore(img, g.nextSibling);
  }
  function swapIcon(g) {
    g.dataset.minioSwapped = '1';
    g.style.display = 'none';
    var img = document.createElement('img');
    img.src = '/minio-favicon.svg';
    img.alt = 'MinIO';
    img.style.width = '30px';
    img.style.height = '30px';
    img.style.display = 'block';
    img.style.cursor = 'pointer';
    g.parentElement.insertBefore(img, g.nextSibling);
  }
  function run() {
    document.querySelectorAll('svg[viewBox="0 0 375 112.5"]:not([data-minio-swapped])').forEach(swapFull);
    document.querySelectorAll('.collapsedIcon svg[viewBox="0 0 300 300"]:not([data-minio-swapped])').forEach(swapIcon);
  }
  function init() {
    run();
    new MutationObserver(run).observe(document.body, { childList: true, subtree: true });
  }
  if (document.body) init();
  else document.addEventListener('DOMContentLoaded', init);
})();
