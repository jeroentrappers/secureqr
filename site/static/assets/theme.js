// Loaded in <head> without defer, so the chosen theme is applied before the page paints.
// Theme: follows the device unless the visitor picked light or dark (stored in this browser only).
// Language: on the English home page, a first-time visitor whose browser asks for one of the
// other languages is sent there once. Picking a language in the menu is remembered and wins.
(function () {
  var d = document.documentElement;
  function get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function set(k, v) { try { if (v == null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch (e) {} }

  var theme = get('theme');
  if (theme === 'light' || theme === 'dark') d.setAttribute('data-theme', theme);

  if (location.pathname === '/' && !get('lang')) {
    var offered = {};
    Array.prototype.forEach.call(document.querySelectorAll('link[rel="alternate"][hreflang]'), function (l) {
      var h = l.getAttribute('hreflang');
      if (h !== 'x-default') offered[h.toLowerCase().split('-')[0]] = l.getAttribute('href');
    });
    var wanted = navigator.languages || [navigator.language || ''];
    for (var i = 0; i < wanted.length; i++) {
      var base = String(wanted[i]).toLowerCase().split('-')[0];
      if (base === 'en') break;
      if (offered[base]) { location.replace(new URL(offered[base]).pathname + location.hash); return; }
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    Array.prototype.forEach.call(document.querySelectorAll('[data-lang]'), function (a) {
      a.addEventListener('click', function () { set('lang', a.getAttribute('data-lang')); });
    });

    var btn = document.querySelector('button.theme');
    if (!btn) return;
    var next = { system: 'light', light: 'dark', dark: 'system' };
    function current() { return d.getAttribute('data-theme') || 'system'; }
    function label() {
      var name = btn.getAttribute('data-label-' + current()) || current();
      btn.title = name;
      btn.setAttribute('data-state', current());
      btn.setAttribute('aria-label', (btn.getAttribute('data-label') || 'Theme') + ': ' + name);
    }
    btn.setAttribute('data-label', btn.getAttribute('aria-label') || 'Theme');
    btn.addEventListener('click', function () {
      var n = next[current()];
      if (n === 'system') { d.removeAttribute('data-theme'); set('theme', null); }
      else { d.setAttribute('data-theme', n); set('theme', n); }
      label();
    });
    label();
  });
})();
