// Test tab: start screen + history, TTS-driven running view, result stamp.
import { el, setText, show, setSpokenText } from './dom.js';
import { t, catLabel, translationFor, displayPair, spokenLanguage, translationPrimary, CHROME_LOCALE, chromeLang } from '../i18n.js';
import { getHistory } from '../settings.js';
import { state, Phase, Mode, Outcome, TEST_TOTAL, startTest, primaryAction, grade, startStudy, activeHighlight } from '../engine.js';
import { selectTab } from '../main.js';

export function renderTest() {
  const start = el('test-start'), run = el('test-run'), result = el('test-result');
  if (state.mode === Mode.TEST && state.phase === Phase.FINISHED) {
    start.hidden = true; run.hidden = true; result.hidden = false;
    renderTestResult();
    return;
  }
  if (state.mode === Mode.TEST && state.phase !== Phase.IDLE) {
    start.hidden = true; result.hidden = true; run.hidden = false;
    renderTestRun();
    return;
  }
  run.hidden = true; result.hidden = true; start.hidden = false;
  renderHistory();
}
function renderHistory() {
  const box = el('test-history');
  box.innerHTML = '';
  const hist = getHistory();
  if (!hist.length) return;
  const title = document.createElement('p');
  title.className = 'h-title';
  title.textContent = t('test_history');
  box.appendChild(title);
  hist.slice(0, 5).forEach(r => {
    const row = document.createElement('div');
    row.className = 'h-row';
    const score = document.createElement('span');
    score.className = r.p ? 'h-pass' : 'h-fail';
    score.textContent = (r.p ? '✓ ' : '✗ ') + r.c + ' / ' + (r.c + r.w);
    const date = document.createElement('span');
    date.className = 'h-date';
    date.textContent = new Date(r.ts).toLocaleDateString(CHROME_LOCALE[chromeLang()]);
    row.appendChild(score);
    row.appendChild(date);
    box.appendChild(row);
  });
}
function renderTestRun() {
  setText('t-progress', t('question_of', state.testIndex + 1, TEST_TOTAL));
  setText('t-correct', state.testCorrect);
  setText('t-wrong', state.testWrong);
  el('t-bar').style.width = (state.testIndex / TEST_TOTAL * 100) + '%';
  const q = state.current;
  if (q) {
    setText('t-num', 'Q' + q.n);
    setText('t-cat', catLabel(q.category).toUpperCase());
    const tr = translationFor(q, spokenLanguage());
    renderSpokenPair('t-q', 't-q2', q.question, tr ? tr.question : null, 'question');
    show('t-answer', state.answerRevealed);
    if (state.answerRevealed) {
      renderSpokenPair('t-a', 't-a2', q.answer, tr ? tr.answer : null, 'answer');
      const note = translationPrimary() && tr ? (tr.note || q.note) : q.note;
      show('t-note', !!note);
      if (note) setText('t-note', note);
    }
  }
  const cap = {
    SPEAKING_QUESTION: t('phase_speaking_question'),
    THINKING: t('phase_thinking'),
    SPEAKING_ANSWER: t('phase_speaking_answer'),
    AWAITING_GRADE: t('phase_awaiting_grade'),
  }[state.phase] || '';
  setText('t-phase', cap);
  const grading = state.phase === Phase.AWAITING_GRADE;
  show('t-grade', grading);
  show('t-reveal', !grading);
}
function renderTestResult() {
  const passed = state.testOutcome === Outcome.PASSED;
  const stamp = el('r-stamp');
  stamp.textContent = passed ? t('test_passed') : t('test_failed');
  stamp.className = 'stamp ' + (passed ? 'pass' : 'fail');
  setText('r-score', state.testCorrect);
  setText('r-total', state.testCorrect + state.testWrong);
  setText('r-verdict', passed ? t('test_verdict_pass') : t('test_verdict_fail'));
}

/* Same pair logic as the Listen tab: the line matching the utterance's block
   and language carries the moving word highlight while TTS speaks. */
function renderSpokenPair(primaryId, secondaryId, english, translated, block) {
  const qp = displayPair(english, translated);
  const hl = activeHighlight(block);
  const onPrimary = !!hl && hl.translation === translationPrimary();
  setSpokenText(primaryId, qp.primary, onPrimary ? hl : null);
  show(secondaryId, qp.secondary != null);
  if (qp.secondary != null) setSpokenText(secondaryId, qp.secondary, onPrimary ? null : hl);
}

/* Per-word refresh for TTS boundary events (see renderListenHighlight). */
export function renderTestHighlight() {
  const q = state.current;
  if (!q || state.mode !== Mode.TEST) return;
  const tr = translationFor(q, spokenLanguage());
  renderSpokenPair('t-q', 't-q2', q.question, tr ? tr.question : null, 'question');
  if (state.answerRevealed) renderSpokenPair('t-a', 't-a2', q.answer, tr ? tr.answer : null, 'answer');
}

el('start-test').onclick = () => startTest();
el('t-reveal').onclick = () => primaryAction(); // same routing as the mobile reveal button
el('t-got').onclick = () => grade(true);
el('t-miss').onclick = () => grade(false);
el('t-stop').onclick = () => startStudy(); // abort: back to the start screen, no history recorded
el('r-again').onclick = () => startTest();
el('r-back').onclick = () => { startStudy(); selectTab('listen'); };
