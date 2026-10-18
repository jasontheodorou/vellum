// Vellum page: the logo's wave, the typing, and switching between windows.
// The page reads in full without this file.

const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch {} },
};

// ---------- Logo: a small wave runs across it, and the blocks shimmer ----------

const logo = document.querySelector('.logo');
const pre = logo.querySelector('pre');
const cols = [];
const rows = pre.textContent.split('\n');
pre.textContent = '';
rows.forEach((row, r) => {
  [...row].forEach((c, i) => {
    if (c === ' ') { pre.append(' '); return; }
    const s = document.createElement('span');
    s.className = 'ch';
    s.textContent = c;
    (cols[i] ||= []).push(s);
    pre.append(s);
  });
  if (r < rows.length - 1) pre.append('\n');
});

let waving = false;
const wave = () => {
  if (waving || reduce) return;
  waving = true;
  cols.forEach((col, i) => {
    if (!col) return;
    setTimeout(() => {
      col.forEach((s) => {
        s.classList.add('up');
        if (s.textContent === '█') { s.dataset.block = '1'; s.textContent = '▓'; }
      });
      setTimeout(() => col.forEach((s) => {
        s.classList.remove('up');
        if (!s.dataset.block) return;
        s.textContent = '▒';
        setTimeout(() => { s.textContent = '█'; delete s.dataset.block; }, 90);
      }), 200);
    }, i * 16);
  });
  setTimeout(() => { waving = false; }, cols.length * 16 + 600);
};
logo.addEventListener('pointerenter', wave);
logo.addEventListener('focus', wave);
logo.addEventListener('click', wave);

// ---------- Windows: bring one forward and Claude greets you with its recap ----------

const stage = document.querySelector('.stage');
const wins = [...stage.querySelectorAll('.win')];
const hint = stage.querySelector('.stage__hint');
let order = wins.map((_, i) => i);
const timers = new Map();

// Wrap each line so it can be uncovered a character at a time
wins.forEach((win) => {
  win.querySelectorAll('.win__cmd, .win__recap, .win__you, .win__claude').forEach((p) => {
    const t = document.createElement('span');
    t.className = 't';
    while (p.firstChild) t.appendChild(p.firstChild);
    p.appendChild(t);
  });
});

const layout = () => {
  order.forEach((w, slot) => {
    wins[w].style.setProperty('--slot', slot);
    wins[w].querySelector('.win__bar').setAttribute('aria-pressed', String(slot === 0));
  });
};

// Pauses after each line: the command, the recap, the question, the answer
const PAUSES = [350, 900, 450, 0];
const type = (win) => {
  (timers.get(win) || []).forEach(clearTimeout);
  const lines = [...win.querySelectorAll('.t')];
  lines.forEach((t) => t.classList.remove('typed'));
  if (reduce) { lines.forEach((t) => t.classList.add('typed')); return; }
  void win.offsetWidth;
  const list = [];
  let at = 250;
  lines.forEach((t, i) => {
    const n = t.textContent.length;
    const dur = Math.min(n * 16, 1300);
    t.style.setProperty('--steps', n);
    t.style.setProperty('--dur', `${dur}ms`);
    list.push(setTimeout(() => t.classList.add('typed'), at));
    at += dur + (PAUSES[i] ?? 300);
  });
  timers.set(win, list);
};

const bringForward = (i) => {
  order = [i, ...order.filter((w) => w !== i)];
  layout();
  type(wins[i]);
  if (hint && !hint.classList.contains('gone')) {
    hint.classList.add('gone');
    store.set('vellum-hint-seen', '1');
  }
};

wins.forEach((win, i) => {
  win.querySelector('.win__bar').addEventListener('click', () => bringForward(i));
});

if (store.get('vellum-hint-seen')) hint.classList.add('gone');
layout();

// Back windows show finished text; the front one types when it comes into view
wins.slice(1).forEach((w) => w.querySelectorAll('.t').forEach((t) => t.classList.add('typed')));
if ('IntersectionObserver' in window && !reduce) {
  const io = new IntersectionObserver((entries) => {
    if (!entries[0].isIntersecting) return;
    type(wins[order[0]]);
    io.disconnect();
  }, { threshold: 0.4 });
  io.observe(stage);
} else {
  wins[0].querySelectorAll('.t').forEach((t) => t.classList.add('typed'));
}

// ---------- Copy the install line ----------

const copy = document.querySelector('.install__copy');
if (navigator.clipboard && copy) {
  copy.hidden = false;
  copy.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(document.querySelector('.install__box code').textContent);
      copy.textContent = 'Copied';
    } catch {
      copy.textContent = 'Select and copy';
    }
    setTimeout(() => { copy.textContent = 'Copy'; }, 2000);
  });
}
