// Practice-test deck rules (picker.js), mirroring TestPickerTest.kt.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pickDeck, reviewRanking, thresholds, TEST_TOTAL } from '../src/picker.js';

const pool = (...ns) => ns.map(n => ({ n }));
const range = (a, b) => Array.from({ length: b - a + 1 }, (_, i) => a + i);
const missed = (w, lw) => ({ r: 0, w, lw });

test('thresholds keep the 60% bar and match the interview at twenty', () => {
  assert.deepEqual(thresholds(20), [12, 9]);
  assert.deepEqual(thresholds(1), [1, 1]);
  assert.deepEqual(thresholds(2), [2, 1]);
  assert.deepEqual(thresholds(3), [2, 2]);
  assert.deepEqual(thresholds(10), [6, 5]);
});

test('pickDeck without missed questions is a plain sample of the pool', () => {
  const deck = pickDeck(pool(...range(1, 30)), {}, true);
  assert.equal(deck.length, TEST_TOTAL);
  assert.equal(new Set(deck.map(q => q.n)).size, deck.length);
  assert.ok(deck.every(q => q.n >= 1 && q.n <= 30));
});

test('pickDeck pulls every missed question when few are missed', () => {
  const stats = { 1: missed(2, 10), 5: missed(1, 20), 9: missed(3, 30) };
  const ns = pickDeck(pool(...range(1, 30)), stats, true).map(q => q.n);
  assert.equal(ns.length, TEST_TOTAL);
  for (const n of [1, 5, 9]) assert.ok(ns.includes(n), `Q${n} in the deck`);
});

test('pickDeck caps the missed slice at half the deck', () => {
  const stats = Object.fromEntries(range(1, 15).map(n => [n, missed(3, 10)]));
  const ns = pickDeck(pool(...range(1, 30)), stats, true).map(q => q.n);
  assert.equal(ns.filter(n => n <= 15).length, 10);
  assert.equal(ns.filter(n => n > 15).length, 10);
});

test('pickDeck over a small pool returns the whole pool; an empty pool, nothing', () => {
  assert.deepEqual(pickDeck(pool(1, 2, 3), { 1: missed(1, 5) }, true).map(q => q.n).sort(), [1, 2, 3]);
  assert.deepEqual(pickDeck([], {}, true), []);
});

test('reviewRanking orders by misses, then recency, and skips the unmissed', () => {
  const stats = {
    1: { r: 2, w: 1, lw: 500 }, // last answer wrong
    2: { r: 0, w: 3, lw: 100 }, // most misses
    3: { r: 5, w: 0, lw: 0 }, // never missed
    4: { r: 0, w: 3, lw: 900 }, // ties Q2, more recent
    5: { r: 0, w: 2, lw: 0 }, // misses dominate, oldest
  };
  assert.deepEqual(reviewRanking(pool(1, 2, 3, 4, 5), stats).map(q => q.n), [4, 2, 5, 1]);
  assert.deepEqual(reviewRanking(pool(1, 2), { 1: missed(1, 10), 99: missed(9, 99) }).map(q => q.n), [1]);
  assert.deepEqual(reviewRanking(pool(1, 2, 3), {}), []);
});
