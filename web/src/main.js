// Entry point: tab switching, static chrome text, master render wiring, global
// keyboard/lifecycle handlers, and init. esbuild bundles this (and the imported
// stylesheet) into the single-file artifact via web/build.mjs.
import './styles.css';

import { t, chromeLang, CHROME_LOCALE } from './i18n.js';
import { speech, updateMediaSession } from './speech.js';
import {
  onEngineUpdate, onUtteranceDone, onUtteranceBoundary, onHighlightUpdate, initDeck,
  primaryAction, pause,
} from './engine.js';
import { el, setText } from './ui/dom.js';
import { updateTtsWarning, renderListen, renderListenHighlight } from './ui/listen.js';
import { fcBuild, fcDeck, renderCardChips, renderCard, updateKnownMeter } from './ui/flashcards.js';
import { enterQuestionsTab, renderQuestions, updateQuestionsPlaying } from './ui/questions.js';
import { renderTest, renderTestHighlight } from './ui/test.js';
import { renderSettings } from './ui/settings.js';
import { renderStore } from './ui/store-badges.js';

/* ---------- tabs ---------- */
const TABS = ['listen', 'cards', 'questions', 'test', 'settings'];
let activeTab = 'listen';
export function selectTab(name) {
  activeTab = name;
  TABS.forEach(k => {
    el('tab-' + k).setAttribute('aria-selected', String(k === name));
    el('panel-' + k).classList.toggle('active', k === name);
  });
  if (name === 'questions') enterQuestionsTab();
}
TABS.forEach(k => { el('tab-' + k).onclick = () => selectTab(k); });

/* ---------- chrome (static UI text) ---------- */
export function applyChrome() {
  document.documentElement.lang = CHROME_LOCALE[chromeLang()];
  TABS.forEach(k => setText('tab-' + k, t('tab_' + k)));
  setText('header-sub', t('header_sub'));
  setText('ft-no-ads', t('feat_no_ads'));
  setText('ft-no-data', t('feat_no_data'));
  setText('ft-readalong', t('feat_readalong'));
  setText('ft-open-source', t('feat_open_source'));
  updateTtsWarning();
  setText('l-title', t('app_title'));
  setText('l-onboarding', t('onboarding'));
  setText('l-a-label', t('acceptable_answer'));
  el('l-prev').setAttribute('aria-label', t('previous_question'));
  el('l-stop').setAttribute('aria-label', t('stop'));
  el('l-next').setAttribute('aria-label', t('button_next_question'));
  setText('a-label', t('acceptable_answer_card'));
  setText('hint-front', t('flip_reveal'));
  setText('hint-back', t('flip_back'));
  el('card').setAttribute('aria-label', t('flashcard_aria'));
  setText('test-h2', t('test_title'));
  const rules = el('test-rules').children;
  const ruleTexts = t('test_rules');
  for (let i = 0; i < rules.length && i < ruleTexts.length; i++) rules[i].textContent = ruleTexts[i];
  setText('start-test', t('test_start'));
  setText('t-correct-label', t('correct_label'));
  setText('t-wrong-label', t('missed_label'));
  setText('t-a-label', t('acceptable_answer'));
  setText('t-reveal', t('button_hear_answer'));
  setText('t-miss', '✗ ' + t('button_missed_it'));
  setText('t-got', '✓ ' + t('button_got_it'));
  setText('t-stop', t('stop'));
  setText('r-again', t('test_again'));
  setText('r-back', t('test_back'));
  setText('s-lang-title', t('settings_language'));
  setText('s-lang-label', t('settings_ui_language'));
  setText('s-loc-title', t('settings_location'));
  setText('s-loc-label', t('settings_your_state'));
  setText('s-dist-label', t('settings_district'));
  setText('s-find-dist', t('settings_find_district'));
  setText('s-loc-hint', t('settings_location_hint'));
  setText('s-voice-title', t('settings_voice'));
  setText('s-announce-label', t('announce_meta'));
  setText('s-playback-title', t('settings_playback'));
  setText('s-think-label', t('think_pause'));
  setText('s-auto-label', t('auto_advance'));
  setText('s-deck-title', t('settings_deck'));
  setText('s-shuffle-label', t('shuffle'));
  setText('s-progress-title', t('settings_progress'));
  setText('s-clear', t('clear_known'));
  setText('s-review-focus-label', t('settings_review_focus'));
  setText('s-reset-stats', t('settings_reset_stats'));
}

/* ---------- master render ---------- */
function update() {
  renderListen();
  renderTest();
  updateQuestionsPlaying();
  updateKnownMeter();
  updateMediaSession();
}
/* Per-word path for TTS boundary events — skips chips, buttons, media session. */
function renderHighlight() {
  renderListenHighlight();
  renderTestHighlight();
}
export function renderAll() {
  applyChrome();
  renderStore();
  renderListen();
  fcBuild(false);
  renderCardChips();
  if (fcDeck.length) renderCard();
  renderQuestions();
  renderTest();
  renderSettings();
  updateMediaSession();
}

/* ---------- keyboard & lifecycle ---------- */
document.addEventListener('keydown', e => {
  const tag = (e.target && e.target.tagName || '').toLowerCase();
  const inControl = tag === 'button' || tag === 'input' || tag === 'select' || tag === 'textarea'
    || (e.target && e.target.isContentEditable);
  if (e.key === ' ' && activeTab === 'listen' && !inControl) {
    e.preventDefault();
    primaryAction();
    return;
  }
  if (activeTab === 'cards' && !inControl) {
    if (e.key === 'ArrowLeft') el('prev').click();
    else if (e.key === 'ArrowRight') el('next').click();
  }
});
window.addEventListener('pagehide', () => pause());
document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });

/* ---------- init ---------- */
speech.ondone = onUtteranceDone;
speech.onboundary = onUtteranceBoundary;
speech.onvoiceschanged = updateTtsWarning;
speech.init();
onEngineUpdate(update);
onHighlightUpdate(renderHighlight);
initDeck();
fcBuild(false);
renderAll();
