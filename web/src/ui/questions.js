// Questions tab: view-local known filter, scrollable 128-row list, tap-to-jump.
import { el, makeChips } from './dom.js';
import { t, catLabel, translationFor, displayPair, spokenLanguage } from '../i18n.js';
import { settings, stats } from '../settings.js';
import { personalizedQuestions, state, jumpTo, toggleKnown } from '../engine.js';
import { selectTab } from '../main.js';

let qFilter = 'all'; // view-local, reset to All on each visit
let qSearch = '';    // view-local, cleared on each visit

el('q-search').addEventListener('input', e => {
  qSearch = e.target.value.trim().toLowerCase();
  renderQuestions();
});

export function enterQuestionsTab() {
  qFilter = 'all';
  qSearch = '';
  el('q-search').value = '';
  renderQuestions();
}

/* Live search: bare/Q-prefixed digits match the question number exactly;
   anything else is a substring match over the English question, every
   translation, and the category label (English + localized). */
function matchesQuery(q, query) {
  if (!query) return true;
  const num = /^q?(\d+)$/.exec(query);
  if (num) return q.n === Number(num[1]);
  if (q.question.toLowerCase().indexOf(query) !== -1) return true;
  if (q.category.toLowerCase().indexOf(query) !== -1) return true;
  if (catLabel(q.category).toLowerCase().indexOf(query) !== -1) return true;
  if (q.translations) {
    for (const lang in q.translations) {
      const tr = q.translations[lang];
      if (tr && tr.question && tr.question.toLowerCase().indexOf(query) !== -1) return true;
    }
  }
  return false;
}

function renderQuestionFilters() {
  makeChips('q-filters', [
    { value: 'all', label: t('filter_all') },
    { value: 'known', label: t('filter_known') },
    { value: 'notKnown', label: t('filter_not_known') },
  ], qFilter, v => { qFilter = v; renderQuestions(); });
}
export function renderQuestions() {
  renderQuestionFilters();
  const search = el('q-search');
  search.placeholder = t('search_questions');
  search.setAttribute('aria-label', t('search_questions'));
  const list = el('q-list');
  list.innerHTML = '';
  const lang = spokenLanguage();
  const shown = personalizedQuestions().filter(q =>
    (qFilter === 'all' || (qFilter === 'known') === settings.known.has(q.n)) &&
    matchesQuery(q, qSearch));
  shown.forEach(q => {
    const row = document.createElement('div');
    row.className = 'q-row';
    row.dataset.n = q.n;
    row.dataset.cat = q.category;

    const main = document.createElement('button');
    main.className = 'q-main';
    main.setAttribute('aria-label', 'Q' + q.n);
    const over = document.createElement('span');
    over.className = 'q-over';
    const head = document.createElement('span');
    head.className = 'q-head';
    const tr = translationFor(q, lang);
    const qp = displayPair(q.question, tr ? tr.question : null);
    head.textContent = qp.primary;
    over.textContent = 'Q' + q.n + ' · ' + catLabel(q.category);
    main.appendChild(over);
    main.appendChild(head);
    if (qp.secondary != null) {
      const h2 = document.createElement('span');
      h2.className = 'q-head2';
      h2.textContent = qp.secondary;
      main.appendChild(h2);
    }
    main.onclick = () => { jumpTo(q.n); selectTab('listen'); };

    // How many times this question was missed in tests, when any. Own node so
    // updateQuestionsPlaying's over.textContent rewrite can't clobber it.
    const st = stats[q.n];
    if (st && st.w > 0) {
      const miss = document.createElement('span');
      miss.className = 'q-miss';
      miss.textContent = '×' + st.w;
      miss.setAttribute('role', 'img');
      miss.setAttribute('aria-label', t('questions_missed_times', st.w));
      row.appendChild(miss);
    }

    const check = document.createElement('button');
    check.className = 'q-check';
    const paint = () => {
      const on = settings.known.has(q.n);
      check.classList.toggle('on', on);
      check.textContent = on ? '✓' : '○';
      check.setAttribute('aria-label', on ? t('questions_unmark') : t('questions_mark'));
      check.setAttribute('aria-pressed', String(on));
    };
    paint();
    check.onclick = () => { toggleKnown(q.n); paint(); };

    row.appendChild(main);
    row.appendChild(check);
    list.appendChild(row);
  });
  updateQuestionsPlaying();
}
export function updateQuestionsPlaying() {
  const cur = state.current;
  const rows = el('q-list').children;
  for (let i = 0; i < rows.length; i++) {
    const over = rows[i].firstChild.firstChild;
    const n = Number(rows[i].dataset.n);
    const isCur = !!cur && cur.n === n;
    over.classList.toggle('playing-now', isCur);
    const base = 'Q' + n + ' · ' + catLabel(rows[i].dataset.cat || '');
    over.textContent = base + (isCur ? t('playing_suffix') : '');
  }
}
