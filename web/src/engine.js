// Study engine (port of StudyEngine.kt): speak question -> think pause -> speak
// answer -> next. Renders exclusively from BANK (web/data/bank.generated.js,
// produced by android/tools/extract-questions.mjs); Q/QZ in
// web/data/questions-source.js are the human-edited source of truth and are not
// imported by the app.
import { BANK } from '../data/bank.generated.js';
import { settings, persistSettings, persistKnown, recordTest } from './settings.js';
import { spokenLanguage, bilingual, translationFor, Q_PREFIX, TTS_LOCALE } from './i18n.js';
import { speech } from './speech.js';

if (!BANK || !Array.isArray(BANK.questions) || BANK.questions.length !== 128) {
  throw new Error('Question bank missing — run: node android/tools/extract-questions.mjs');
}
export const QUESTIONS = BANK.questions;
export const TOTAL = QUESTIONS.length;

export const Phase = {
  IDLE: 'IDLE', SPEAKING_QUESTION: 'SPEAKING_QUESTION', THINKING: 'THINKING',
  SPEAKING_ANSWER: 'SPEAKING_ANSWER', AWAITING_ADVANCE: 'AWAITING_ADVANCE',
  AWAITING_GRADE: 'AWAITING_GRADE', FINISHED: 'FINISHED',
};
export const Mode = { STUDY: 'STUDY', TEST: 'TEST' };
export const Outcome = { NONE: 'NONE', PASSED: 'PASSED', FAILED: 'FAILED' };
export const TEST_TOTAL = 20, TEST_PASS_AT = 12, TEST_FAIL_AT = 9, AUTO_ADVANCE_MS = 2000;

export const state = {
  phase: Phase.IDLE, position: 0, current: null, answerRevealed: false,
  mode: Mode.STUDY, testIndex: 0, testCorrect: 0, testWrong: 0, testOutcome: Outcome.NONE,
  highlight: null, // {id, block, translation, text, start, end} — set by speak(), ranged by boundary events
};
let deck = [];
let timer = null;
let expectedUtterance = null;

/* The engine never touches the DOM; main.js registers the UI refresh callback. */
let updateFn = () => {};
export function onEngineUpdate(fn) { updateFn = fn; }
function update() { updateFn(); }
/* Per-word path for boundary events — skips the chip/button rebuilds of update(). */
let highlightFn = () => {};
export function onHighlightUpdate(fn) { highlightFn = fn; }

export function deckSize() { return deck.length; }
export function initDeck() {
  deck = repoDeck(settings.category, settings.shuffle, settings.knownFilter, settings.known);
}

export function shuffleArr(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = a[i]; a[i] = a[j]; a[j] = tmp;
  }
  return a;
}
export function repoDeck(category, shuffle, knownFilter, known) {
  let list = category === 'All' ? QUESTIONS.slice() : QUESTIONS.filter(q => q.category === category);
  if (knownFilter === 'known') list = list.filter(q => known.has(q.n));
  else if (knownFilter === 'notKnown') list = list.filter(q => !known.has(q.n));
  return shuffle ? shuffleArr(list) : list;
}
function sameNumbers(a, b) {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i].n !== b[i].n) return false;
  return true;
}
function cancelTimer() { if (timer !== null) { clearTimeout(timer); timer = null; } }

function speak(id, text, lang) {
  expectedUtterance = id;
  state.highlight = {
    id: id,
    block: id.indexOf('q-') === 0 || id.indexOf('zq-') === 0 ? 'question' : 'answer',
    translation: id.charAt(0) === 'z',
    text: text, start: null, end: null,
  };
  speech.speak({ id: id, text: text, lang: TTS_LOCALE[lang], rate: settings.speechRate });
}

export function primaryAction() {
  switch (state.phase) {
    case Phase.IDLE: startDeck(); break;
    case Phase.SPEAKING_QUESTION:
    case Phase.THINKING: revealAnswer(); break;
    case Phase.SPEAKING_ANSWER:
    case Phase.AWAITING_ADVANCE: next(); break;
    case Phase.AWAITING_GRADE: grade(true); break;
    case Phase.FINISHED: break;
  }
}
export function pause() {
  cancelTimer();
  expectedUtterance = null;
  state.highlight = null;
  speech.stop();
  if (state.phase !== Phase.IDLE) { state.phase = Phase.IDLE; update(); }
}
export function startTest() {
  cancelTimer();
  expectedUtterance = null;
  state.highlight = null;
  speech.stop();
  deck = shuffleArr(QUESTIONS.slice()).slice(0, TEST_TOTAL);
  state.position = 0;
  state.mode = Mode.TEST;
  state.testIndex = 0;
  state.testCorrect = 0;
  state.testWrong = 0;
  state.testOutcome = Outcome.NONE;
  speakQuestionAt(0);
}
export function grade(correct) {
  if (state.phase !== Phase.AWAITING_GRADE) return;
  const q = state.current;
  if (!q) return;
  const correctNow = state.testCorrect + (correct ? 1 : 0);
  const wrongNow = state.testWrong + (correct ? 0 : 1);
  // Mistakes resurface in study mode: a wrong answer unmarks a known question.
  if (!correct && settings.known.has(q.n)) setKnown(q.n, false);
  if (correctNow >= TEST_PASS_AT) finishTest(true, correctNow, wrongNow);
  else if (wrongNow >= TEST_FAIL_AT) finishTest(false, correctNow, wrongNow);
  else if (state.testIndex + 1 >= deck.length) finishTest(correctNow >= TEST_PASS_AT, correctNow, wrongNow);
  else {
    state.testIndex++;
    state.testCorrect = correctNow;
    state.testWrong = wrongNow;
    speakQuestionAt(state.testIndex);
  }
}
export function startStudy() {
  cancelTimer();
  expectedUtterance = null;
  state.highlight = null;
  speech.stop();
  deck = repoDeck(settings.category, settings.shuffle, settings.knownFilter, settings.known);
  state.phase = Phase.IDLE;
  state.position = 0;
  state.mode = Mode.STUDY;
  state.testOutcome = Outcome.NONE;
  update();
}
function finishTest(passed, correct, wrong) {
  cancelTimer();
  state.phase = Phase.FINISHED;
  state.answerRevealed = true;
  state.testCorrect = correct;
  state.testWrong = wrong;
  state.testOutcome = passed ? Outcome.PASSED : Outcome.FAILED;
  state.highlight = null;
  speech.stop();
  recordTest({ c: correct, w: wrong, p: passed ? 1 : 0, ts: Date.now() });
  update();
}
export function next() {
  if (state.mode === Mode.TEST) return; // no skipping during a test
  if (!deck.length) return;
  speakQuestionAt((state.position + 1) % deck.length);
}
/* Music-player style: while hearing the answer, repeat this question; otherwise go back one. */
export function previous() {
  if (state.mode === Mode.TEST) return; // no skipping during a test
  if (!deck.length) return;
  if (state.phase === Phase.SPEAKING_ANSWER || state.phase === Phase.AWAITING_ADVANCE) {
    speakQuestionAt(state.position);
  } else {
    speakQuestionAt((state.position - 1 + deck.length) % deck.length);
  }
}
export function jumpTo(questionNumber) {
  let idx = deck.findIndex(q => q.n === questionNumber);
  if (idx < 0) {
    deck = repoDeck('All', false, 'all', settings.known);
    idx = deck.findIndex(q => q.n === questionNumber);
  }
  if (idx >= 0) speakQuestionAt(idx);
}
export function toggleKnown(n) { setKnown(n, !settings.known.has(n)); }
export function setKnown(n, on) {
  if (on) settings.known.add(n); else settings.known.delete(n);
  persistKnown();
  applySettings();
}

function startDeck() {
  if (!deck.length) return;
  speakQuestionAt(Math.min(Math.max(state.position, 0), deck.length - 1));
}
function speakQuestionAt(position) {
  cancelTimer();
  const q = deck[position];
  if (!q) return;
  const lang = spokenLanguage();
  const tr = translationFor(q, lang);
  if (!bilingual() && lang !== 'english' && tr) {
    speak('zq-' + q.n, translationQuestionText(q, lang), lang);
  } else {
    speak('q-' + q.n, (settings.announceMeta ? Q_PREFIX.english(q.n) + ' ' : '') + q.question, 'english');
  }
  state.phase = Phase.SPEAKING_QUESTION;
  state.position = position;
  state.current = q;
  state.answerRevealed = false;
  update();
}
function revealAnswer() {
  cancelTimer();
  const q = state.current;
  if (!q) return;
  const lang = spokenLanguage();
  const tr = translationFor(q, lang);
  if (!bilingual() && lang !== 'english' && tr) {
    speak('za-' + q.n, tr.spoken, lang);
  } else {
    speak('a-' + q.n, q.spoken, 'english');
  }
  state.phase = Phase.SPEAKING_ANSWER;
  state.answerRevealed = true;
  update();
}
function afterAnswerSpoken() {
  if (state.mode === Mode.TEST) {
    state.phase = Phase.AWAITING_GRADE;
    update();
  } else {
    beginAwaitingAdvance();
  }
}
export function onUtteranceDone(utteranceId) {
  if (utteranceId !== expectedUtterance) return;
  state.highlight = null; // a fresh one is set if a follow-up utterance chains
  const lang = spokenLanguage();
  if (utteranceId.indexOf('zq-') === 0) { beginThinkPause(); return; }
  if (utteranceId.indexOf('za-') === 0) { afterAnswerSpoken(); return; }
  if (utteranceId.indexOf('q-') === 0) {
    const q = state.current;
    const tr = q ? translationFor(q, lang) : null;
    if (bilingual() && tr) speak('zq-' + q.n, translationQuestionText(q, lang), lang);
    else beginThinkPause();
    return;
  }
  if (utteranceId.indexOf('a-') === 0) {
    const q = state.current;
    const tr = q ? translationFor(q, lang) : null;
    if (bilingual() && q && tr) speak('za-' + q.n, tr.spoken, lang);
    else afterAnswerSpoken();
  }
}
export function onUtteranceBoundary(id, start, end) {
  const h = state.highlight;
  if (!h || h.id !== id || id !== expectedUtterance) return;
  h.start = start;
  h.end = end;
  highlightFn();
}
/* The highlight to render on a block's line, or null unless speech is in flight. */
export function activeHighlight(block) {
  const h = state.highlight;
  if (!h || h.block !== block || h.start == null || h.end == null) return null;
  if (state.phase !== Phase.SPEAKING_QUESTION && state.phase !== Phase.SPEAKING_ANSWER) return null;
  return h;
}
function translationQuestionText(q, language) {
  const tr = translationFor(q, language);
  if (!tr) return q.question;
  return (settings.announceMeta ? Q_PREFIX[language](q.n) + ' ' : '') + tr.question;
}
function beginThinkPause() {
  const think = settings.thinkSeconds;
  if (think === 0) { revealAnswer(); return; }
  state.phase = Phase.THINKING;
  update();
  if (think > 0) {
    timer = setTimeout(() => { timer = null; revealAnswer(); }, think * 1000);
  } // think < 0: wait for a press
}
function beginAwaitingAdvance() {
  state.phase = Phase.AWAITING_ADVANCE;
  update();
  if (settings.autoAdvance) {
    timer = setTimeout(() => { timer = null; next(); }, AUTO_ADVANCE_MS);
  }
}

/* Rebuild the study deck when settings change; keep position by question number. */
export function applySettings() {
  persistSettings();
  if (state.mode !== Mode.TEST) {
    const newDeck = repoDeck(settings.category, settings.shuffle, settings.knownFilter, settings.known);
    if (!sameNumbers(deck, newDeck)) {
      deck = newDeck;
      const cur = state.current;
      const idx = cur ? deck.findIndex(q => q.n === cur.n) : -1;
      state.position = idx >= 0 ? idx : 0;
    }
  }
  update();
}
