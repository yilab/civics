// Flashcards tab (web-only bonus): category chips, flip card, one-shot shuffle,
// shared known set, arrow-key friendly prev/next.
import { el, setText, show, makeChips } from './dom.js';
import { t, catLabel, translationFor, displayPair, spokenLanguage, translationPrimary } from '../i18n.js';
import { settings, CATS } from '../settings.js';
import { QUESTIONS, TOTAL, shuffleArr, toggleKnown } from '../engine.js';

let fcFilter = 'All';
export let fcDeck = [];
let fcPos = 0;

export function fcBuild(shuffleIt) {
  fcDeck = fcFilter === 'All' ? QUESTIONS.slice() : QUESTIONS.filter(q => q.category === fcFilter);
  if (shuffleIt) shuffleArr(fcDeck);
  fcPos = 0;
}
export function renderCardChips() {
  makeChips('chips', CATS.map(c => ({ value: c, label: catLabel(c) })), fcFilter, v => {
    fcFilter = v; fcBuild(false); renderCard(); renderCardChips();
  });
}
export function renderCard() {
  if (!fcDeck.length) return;
  const item = fcDeck[fcPos];
  const card = el('card');
  card.classList.remove('flipped');
  setText('f-num', 'Q' + item.n);
  setText('b-num', 'Q' + item.n);
  setText('f-cat', catLabel(item.c));
  setText('back-cat', t('answer_label'));
  const tr = translationFor(item, spokenLanguage());
  const qp = displayPair(item.question, tr ? tr.question : null);
  setText('f-q', qp.primary);
  show('f-q2', qp.secondary != null);
  if (qp.secondary != null) setText('f-q2', qp.secondary);
  const ap = displayPair(item.answer, tr ? tr.answer : null);
  setText('b-a', ap.primary);
  show('b-a2', ap.secondary != null);
  if (ap.secondary != null) setText('b-a2', ap.secondary);
  const note = translationPrimary() && tr ? (tr.note || item.note) : item.note;
  show('b-note', !!note);
  setText('b-note', note || '');
  setText('card-counter', t('question_of', fcPos + 1, fcDeck.length));
  const isKnown = settings.known.has(item.n);
  const kb = el('known');
  kb.classList.toggle('on', isKnown);
  kb.setAttribute('aria-pressed', String(isKnown));
  setText('known-check', isKnown ? '✓' : '○');
  setText('known-label', isKnown ? t('known_label') : t('questions_mark'));
  el('prev').disabled = fcPos === 0;
  el('next').disabled = fcPos === fcDeck.length - 1;
  updateKnownMeter();
}
export function updateKnownMeter() {
  setText('known-count', t('known_count', settings.known.size));
  el('known-bar').style.width = (settings.known.size / TOTAL * 100) + '%';
}

el('card').addEventListener('click', () => el('card').classList.toggle('flipped'));
el('card').addEventListener('keydown', e => {
  if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); el('card').classList.toggle('flipped'); }
});
el('prev').onclick = () => { if (fcPos > 0) { fcPos--; renderCard(); } };
el('next').onclick = () => { if (fcPos < fcDeck.length - 1) { fcPos++; renderCard(); } };
el('shuffle').onclick = () => { fcBuild(true); renderCard(); };
el('known').onclick = () => {
  if (!fcDeck.length) return;
  const item = fcDeck[fcPos];
  toggleKnown(item.n);
  renderCard();
};
