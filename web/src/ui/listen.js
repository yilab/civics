// Listen tab: warning card, progress, question card, phase caption, transport row.
import { el, setText, show, makeChips, setSpokenText } from './dom.js';
import { t, catLabel, translationFor, displayPair, spokenLanguage, translationPrimary } from '../i18n.js';
import { settings } from '../settings.js';
import { state, Phase, Mode, deckSize, primaryAction, pause, next, previous, toggleKnown, applySettings, activeHighlight } from '../engine.js';
import { ttsAvailable } from '../speech.js';

export function updateTtsWarning() {
  const w = el('tts-warning');
  if (!w) return;
  w.textContent = t('no_tts');
  w.hidden = ttsAvailable();
}

export function renderListen() {
  const size = deckSize();
  setText('l-counter', size > 0 ? t('question_of', state.position + 1, size) : t('no_questions'));
  setText('l-known', t('known_count', settings.known.size));
  el('l-bar').style.width = (size === 0 ? 0 : (state.position + 1) / size * 100) + '%';

  const q = state.current;
  show('l-idle', !q);
  show('l-active', !!q);
  if (q) {
    setText('l-num', 'Q' + q.n);
    setText('l-cat', catLabel(q.category).toUpperCase());
    const tr = translationFor(q, spokenLanguage());
    renderSpokenPair('l-q', 'l-q2', q.question, tr ? tr.question : null, 'question');
    show('l-answer', state.answerRevealed);
    if (state.answerRevealed) {
      renderSpokenPair('l-a', 'l-a2', q.answer, tr ? tr.answer : null, 'answer');
      const note = translationPrimary() && tr ? (tr.note || q.note) : q.note;
      show('l-note', !!note);
      if (note) setText('l-note', note);
    }
  }

  const cap = {
    IDLE: '',
    SPEAKING_QUESTION: t('phase_speaking_question'),
    THINKING: t('phase_thinking'),
    SPEAKING_ANSWER: t('phase_speaking_answer'),
    AWAITING_ADVANCE: t('phase_awaiting_advance'),
    AWAITING_GRADE: t('phase_awaiting_grade'),
    FINISHED: '',
  }[state.phase];
  setText('l-phase', cap);

  const label = {
    IDLE: t('button_start'),
    SPEAKING_QUESTION: t('button_hear_answer'),
    THINKING: t('button_hear_answer'),
    SPEAKING_ANSWER: t('button_next_question'),
    AWAITING_ADVANCE: t('button_next_question'),
    AWAITING_GRADE: t('button_got_it'),
    FINISHED: t('button_start'),
  }[state.phase];
  setText('l-primary', label);

  const noNav = state.mode === Mode.TEST || !size;
  el('l-prev').disabled = noNav;
  el('l-next').disabled = noNav;
  const star = el('l-star');
  const isKnown = !!q && settings.known.has(q.n);
  star.disabled = !q;
  star.classList.toggle('on', isKnown);
  star.setAttribute('aria-pressed', String(isKnown));
  setText('l-star-ic', isKnown ? '★' : '☆');
  setText('l-star-label', isKnown ? t('known_label') : t('mark_known'));

  renderListenFilters();
}

/* Renders one primary/secondary line pair; while TTS speaks, the line matching
   the utterance's block and language carries the moving word highlight. */
function renderSpokenPair(primaryId, secondaryId, english, translated, block) {
  const qp = displayPair(english, translated);
  const hl = activeHighlight(block);
  const onPrimary = !!hl && hl.translation === translationPrimary();
  setSpokenText(primaryId, qp.primary, onPrimary ? hl : null);
  show(secondaryId, qp.secondary != null);
  if (qp.secondary != null) setSpokenText(secondaryId, qp.secondary, onPrimary ? null : hl);
}

/* Per-word refresh for TTS boundary events: only the four text lines, never
   the chips/buttons/captions the full render also touches. */
export function renderListenHighlight() {
  const q = state.current;
  if (!q) return;
  const tr = translationFor(q, spokenLanguage());
  renderSpokenPair('l-q', 'l-q2', q.question, tr ? tr.question : null, 'question');
  if (state.answerRevealed) renderSpokenPair('l-a', 'l-a2', q.answer, tr ? tr.answer : null, 'answer');
}

function renderListenFilters() {
  makeChips('l-filters', [
    { value: 'all', label: t('filter_all') },
    { value: 'known', label: t('filter_known') },
    { value: 'notKnown', label: t('filter_not_known') },
  ], settings.knownFilter, v => { settings.knownFilter = v; applySettings(); });
}

el('l-primary').onclick = () => primaryAction();
el('l-prev').onclick = () => previous();
el('l-stop').onclick = () => pause();
el('l-next').onclick = () => next();
el('l-star').onclick = () => { if (state.current) toggleKnown(state.current.n); };
