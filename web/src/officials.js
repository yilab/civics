// State-specific answers for the four "depends on your state" questions
// (Q23 senators, Q29 representative, Q61 governor, Q62 capital): fills answer,
// spoken text, and note with the officials serving the user's chosen place on
// today's date. Pure data transformation, kept in parity with Officials.kt and
// Officials.swift. Officials' names stay in English in every language (the
// interview is in English); only the surrounding sentence comes from the
// translated templates.
import { OFFICIALS } from '../data/officials.generated.js';

export const PLACES = OFFICIALS.places;
export const PLACE_BY_CODE = {};
for (const p of PLACES) PLACE_BY_CODE[p.code] = p;
export const STATE_QUESTIONS = new Set([23, 29, 61, 62]);

export function todayLocal() {
  const d = new Date();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return d.getFullYear() + '-' + mm + '-' + dd;
}

function fill(tpl, map) {
  return tpl.replace(/\{(\w+)\}/g, (m, k) => (map[k] != null ? map[k] : m));
}

/* Latest entry seated on or before `today`; stale when its `until` date has
   passed and no successor entry exists yet (data awaiting an election refresh). */
function pickName(timeline, today) {
  let cur = null;
  for (const e of timeline || []) if (e.from <= today) cur = e;
  if (!cur) return null;
  return { name: cur.name, stale: cur.until != null && today > cur.until };
}

function placeFor(code) {
  return code ? PLACE_BY_CODE[code] ?? null : null;
}

function districtFor(place, district) {
  if (!place) return null;
  return place.seats > 1 && !(district >= 1 && district <= place.seats) ? null : district;
}

/* The state questions that cannot be answered for these settings — excluded
   from the practice test, since the user cannot be graded on them. */
export function unresolvedStateQuestions(placeCode, district) {
  const place = placeFor(placeCode);
  if (!place) return new Set(STATE_QUESTIONS);
  if (place.seats > 1 && districtFor(place, district) == null) return new Set([29]);
  return new Set();
}

/* Texts for one state question in one language, or null when the bank text
   stays (Q29 in a multi-district state with no district chosen). */
function resolveTexts(n, place, district, today, lang) {
  const T = OFFICIALS.templates[lang];
  const placeName = place.name[lang];
  const verifyNote = fill(T.noteVerify, { place: placeName });
  const dated = (text, stale) => (stale ? fill(T.outOfDate, { text: text }) : text);
  switch (n) {
    case 23: {
      if (place.kind !== 'state') return { answer: fill(T.senatorsNone, { place: placeName }), note: null };
      const bySeat = {};
      for (const e of OFFICIALS.senators[place.code] || []) {
        (bySeat[e.seat] = bySeat[e.seat] || []).push(e);
      }
      const picks = Object.values(bySeat).map(tl => pickName(tl, today)).filter(Boolean);
      if (!picks.length) return { answer: T.vacant, note: verifyNote };
      const stale = picks.some(p => p.stale);
      const text = picks.length === 1
        ? picks[0].name + '.'
        : fill(T.senators, { a: picks[0].name, b: picks[1].name });
      return { answer: dated(text, stale), note: verifyNote };
    }
    case 29: {
      const districts = OFFICIALS.representatives[place.code] || {};
      const key = place.seats === 1 ? Object.keys(districts)[0] : String(district);
      const pick = pickName(districts[key], today);
      if (!pick) return { answer: T.vacant, note: verifyNote };
      return { answer: dated(pick.name + '.', pick.stale), note: verifyNote };
    }
    case 61: {
      if (place.kind === 'dc') return { answer: T.governorNoneDc, note: null };
      const pick = pickName(OFFICIALS.governors[place.code], today);
      if (!pick) return { answer: T.vacant, note: verifyNote };
      return { answer: dated(pick.name + '.', pick.stale), note: verifyNote };
    }
    case 62: {
      if (place.kind === 'dc') return { answer: T.capitalNoneDc, note: null };
      return { answer: place.capital + '.', note: null };
    }
  }
  return null;
}

/* Replaces only the spoken text (all languages) with a "set this up" prompt;
   the bank's display answer and note stay. */
function withSpokenPrompt(q, key) {
  const translations = {};
  for (const lang of Object.keys(q.translations)) {
    translations[lang] = { ...q.translations[lang], spoken: OFFICIALS.templates[lang][key] };
  }
  return { ...q, spoken: OFFICIALS.templates.english[key], translations: translations };
}

function personalizeQuestion(q, place, district, today) {
  if (!place) return withSpokenPrompt(q, 'chooseState');
  if (q.n === 29 && place.seats > 1 && districtFor(place, district) == null) {
    return withSpokenPrompt(q, 'chooseDistrict');
  }
  const en = resolveTexts(q.n, place, district, today, 'english');
  if (!en) return q;
  const translations = {};
  for (const lang of Object.keys(q.translations)) {
    const t = resolveTexts(q.n, place, district, today, lang);
    translations[lang] = t
      ? { ...q.translations[lang], answer: t.answer, spoken: t.answer, note: t.note }
      : q.translations[lang];
  }
  return { ...q, answer: en.answer, spoken: en.answer, note: en.note, translations: translations };
}

/* The 128 questions with the four state questions personalized for the chosen
   place/district/date. Untouched questions are passed through by reference. */
export function personalize(questions, placeCode, district, today) {
  const place = placeFor(placeCode);
  const dist = districtFor(place, district);
  const date = today || todayLocal();
  return questions.map(q => (STATE_QUESTIONS.has(q.n) ? personalizeQuestion(q, place, dist, date) : q));
}

/* Options for the district picker, with the current member's name per district. */
export function districtOptions(placeCode, today) {
  const place = placeFor(placeCode);
  if (!place || place.seats <= 1) return [];
  const date = today || todayLocal();
  const reps = OFFICIALS.representatives[place.code] || {};
  const out = [];
  for (let d = 1; d <= place.seats; d++) {
    const pick = pickName(reps[String(d)], date);
    out.push({ district: d, name: pick ? pick.name : null });
  }
  return out;
}
