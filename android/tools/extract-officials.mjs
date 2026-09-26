// Builds the officials dataset for state-specific civics answers (Q23/29/61/62)
// by merging the hand-maintained web/data/officials-source.json (places, governors,
// sentence templates) with web/data/officials-congress.json (distilled from the
// CC0 unitedstates/congress-legislators roster by fetch-officials.mjs).
// Writes three targets, next to the generated question bank:
//   1. android/app/src/main/assets/officials.json (pretty-printed)
//   2. apple/Civics/Civics/Resources/officials.json (pretty-printed)
//   3. web/data/officials.generated.js (minified ESM module for the web build)
// Usage: node tools/extract-officials.mjs   (npm run sync in web/ runs both extractors)
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const LANGS = ['english', 'zh-Hans', 'zh-Hant', 'es', 'vi', 'tl', 'ko', 'ar', 'hi', 'pt', 'ru'];
const TEMPLATE_KEYS = ['chooseState', 'chooseDistrict', 'senators', 'senatorsNone', 'vacant', 'governorNoneDc', 'capitalNoneDc', 'outOfDate', 'noteVerify'];

const source = JSON.parse(readFileSync(new URL('../../web/data/officials-source.json', import.meta.url), 'utf8'));
const congress = JSON.parse(readFileSync(new URL('../../web/data/officials-congress.json', import.meta.url), 'utf8'));

const fail = (msg) => { console.error('officials-source:', msg); process.exit(1); };

// ---- places -----------------------------------------------------------------
const { places } = source;
if (!Array.isArray(places) || places.length !== 56) fail(`expected 56 places, got ${places?.length}`);
const codes = new Set();
for (const p of places) {
  if (!/^[A-Z]{2}$/.test(p.code)) fail(`bad place code ${p.code}`);
  if (codes.has(p.code)) fail(`duplicate place code ${p.code}`);
  codes.add(p.code);
  if (!['state', 'dc', 'territory'].includes(p.kind)) fail(`${p.code}: bad kind ${p.kind}`);
  if (!Number.isInteger(p.seats) || p.seats < 1) fail(`${p.code}: bad seats ${p.seats}`);
  if (p.kind === 'dc' ? p.capital !== null : !p.capital) fail(`${p.code}: bad capital`);
  for (const lang of LANGS) if (!p.name[lang]) fail(`${p.code}: missing ${lang} name`);
  const actual = congress.seats[p.code];
  if (actual !== p.seats) fail(`${p.code}: source seats ${p.seats} != congress seats ${actual} (redistricting? update the source)`);
}

// ---- governors ---------------------------------------------------------------
for (const p of places) {
  const entries = source.governors[p.code];
  if (p.kind === 'dc') {
    if (entries) fail('DC must not have a governor entry');
    continue;
  }
  if (!Array.isArray(entries) || entries.length === 0) fail(`${p.code}: missing governor`);
  for (const g of entries) if (!g.name || !/^\d{4}-\d{2}-\d{2}$/.test(g.from)) fail(`${p.code}: bad governor entry ${JSON.stringify(g)}`);
}

// ---- congress coverage ---------------------------------------------------------
const stateCodes = places.filter((p) => p.kind === 'state').map((p) => p.code);
for (const code of stateCodes) {
  const sens = congress.senators[code];
  if (!Array.isArray(sens) || sens.length !== 2) fail(`${code}: expected 2 senators, got ${sens?.length}`);
}
for (const p of places.filter((p) => p.kind !== 'state')) {
  if (congress.senators[p.code]) fail(`${p.code}: territories and D.C. must have no senators in the roster`);
}
for (const p of places) {
  const districts = congress.representatives[p.code];
  if (!districts) fail(`${p.code}: missing representatives`);
  const got = Object.keys(districts).map(Number).sort((a, b) => a - b);
  const want = p.seats === 1 ? [0] : Array.from({ length: p.seats }, (_, i) => i + 1);
  const vacant = want.filter((d) => !got.includes(d));
  if (vacant.length) {
    // A seat with no current member is normal (resignation, death) — the apps say
    // "this seat is vacant". Only fail when the roster disagrees about the map itself.
    if (got.length !== want.length - vacant.length) fail(`${p.code}: unexpected districts ${got}`);
    console.warn(`note: ${p.code} district(s) currently vacant: ${vacant.join(', ')}`);
  }
}

// ---- templates -----------------------------------------------------------------
const NEED = { senators: ['{a}', '{b}'], senatorsNone: ['{place}'], outOfDate: ['{text}'], noteVerify: ['{place}'] };
for (const lang of LANGS) {
  const tpl = source.templates[lang];
  if (!tpl) fail(`missing templates for ${lang}`);
  for (const key of TEMPLATE_KEYS) {
    if (!tpl[key]) fail(`${lang}: missing template ${key}`);
    if (/[()（）]/.test(tpl[key]) || / {2}/.test(tpl[key])) fail(`${lang}.${key}: parens or double spaces break the TTS audit`);
    for (const ph of NEED[key] ?? []) if (!tpl[key].includes(ph)) fail(`${lang}.${key}: missing placeholder ${ph}`);
  }
}

// ---- merge ---------------------------------------------------------------------
// Hand-added "incoming" entries (election winners not yet seated) ride alongside
// the roster with their real start dates; the apps pick by date. Each seat/district
// keeps its own timeline of entries, sorted by start date.
const senators = {};
for (const code of stateCodes) {
  const extra = source.incoming?.senators?.[code] ?? [];
  for (const e of extra) if (!e.seat) fail(`${code}: incoming senator missing "seat"`);
  senators[code] = [
    ...congress.senators[code].map(({ name, from, until, class: cls }) => ({ name, from, until, seat: cls })),
    ...extra,
  ].sort((a, b) => a.seat - b.seat || a.from.localeCompare(b.from));
}
const representatives = {};
for (const p of places) {
  representatives[p.code] = {};
  for (const [district, entry] of Object.entries(congress.representatives[p.code])) {
    representatives[p.code][district] = [entry];
  }
  for (const [district, entries] of Object.entries(source.incoming?.representatives?.[p.code] ?? {})) {
    representatives[p.code][district] = [...(representatives[p.code][district] ?? []), ...entries]
      .sort((a, b) => a.from.localeCompare(b.from));
  }
}
const governors = { ...source.governors };
for (const [code, entries] of Object.entries(source.incoming?.governors ?? {})) {
  governors[code] = [...(governors[code] ?? []), ...entries].sort((a, b) => a.from.localeCompare(b.from));
}

const out = {
  version: `congress ${congress.fetched}`,
  places,
  governors,
  senators,
  representatives,
  templates: source.templates,
};

const json = JSON.stringify(out, null, 1) + '\n';
const targets = [
  new URL('../app/src/main/assets/officials.json', import.meta.url),
  new URL('../../apple/Civics/Civics/Resources/officials.json', import.meta.url),
];
for (const target of targets) {
  mkdirSync(new URL('.', target), { recursive: true });
  writeFileSync(target, json);
}
console.log(`wrote officials for ${places.length} places to ${targets.length} targets`);

const jsUrl = new URL('../../web/data/officials.generated.js', import.meta.url);
writeFileSync(
  jsUrl,
  '// GENERATED by android/tools/extract-officials.mjs — do not edit by hand.\n' +
    '// Source: web/data/officials-source.json + officials-congress.json. After regenerating,\n' +
    '// rebuild the web artifact with `npm run build` in web/ (or `npm run sync`).\n' +
    `export const OFFICIALS = ${JSON.stringify(out).replace(/</g, '\\u003c')};\n`,
);
console.log('wrote minified officials module to web/data/officials.generated.js');
