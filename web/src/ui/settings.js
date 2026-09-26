// Settings tab: six sections (language, location, voice, playback, deck, progress).
import { el, setText, show, makeChips } from './dom.js';
import { t, catLabel, AUTONYM, chromeLang } from '../i18n.js';
import { settings, persistKnown, store, CATS, LANGS, setLocation } from '../settings.js';
import { applySettings } from '../engine.js';
import { PLACES, districtOptions } from '../officials.js';
import { renderCard } from './flashcards.js';
import { applyChrome, renderAll } from '../main.js';

/* Place names show in the UI language (4 chrome languages); everything else English. */
function placeName(p) {
  const cl = chromeLang();
  return p.name[cl === 'en' ? 'english' : cl] || p.name.english;
}

function fillSelect(sel, items, current, key) {
  if (sel.dataset.key !== key) {
    sel.dataset.key = key;
    sel.innerHTML = '';
    for (const it of items) {
      const o = document.createElement('option');
      o.value = it.value;
      o.textContent = it.label;
      sel.appendChild(o);
    }
  }
  sel.value = current;
}

function renderLocation() {
  const code = settings.jurisdiction || '';
  fillSelect('s-place',
    [{ value: '', label: t('settings_not_set') }]
      .concat(PLACES.map(p => ({ value: p.code, label: placeName(p) }))),
    code, code + '|' + chromeLang());
  const place = code ? PLACES.find(p => p.code === code) : null;
  const multi = !!place && place.seats > 1;
  show('s-dist-wrap', multi);
  if (multi) {
    const opts = districtOptions(code);
    fillSelect('s-dist',
      [{ value: '', label: t('settings_not_set') }]
        .concat(opts.map(o => ({
          value: String(o.district),
          label: t('settings_district') + ' ' + o.district + (o.name ? ' · ' + o.name : ''),
        }))),
      settings.district != null ? String(settings.district) : '',
      code + '|' + chromeLang() + '|' + opts.map(o => o.name).join(','));
  }
}

export function renderSettings() {
  makeChips('s-lang-chips',
    [{ value: 'system', label: t('ui_system') }].concat(LANGS.map(l => ({ value: l, label: AUTONYM[l] }))),
    settings.language, v => {
      settings.language = v;
      applySettings();
      applyChrome();
      renderAll();
    });
  renderLocation();
  setText('s-rate-label', t('speech_rate', settings.speechRate.toFixed(2)));
  el('s-rate').value = settings.speechRate;
  el('s-announce').checked = settings.announceMeta;
  makeChips('s-think-chips', [
    { value: -1, label: t('think_wait') },
    { value: 0, label: t('think_none') },
    { value: 3, label: t('think_seconds', 3) },
    { value: 5, label: t('think_seconds', 5) },
    { value: 10, label: t('think_seconds', 10) },
  ], settings.thinkSeconds, v => { settings.thinkSeconds = v; applySettings(); });
  el('s-auto').checked = settings.autoAdvance;
  makeChips('s-cat-chips', CATS.map(c => ({ value: c, label: catLabel(c) })),
    settings.category, v => { settings.category = v; applySettings(); });
  el('s-shuffle').checked = settings.shuffle;
  setText('s-known-label', t('known_progress', settings.known.size));
}
el('s-rate').addEventListener('input', () => {
  const v = Math.round(parseFloat(el('s-rate').value) * 20) / 20;
  settings.speechRate = Math.min(1.5, Math.max(0.75, v));
  setText('s-rate-label', t('speech_rate', settings.speechRate.toFixed(2)));
  store.set('speech_rate', settings.speechRate);
});
el('s-announce').addEventListener('change', () => { settings.announceMeta = el('s-announce').checked; applySettings(); });
el('s-auto').addEventListener('change', () => { settings.autoAdvance = el('s-auto').checked; applySettings(); });
el('s-shuffle').addEventListener('change', () => { settings.shuffle = el('s-shuffle').checked; applySettings(); });
el('s-place').addEventListener('change', () => {
  setLocation(el('s-place').value || null, null);
  applySettings();
  renderAll();
});
el('s-dist').addEventListener('change', () => {
  const v = el('s-dist').value;
  setLocation(settings.jurisdiction, v ? parseInt(v, 10) : null);
  applySettings();
  renderAll();
});
el('s-clear').onclick = () => { settings.known.clear(); persistKnown(); applySettings(); renderCard(); };
