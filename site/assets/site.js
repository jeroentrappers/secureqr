// Decorative QR code in the hero phone (not a real code).
(function () {
  var n = 21, c = 100 / n, s = '';
  function on(x, y) {
    var corners = [[0, 0], [14, 0], [0, 14]];
    for (var i = 0; i < 3; i++) {
      var dx = x - corners[i][0], dy = y - corners[i][1];
      if (dx >= 0 && dy >= 0 && dx <= 6 && dy <= 6) return Math.max(Math.abs(dx - 3), Math.abs(dy - 3)) !== 2;
    }
    if ((x < 8 && y < 8) || (x > 12 && y < 8) || (x < 8 && y > 12)) return false;
    return ((x * 7 + y * 13 + x * y * 3) % 5 < 2) !== ((x + y) % 7 === 0);
  }
  for (var y = 0; y < n; y++) for (var x = 0; x < n; x++)
    if (on(x, y)) s += '<rect x="' + (x * c).toFixed(2) + '" y="' + (y * c).toFixed(2) + '" width="' + (c + 0.3).toFixed(2) + '" height="' + (c + 0.3).toFixed(2) + '"/>';
  var el = document.getElementById('qr');
  if (el) el.innerHTML = '<svg viewBox="-8 -8 116 116"><rect x="-8" y="-8" width="116" height="116" fill="#f4f4f1"/><g fill="#15161a">' + s + '</g></svg>';
})();

// Demo: a scripted playback of three made-up checks. Nothing is sent anywhere.
(function () {
  var steps = document.getElementById('d-steps');
  if (!steps) return;
  var $ = function (id) { return document.getElementById(id); };
  var HEAD = { ok: 'No warning signs found', caution: 'Check this one', danger: 'This looks risky' };
  var ICON = { ok: '✓', caution: '⚠', danger: '✕' };
  var CLS = { ok: '', caution: 'warn', danger: 'bad' };

  var DEMOS = {
    parcel: {
      url: 'https://qr-go.example/x7Pq',
      hops: ['qr-go.example', 'trk.mailing.example', 'pay-fee.parcel-track.example'],
      lists: 'Not on 4 blocklists', redirects: '2 redirects', forms: 'Asks for card details',
      level: 'caution', https: true, host: 'pay-fee.', domain: 'parcel-track.example',
      reasons: ['Ends at a different site than it starts', 'The page asks for card details'],
      chips: [['HTTPS'], ['2 redirects'], ['Not on blocklists']],
      page: { colour: '#c33', title: 'Your parcel is on hold', text: 'Pay the €1.99 customs fee to release delivery.', fields: ['Card number', 'Expiry date'], button: 'Pay now' }
    },
    menu: {
      url: 'https://menu.cafe-lindeboom.example/table/12',
      hops: ['menu.cafe-lindeboom.example'],
      lists: 'Not on 4 blocklists', redirects: 'No redirects', forms: 'No sign-in or payment forms',
      level: 'ok', https: true, host: 'menu.', domain: 'cafe-lindeboom.example',
      reasons: [],
      chips: [['HTTPS'], ['No redirects'], ['Not on blocklists']],
      page: { colour: '#2f6b4f', title: 'Café Lindeboom', text: 'Table 12 · Today’s menu', lines: ['Soup of the day  6.50', 'Croque monsieur  11.00', 'Apple pie  5.50', 'Coffee  3.20'] }
    },
    prize: {
      url: 'http://win-a-phone.example/claim',
      hops: ['win-a-phone.example', 'secure-login.prize-claim.example'],
      lists: 'Listed as malicious by Quad9 and Cloudflare', listsBad: true, redirects: '1 redirect', forms: 'Asks for a password',
      level: 'danger', https: true, host: 'secure-login.', domain: 'prize-claim.example',
      reasons: ['Listed as malicious by Quad9 and Cloudflare', 'Ends at a different site than it starts', 'The page asks for a password'],
      chips: [['HTTPS'], ['1 redirect'], ['On a blocklist', 'bad']],
      page: { colour: '#5a39c6', title: 'Congratulations! Confirm your prize', text: 'Sign in with your email account to claim your new phone.', fields: ['Email address', 'Password'], button: 'Claim now' }
    }
  };

  function add(parent, tag, text, cls) {
    var el = document.createElement(tag);
    if (text != null) el.textContent = text;
    if (cls) el.className = cls;
    parent.appendChild(el);
    return el;
  }

  var timers = [];
  var still = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function at(ms, fn) { if (still) fn(); else timers.push(setTimeout(fn, ms)); }

  function row(id, label) {
    var li = add(steps, 'li', null, 'active');
    li.id = 'd-step-' + id;
    add(li, 'i');
    add(li, 'span', label);
    return li;
  }
  function done(id, label, bad) {
    var li = $('d-step-' + id);
    li.className = bad ? 'done bad' : 'done';
    li.querySelector('span').textContent = label;
  }

  function result(d) {
    $('d-verdict').className = 'verdict ' + CLS[d.level];
    $('d-icon').textContent = ICON[d.level];
    $('d-head').textContent = HEAD[d.level];
    $('d-sub').textContent = d.reasons[0] || 'Nothing unusual about where this link ends.';
    $('d-chrome').textContent = (d.https ? '🔒 ' : '') + d.host + d.domain;

    var pg = $('d-page'); pg.textContent = '';
    add(pg, 'div', null, 'brandbar').style.background = d.page.colour;
    add(pg, 'h5', d.page.title);
    add(pg, 'p', d.page.text);
    (d.page.lines || []).forEach(function (t) { add(pg, 'div', t, 'ln'); });
    (d.page.fields || []).forEach(function (t) { add(pg, 'div', t, 'f'); });
    if (d.page.button) add(pg, 'div', d.page.button, 'b').style.background = d.page.colour;

    var fin = $('d-final'); fin.textContent = d.host;
    add(fin, 'em', d.domain);
    $('d-finalcard').className = 'card ' + (d.level === 'danger' ? 'bad-hl' : d.level === 'caution' ? 'warn-hl' : '');
    var chips = $('d-chips'); chips.textContent = '';
    d.chips.forEach(function (c) { add(chips, 'span', c[0], c[1]); });
    var list = $('d-reasons'); list.textContent = '';
    if (!d.reasons.length) add(list, 'li', 'No warning signs found. That is not a guarantee.');
    d.reasons.forEach(function (t) { add(list, 'li', t); });
    $('d-result').hidden = false;
  }

  function play(name) {
    var d = DEMOS[name];
    timers.forEach(clearTimeout); timers = [];
    Array.prototype.forEach.call(document.querySelectorAll('.pick'), function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-demo') === name ? 'true' : 'false');
    });
    $('d-url').textContent = d.url;
    steps.textContent = '';
    $('d-result').hidden = true;

    var t = 250;
    at(t, function () { row('lists', 'Checking threat blocklists'); row('address', 'Looking up the address'); });
    at(t += 450, function () { done('address', 'Address found'); });
    at(t += 200, function () {
      var li = row('redirects', 'Following the link');
      add(li, 'ol', null, 'dhops');
    });
    d.hops.forEach(function (h) {
      at(t += 420, function () { add($('d-step-redirects').querySelector('ol'), 'li', h); });
    });
    at(t += 350, function () { row('page', 'Loading the page'); });
    at(t += 900, function () {
      done('redirects', d.redirects); done('page', 'Page loaded');
      row('forms', 'Looking for sign-in and payment forms'); row('picture', 'Taking a picture of the page');
    });
    at(t += 350, function () { done('lists', d.lists, d.listsBad); });
    at(t += 250, function () { done('forms', d.forms); });
    at(t += 300, function () { done('picture', 'Picture taken'); });
    at(t += 500, function () { result(d); });
  }

  Array.prototype.forEach.call(document.querySelectorAll('.pick'), function (b) {
    b.addEventListener('click', function () { play(b.getAttribute('data-demo')); });
  });

  // Start the first example when the section scrolls into view.
  var section = document.getElementById('demo'), started = false;
  function first() { if (!started) { started = true; play('parcel'); } }
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (e) { if (e[0].isIntersecting) { io.disconnect(); first(); } }, { threshold: 0.35 });
    io.observe(section);
  } else first();
})();
