// Design tool: names every vertical gap (V1, V2 ...) with its measured size,
// and lets the spacing scale be changed live. Remove when spacing is signed off.
// Hidden unless the address ends in ?spacing, so visitors never see it and saved slider values never apply.

(() => {
if (!new URLSearchParams(location.search).has('spacing')) return;

const root = document.documentElement;
const wrap = document.querySelector('.spacing');
const panel = wrap.querySelector('.spacing__panel');
const toggle = wrap.querySelector('.spacing__toggle');
const rows = wrap.querySelector('.spacing__rows');
const overlay = document.querySelector('.spacing-overlay');

const TOKENS = [
  ['--gap-top', 'Top of page'],
  ['--gap-title', 'Title to statement'],
  ['--gap-window', 'Statement to window'],
  ['--gap-block', 'Between blocks'],
  ['--gap-para', 'Between paragraphs'],
  ['--gap-head', 'Heading to text'],
];
const defaults = Object.fromEntries(TOKENS.map(([t]) => [t, parseFloat(getComputedStyle(root).getPropertyValue(t))]));

const store = {
  get() { try { return JSON.parse(localStorage.getItem('vellum-spacing') || '{}'); } catch { return {}; } },
  set(v) { try { localStorage.setItem('vellum-spacing', JSON.stringify(v)); } catch {} },
};

// Each gap: [from element, to element]. "page" means the top of the page.
const $ = (s) => document.querySelector(s);
const gaps = () => {
  const list = [['page', $('.title')], [$('.title'), $('.statement p')]];
  const sp = [...document.querySelectorAll('.statement p')];
  sp.forEach((p, j) => { if (j) list.push([sp[j - 1], p]); });
  list.push([sp[sp.length - 1], $('.window')], [$('.window'), $('.benefit')]);
  document.querySelectorAll('.benefit').forEach((b, i, all) => {
    const ps = b.querySelectorAll('p');
    list.push([b.querySelector('h2'), ps[0]]);
    ps.forEach((p, j) => { if (j) list.push([ps[j - 1], p]); });
    list.push([ps[ps.length - 1], all[i + 1] || $('.install h2')]);
  });
  list.push([$('.install h2'), $('.install p')], [$('.install p'), $('.install__line')], [$('.install__line'), $('.close__link')]);
  return list;
};

const draw = () => {
  overlay.textContent = '';
  const left = $('.title').getBoundingClientRect().left;
  gaps().forEach(([a, b], i) => {
    const top = a === 'page' ? 0 : a.getBoundingClientRect().bottom + scrollY;
    const bottom = b.getBoundingClientRect().top + scrollY;
    const h = bottom - top;
    const band = document.createElement('div');
    band.className = 'spacing-overlay__band';
    band.style.cssText = `top:${top}px;height:${h}px;left:${left - 4}px`;
    band.innerHTML = `<span>V${i + 1} ${Math.round(h * 10) / 10}</span>`;
    overlay.appendChild(band);
  });
};

const apply = (values) => {
  TOKENS.forEach(([t]) => root.style.setProperty(t, `${values[t] ?? defaults[t]}px`));
};

TOKENS.forEach(([token, label]) => {
  const id = `sp${token}`;
  const row = document.createElement('div');
  row.className = 'spacing__row';
  row.innerHTML = `<label for="${id}">${label}</label><input id="${id}" type="range" min="0" max="200" step="4"><output></output>`;
  const input = row.querySelector('input');
  const out = row.querySelector('output');
  input.addEventListener('input', () => {
    const v = store.get(); v[token] = +input.value; store.set(v);
    out.textContent = input.value;
    apply(v);
    requestAnimationFrame(draw);
  });
  rows.appendChild(row);
});

const sync = () => {
  const v = store.get();
  rows.querySelectorAll('.spacing__row').forEach((row, i) => {
    const t = TOKENS[i][0];
    const val = v[t] ?? defaults[t];
    row.querySelector('input').value = val;
    row.querySelector('output').textContent = val;
  });
  apply(v);
};

wrap.querySelector('.spacing__reset').addEventListener('click', () => {
  store.set({}); sync(); requestAnimationFrame(draw);
});

toggle.addEventListener('click', () => {
  const on = panel.hidden;
  panel.hidden = !on;
  overlay.hidden = !on;
  toggle.setAttribute('aria-expanded', String(on));
  toggle.textContent = on ? 'Spacing on' : 'Spacing off';
  if (on) requestAnimationFrame(draw);
});

window.addEventListener('resize', () => { if (!overlay.hidden) draw(); });
sync();
wrap.hidden = false;
})();
