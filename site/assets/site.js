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

// "Try it": everything that comes back from the server is written with textContent only.
(function () {
  var form = document.getElementById('check');
  if (!form) return;
  var $ = function (id) { return document.getElementById(id); };
  var input = $('url'), button = form.querySelector('button'), status = $('status'), result = $('result');
  var HEAD = { ok: 'No warning signs found', caution: 'Check this one', danger: 'This looks risky' };
  var ICON = { ok: '✓', caution: '⚠', danger: '✕' };
  var CLS = { ok: '', caution: 'warn', danger: 'bad' };

  function say(text, isError) {
    status.textContent = text;
    status.className = 'status' + (isError ? ' err' : '');
  }
  function add(parent, tag, text, cls) {
    var el = document.createElement(tag);
    if (text != null) el.textContent = text;
    if (cls) el.className = cls;
    parent.appendChild(el);
    return el;
  }

  function show(r) {
    var level = HEAD[r.verdict && r.verdict.level] ? r.verdict.level : 'caution';
    var reasons = (r.verdict && r.verdict.reasons) || [];
    $('r-verdict').className = 'verdict ' + CLS[level];
    $('r-icon').textContent = ICON[level];
    $('r-head').textContent = HEAD[level];
    $('r-sub').textContent = reasons.length ? reasons[0].message : 'Nothing unusual about where this link ends.';

    $('r-chrome').textContent = (r.https ? '🔒 ' : '') + r.finalHost;
    var img = $('r-shot'), none = $('r-noshot');
    if (r.screenshotUrl && /^\/v1\/screenshots\/[0-9a-f]+\.jpg$/.test(r.screenshotUrl)) {
      img.src = r.screenshotUrl; img.hidden = false; none.hidden = true;
    } else { img.removeAttribute('src'); img.hidden = true; none.hidden = false; }

    var fin = $('r-final'); fin.textContent = '';
    var host = String(r.finalHost || ''), dom = String(r.finalDomain || '');
    if (dom && host.length > dom.length && host.slice(-dom.length) === dom) {
      fin.appendChild(document.createTextNode(host.slice(0, host.length - dom.length)));
      add(fin, 'em', dom);
    } else add(fin, 'em', host);
    fin.parentNode.className = 'card ' + (level === 'danger' ? 'bad-hl' : level === 'caution' ? 'warn-hl' : '');

    var chips = $('r-chips'); chips.textContent = '';
    add(chips, 'span', r.https ? 'HTTPS' : 'Not encrypted', r.https ? '' : 'bad');
    var redirects = Math.max(0, (r.hops || []).length - 1);
    add(chips, 'span', redirects === 0 ? 'No redirects' : redirects === 1 ? '1 redirect' : redirects + ' redirects');
    var rep = r.reputation;
    if (rep && rep.flaggedBy && rep.flaggedBy.length) add(chips, 'span', 'On a blocklist', 'bad');
    else if (rep && rep.checked && rep.checked.length) add(chips, 'span', 'Not on blocklists');

    var list = $('r-reasons'); list.textContent = '';
    if (!reasons.length) add(list, 'li', 'No warning signs found. That is not a guarantee.');
    reasons.forEach(function (x) { add(list, 'li', x.message); });

    var hops = $('r-hops'); hops.textContent = '';
    (r.hops || []).forEach(function (h) {
      var li = add(hops, 'li', h.host);
      var kind = h.kind === 'start' ? 'The link you gave' : h.kind === 'client' ? 'Redirected by the page' : 'Redirected';
      add(li, 'small', kind + (h.status ? ' · ' + h.status : ''));
    });
    result.hidden = false;
  }

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    var url = input.value.trim();
    if (!url) return;
    if (!/^https?:\/\//i.test(url)) { url = 'https://' + url; input.value = url; }
    button.disabled = true; result.hidden = true;
    say('Following the link for you… this can take a few seconds.');
    fetch('/v1/preview', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ url: url }) })
      .then(function (res) { return res.json().then(function (body) { return { ok: res.ok, body: body }; }); })
      .then(function (x) {
        if (!x.ok) { say((x.body && x.body.error && x.body.error.message) || 'Something went wrong. Try again.', true); return; }
        say('Done in ' + (x.body.durationMs / 1000).toFixed(1) + ' s.');
        show(x.body);
      })
      .catch(function () { say('We could not reach the checking service. Try again in a moment.', true); })
      .then(function () { button.disabled = false; });
  });
})();
