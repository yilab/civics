// State-specific answers (officials.js), mirroring OfficialsDataTest.kt over
// the same generated data.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { BANK } from '../data/bank.generated.js';
import { PLACES, STATE_QUESTIONS, personalize, unresolvedStateQuestions, districtOptions } from '../src/officials.js';

const TODAY = '2026-09-26';
const questions = BANK.questions;
const byN = (list, n) => list.find(q => q.n === n);

test('56 places in picker order', () => {
  assert.equal(PLACES.length, 56);
  assert.equal(PLACES[0].code, 'AL');
  assert.equal(PLACES[50].code, 'DC');
  assert.equal(PLACES.filter(p => p.kind === 'territory').length, 5);
});

test('no place keeps the bank text and prompts through the spoken text', () => {
  const p = personalize(questions, null, null, TODAY);
  const q23 = byN(p, 23);
  assert.equal(q23.answer, 'Depends on your state.');
  assert.match(q23.spoken, /Choose your state in Settings/);
  assert.match(q23.translations['zh-Hans'].spoken, /设置/);
  assert.equal(byN(p, 1), byN(questions, 1)); // untouched questions pass through
});

test('a state fills senators, governor and capital in every language', () => {
  const p = personalize(questions, 'CA', null, TODAY);
  const q23 = byN(p, 23);
  assert.match(q23.answer, /^Either one: /);
  assert.equal(q23.spoken, q23.answer);
  assert.equal(byN(p, 61).answer, 'Gavin Newsom.');
  assert.equal(byN(p, 62).answer, 'Sacramento.');
  assert.equal(byN(p, 62).note, null);
  // Names stay English in translations; the sentence around them is localized.
  assert.match(q23.translations['zh-Hans'].answer, /^两位中的任意一位/);
  assert.match(q23.translations['zh-Hans'].answer, /Alex Padilla/);
});

test('a multi-seat state without a district prompts for Q29 only', () => {
  const p = personalize(questions, 'CA', null, TODAY);
  assert.equal(byN(p, 29).answer, 'Depends on where you live.');
  assert.match(byN(p, 29).spoken, /congressional district/);
  assert.deepEqual([...unresolvedStateQuestions('CA', null)], [29]);
  assert.deepEqual([...unresolvedStateQuestions('CA', 5)], []);
  assert.deepEqual([...unresolvedStateQuestions(null, null)], [...STATE_QUESTIONS]);
  assert.deepEqual([...unresolvedStateQuestions('WY', null)], []);
});

test('a district resolves the representative; a vacant seat says so', () => {
  assert.equal(byN(personalize(questions, 'CA', 12, TODAY), 29).answer, 'Lateefah Simon.');
  const vacant = byN(personalize(questions, 'FL', 20, TODAY), 29).answer;
  assert.match(vacant, /vacant/);
  assert.match(vacant, /house\.gov/);
});

test('D.C. and the territories get their own wording', () => {
  const dc = personalize(questions, 'DC', null, TODAY);
  assert.equal(byN(dc, 23).answer, 'There are no U.S. senators for District of Columbia.');
  assert.equal(byN(dc, 61).answer, 'D.C. does not have a governor.');
  assert.equal(byN(dc, 62).answer, 'D.C. is not a state and does not have a capital.');
  const pr = personalize(questions, 'PR', null, TODAY);
  assert.equal(byN(pr, 61).answer, 'Jenniffer González-Colón.');
  assert.equal(byN(pr, 62).answer, 'San Juan.');
});

test('an expired term keeps the name, flagged as possibly out of date', () => {
  const answer = byN(personalize(questions, 'AK', null, '2027-01-05'), 61).answer;
  assert.match(answer, /^Mike Dunleavy\./);
  assert.match(answer, /out of date/);
});

test('future entries take over on their start date', () => {
  assert.doesNotMatch(byN(personalize(questions, 'OH', null, '2025-01-20'), 23).answer, /Jon Husted/);
  assert.match(byN(personalize(questions, 'OH', null, '2025-01-21'), 23).answer, /Jon Husted/);
});

test('district options carry the current members', () => {
  const options = districtOptions('CA', TODAY);
  assert.equal(options.length, 52);
  assert.deepEqual(options.find(o => o.district === 12), { district: 12, name: 'Lateefah Simon' });
  assert.deepEqual(districtOptions('WY', TODAY), []);
});
