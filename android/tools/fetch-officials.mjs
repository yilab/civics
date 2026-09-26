// Downloads the public-domain (CC0) unitedstates/congress-legislators roster and
// distills it to web/data/officials-congress.json: current senators and
// representatives per state, with term start/end dates. Checked in and consumed
// by extract-officials.mjs, which merges it with the hand-maintained
// officials-source.json (places, governors, templates). Re-run after elections
// or when seats change; review the diff like any other data change.
// Usage: node tools/fetch-officials.mjs
import { writeFileSync } from 'node:fs';

const ROSTER_URL = 'https://unitedstates.github.io/congress-legislators/legislators-current.json';

const res = await fetch(ROSTER_URL);
if (!res.ok) throw new Error(`fetch failed: ${res.status} ${res.statusText}`);
const roster = await res.json();

// "Eric A. \"Rick\" Crawford" -> "Eric A. Crawford"; "Sanford D. Bishop, Jr." -> "Sanford D. Bishop"
function cleanName(m) {
  const full = m.name.official_full ?? `${m.name.first} ${m.name.last}`;
  return full
    .replace(/\s*"[^"]*"/g, '')
    .replace(/,\s*(Jr\.|Sr\.|II|III|IV|V)$/i, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const senators = {}; // state -> [{name, from, until, class}]
const representatives = {}; // state -> {district: {name, from, until}}
const seats = {}; // state -> highest district number

for (const m of roster) {
  const t = m.terms[m.terms.length - 1];
  const name = cleanName(m);
  if (t.type === 'sen') {
    (senators[t.state] ??= []).push({ name, from: t.start, until: t.end, class: t.class });
  } else if (t.type === 'rep') {
    (representatives[t.state] ??= {})[t.district] = { name, from: t.start, until: t.end };
    // At-large states and D.C./territory delegates use district 0 — still one seat.
    seats[t.state] = Math.max(seats[t.state] ?? 0, t.district, 1);
  }
}
for (const list of Object.values(senators)) list.sort((a, b) => a.class - b.class);

const states = [...new Set([...Object.keys(senators), ...Object.keys(representatives)])].sort();
const out = {
  source: ROSTER_URL,
  fetched: new Date().toISOString().slice(0, 10),
  senators: Object.fromEntries(states.filter((s) => senators[s]).map((s) => [s, senators[s]])),
  representatives: Object.fromEntries(
    states.filter((s) => representatives[s]).map((s) => [
      s,
      Object.fromEntries(Object.entries(representatives[s]).sort((a, b) => Number(a[0]) - Number(b[0]))),
    ]),
  ),
  seats: Object.fromEntries(states.filter((s) => seats[s]).map((s) => [s, seats[s]])),
};

const target = new URL('../../web/data/officials-congress.json', import.meta.url);
writeFileSync(target, JSON.stringify(out, null, 1) + '\n');
const senCount = Object.values(senators).reduce((n, l) => n + l.length, 0);
const repCount = Object.values(representatives).reduce((n, d) => n + Object.keys(d).length, 0);
console.log(`wrote ${senCount} senators, ${repCount} representatives (${states.length} jurisdictions) to web/data/officials-congress.json`);
