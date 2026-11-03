// Removes the loading screen once the app appears (see index.html).
// Kept in a file (not inline) so the site's Content-Security-Policy can
// forbid inline scripts.
(function () {
  var el = document.getElementById('dp-loading');
  function done() {
    if (!el) return;
    var x = el; el = null;
    x.style.opacity = '0';
    setTimeout(function () { x.remove(); }, 350);
  }
  // The app has drawn its first screen…
  window.addEventListener('flutter-first-frame', done);
  // …or its view was added to the page (older/newer Flutter versions).
  new MutationObserver(function (_, obs) {
    if (document.querySelector('flutter-view, flt-glass-pane')) { obs.disconnect(); setTimeout(done, 1500); }
  }).observe(document.body, { childList: true, subtree: true });
  // Slow connection: say so instead of spinning silently.
  setTimeout(function () { var s = document.getElementById('dp-slow'); if (el && s) s.style.display = 'block'; }, 20000);
})();
