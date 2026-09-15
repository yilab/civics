// Settings tab: five sections (language, voice, playback, deck, progress).
import { el, setText, makeChips } from './dom.js';
import { t, catLabel, AUTONYM } from '../i18n.js';
import { settings, persistKnown, store, CATS, LANGS } from '../settings.js';
import { applySettings } from '../engine.js';
import { renderCard } from './flashcards.js';
import { applyChrome, renderAll } from '../main.js';

export function renderSettings() {
  makeChips('s-lang-chips',
    [{ value: 'system', label: t('ui_system') }].concat(LANGS.map(l => ({ value: l, label: AUTONYM[l] }))),
    settings.language, v => {
      settings.language = v;
      applySettings();
      applyChrome();
      renderAll();
    });
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
el('s-clear').onclick = () => { settings.known.clear(); persistKnown(); applySettings(); renderCard(); };
