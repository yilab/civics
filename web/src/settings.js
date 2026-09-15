// Persistence: the civics.* localStorage keys mirror the mobile settings store.
// This module also owns the supported-language and category lists, because the
// stored `language` and `category` values are validated against them at load time.

export const LANGS = ['english', 'zh-Hans', 'zh-Hant', 'es', 'vi', 'tl', 'ko', 'ar', 'hi', 'pt', 'ru'];
export const CATS = ['All', 'American Government', 'American History', 'Symbols & Holidays'];

const DEFAULTS = {
  speech_rate: 1.0, think_seconds: 3, auto_advance: false, category: 'All',
  shuffle: false, announce_meta: true, known: [], known_filter: 'all',
  language: 'system', test_history: [],
};
export const store = {
  get(k) {
    try {
      const v = localStorage.getItem('civics.' + k);
      return v === null ? DEFAULTS[k] : JSON.parse(v);
    } catch (e) { return DEFAULTS[k]; }
  },
  set(k, v) { try { localStorage.setItem('civics.' + k, JSON.stringify(v)); } catch (e) {} },
};

(function migrateLegacy() {
  let old = null;
  try { old = localStorage.getItem('civics-lang'); } catch (e) { return; }
  if (old === null) return;
  const map = { en: 'english', zh: 'zh-Hans', bi: 'zh-Hans' };
  try {
    if (map[old] && localStorage.getItem('civics.language') === null) {
      localStorage.setItem('civics.language', JSON.stringify(map[old]));
    }
    localStorage.removeItem('civics-lang');
  } catch (e) {}
})();

export const settings = {
  speechRate: clampNum(store.get('speech_rate'), 0.75, 1.5, 1.0),
  thinkSeconds: [-1, 0, 3, 5, 10].includes(store.get('think_seconds')) ? store.get('think_seconds') : 3,
  autoAdvance: store.get('auto_advance') === true,
  category: CATS.includes(store.get('category')) ? store.get('category') : 'All',
  shuffle: store.get('shuffle') === true,
  announceMeta: store.get('announce_meta') !== false,
  known: new Set((Array.isArray(store.get('known')) ? store.get('known') : []).filter(n => Number.isInteger(n))),
  knownFilter: ['all', 'known', 'notKnown'].includes(store.get('known_filter')) ? store.get('known_filter') : 'all',
  language: store.get('language') === 'system' || LANGS.includes(store.get('language')) ? store.get('language') : 'system',
};
function clampNum(v, lo, hi, dflt) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : dflt;
}
export function persistSettings() {
  store.set('speech_rate', settings.speechRate);
  store.set('think_seconds', settings.thinkSeconds);
  store.set('auto_advance', settings.autoAdvance);
  store.set('category', settings.category);
  store.set('shuffle', settings.shuffle);
  store.set('announce_meta', settings.announceMeta);
  store.set('known_filter', settings.knownFilter);
  store.set('language', settings.language);
}
export function persistKnown() { store.set('known', Array.from(settings.known).sort((a, b) => a - b)); }

/* ---------- test history ---------- */
export function getHistory() {
  const h = store.get('test_history');
  return Array.isArray(h) ? h : [];
}
export function recordTest(rec) {
  const h = getHistory();
  h.unshift(rec);
  store.set('test_history', h.slice(0, 20));
}
