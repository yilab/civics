// The whole web app — real render and engine code — driven in Node against the
// browser stand-in. Starts with one missed test question in the stats, which
// gives the Questions list its miss badge. Tests share one app instance, in order.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { store, $, sleep, until } from './support/browser.mjs';

store.set('civics.question_stats', JSON.stringify({ 5: { r: 0, w: 1, lw: 1 } }));
const E = await import('../src/engine.js');
const S = await import('../src/settings.js');
await import('../src/main.js');
const { state, Phase, Mode } = E;

const DEFAULTS = { category: 'All', knownFilter: 'all', shuffle: false, thinkSeconds: -1, autoAdvance: false };
/** Back to a stopped study deck with the given settings (think: wait for a press). */
function reset(overrides = {}) {
  E.pause();
  Object.assign(S.settings, DEFAULTS, overrides);
  S.settings.known.clear();
  E.startStudy();
}
/** The question numbers next() walks through, from the deck's first question. */
function walk(first, count) {
  E.jumpTo(first);
  const ns = [state.current.n];
  while (ns.length < count) { E.next(); ns.push(state.current.n); }
  return ns;
}
const history = () => JSON.parse(store.get('civics.test_history') || '[]');

test('Settings renders every control', () => {
  assert.equal($('s-place').children.length, 57); // "Not set" + 56 places
  assert.equal($('s-think-chips').children.length, 5);
  assert.equal($('s-cat-chips').children.length, 5);
});

test('hands-free listening reveals the answer after the think pause', async () => {
  reset({ thinkSeconds: 1 });
  $('l-primary').click();
  assert.ok(await until(() => state.phase === Phase.THINKING));
  assert.ok(await until(() => state.phase === Phase.AWAITING_ADVANCE, 2500), `stuck in ${state.phase}`);
});

test('a new state reaches the Listen deck and the current question', () => {
  reset();
  E.jumpTo(61);
  E.pause();
  assert.equal(state.current.answer, 'Depends on your state.');
  $('s-place').value = 'CA';
  $('s-place').dispatch('change');
  assert.equal(state.current.answer, 'Gavin Newsom.');
  S.setLocation(null, null);
  E.applySettings();
});

test('"Not known": marking the playing question known continues with the next one', async () => {
  reset({ knownFilter: 'notKnown' });
  E.primaryAction(); // Q1
  E.next(); // Q2
  await until(() => state.phase === Phase.THINKING);
  E.setKnown(2, true);
  E.next();
  assert.equal(state.current.n, 3);
  // Stopped on Q3, then Q3 and Q4 marked known: play resumes at Q5.
  E.pause();
  E.setKnown(3, true);
  E.setKnown(4, true);
  E.primaryAction();
  assert.equal(state.current.n, 5);
  // Previous goes to the question before the one that left.
  E.setKnown(5, true);
  E.previous();
  assert.equal(state.current.n, 1);
});

test('Shuffle keeps its order across settings changes', () => {
  reset({ shuffle: true, knownFilter: 'notKnown' });
  E.primaryAction();
  const order = walk(state.current.n, 8);
  S.settings.thinkSeconds = 5;
  E.applySettings();
  assert.deepEqual(walk(order[0], 8), order);
  // A question marked known drops out in place.
  E.setKnown(order[3], true);
  assert.deepEqual(walk(order[0], 7), order.filter(n => n !== order[3]));
});

test('a paused test stays on screen and resumes on the same question', () => {
  reset();
  E.startTest();
  const q = state.current.n;
  E.pause(); // a hidden tab, a lock-screen pause
  assert.equal($('test-run').hidden, false);
  assert.equal($('test-start').hidden, true);
  assert.equal($('t-reveal').textContent, 'Resume test');
  E.primaryAction(); // Resume
  assert.equal(state.mode, Mode.TEST);
  assert.equal(state.phase, Phase.SPEAKING_QUESTION);
  assert.equal(state.current.n, q);
  $('t-stop').click(); // End test
  assert.equal(state.mode, Mode.STUDY);
  assert.equal($('test-start').hidden, false);
});

test('jumping to a question mid-test leaves the test alone', () => {
  reset();
  E.startTest();
  const q = state.current.n;
  E.jumpTo(23); // never in a test deck while no state is set
  assert.equal(state.current.n, q);
  assert.equal(state.testIndex, 0);
  assert.equal(E.deckSize(), 20);
});

test('a finished test stays finished: pause and play cannot reopen it', async () => {
  reset({ thinkSeconds: 0 });
  const before = history().length;
  E.startTest();
  for (let i = 0; i < 12; i++) {
    assert.ok(await until(() => state.phase === Phase.AWAITING_GRADE), `stuck in ${state.phase}`);
    E.grade(true);
  }
  assert.equal(state.phase, Phase.FINISHED);
  assert.equal(E.isPlaying(), false);
  E.pause();
  E.primaryAction();
  await sleep(30);
  assert.equal(state.phase, Phase.FINISHED);
  assert.equal(history().length, before + 1);
  // The finished test lists the answer that ended it.
  assert.equal(state.answers.length, 12);
  // Jumping to a question afterwards goes back to study.
  E.jumpTo(7);
  assert.equal(state.mode, Mode.STUDY);
  assert.equal(state.current.n, 7);
});
