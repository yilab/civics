// Test deck selection (port of TestPicker.kt): pure sampling rules, kept free
// of engine state so they stay unit-testable. shuffleArr lives here too —
// engine.js re-exports it — because the engine imports from this module.
export const TEST_TOTAL = 20;

export function shuffleArr(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = a[i]; a[i] = a[j]; a[j] = tmp;
  }
  return a;
}

/* Missed = the last answer was wrong, or misses dominate the history. */
export function isMissed(stat) {
  return !!stat && (stat.lw > 0 || (stat.w >= 2 && stat.w >= stat.r));
}

/* The standard test deck: a random 20, with up to half drawn from missed
   questions when focus is on. With nothing missed (or focus off) this is a
   plain uniform shuffle of the pool — the historical behavior. */
export function pickDeck(pool, stats, focus) {
  if (!focus) return shuffleArr(pool.slice()).slice(0, TEST_TOTAL);
  const missedNumbers = new Set(pool.filter(q => isMissed(stats[q.n])).map(q => q.n));
  if (!missedNumbers.size) return shuffleArr(pool.slice()).slice(0, TEST_TOTAL);
  const missedPool = shuffleArr(pool.filter(q => missedNumbers.has(q.n)));
  const restPool = shuffleArr(pool.filter(q => !missedNumbers.has(q.n)));
  const missedCount = Math.min(Math.floor(TEST_TOTAL / 2), missedPool.length);
  const restCount = Math.min(TEST_TOTAL - missedCount, restPool.length);
  return shuffleArr(missedPool.slice(0, missedCount).concat(restPool.slice(0, restCount)));
}

/* Missed questions ranked for review: most misses first, ties by most recent
   miss. Deterministic — callers shuffle the cut they take. */
export function reviewRanking(pool, stats) {
  return pool
    .filter(q => isMissed(stats[q.n]))
    .sort((x, y) => {
      const sx = stats[x.n] || { r: 0, w: 0, lw: 0 };
      const sy = stats[y.n] || { r: 0, w: 0, lw: 0 };
      return (sy.w - sx.w) || (sy.lw - sx.lw);
    });
}

/* Pass/fail marks scaled to the deck size, keeping the real interview's 60%
   bar: 20 questions -> 12/9. (n=2 -> 2/1: a single miss fails a pair.) */
export function thresholds(n) {
  const passAt = Math.ceil(n * 0.6);
  return [passAt, n - passAt + 1];
}
