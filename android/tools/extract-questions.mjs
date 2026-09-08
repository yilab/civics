// Extracts the 128-question civics bank from civics-test-study-tool.html into
// app/src/main/assets/questions.json, adding a TTS-friendly "spoken" field.
// Usage: node tools/extract-questions.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const html = readFileSync(new URL('../../web/civics-test-study-tool.html', import.meta.url), 'utf8');
const m = html.match(/const Q = (\[[\s\S]*?\]);\s*\n/);
if (!m) throw new Error('question array not found');
const Q = eval(m[1]);
if (Q.length !== 128) throw new Error(`expected 128 questions, got ${Q.length}`);

// Simplified-Chinese translations live in the QZ map keyed by question number.
// zh answers are written as TTS-friendly prose (no parentheses), so they double
// as the spoken text.
const mz = html.match(/const QZ = (\{[\s\S]*?\});\s*\n/);
if (!mz) throw new Error('translation map not found');
const QZ = eval(`(${mz[1]})`);
for (const item of Q) {
  if (!QZ[item.n] || !QZ[item.n].q || !QZ[item.n].a) {
    throw new Error(`missing zh translation for question ${item.n}`);
  }
}

// Hand-tuned spoken text where heuristics read badly. Keyed by question number.
const SPOKEN_OVERRIDES = {
  5: 'Through amendments, the amendment process.',
  12: 'A free-market economy, or capitalism.',
  13: 'Everyone must follow the law. No one is above the law, including leaders and the government.',
  16: 'Legislative: Congress. Executive: the President. Judicial: the courts.',
  18: 'Congress, the legislative branch.',
  23: "This answer depends on your state. Look up your state's two U.S. senators before your interview.",
  28: 'For equal representation among the states. Also acceptable: the Great Compromise, also called the Connecticut Compromise.',
  29: 'This answer depends on where you live. Look up your U.S. representative before your interview.',
  30: 'Mike Johnson. Verify this before your interview, current officials can change.',
  35: "Because they have more people, the state's population.",
  38: 'Donald J. Trump. Verify this before your interview, current officials can change.',
  39: 'JD Vance. Verify this before your interview, current officials can change.',
  48: 'For example: Secretary of State and Secretary of Transportation. Any two department secretaries, the Attorney General, or the Vice President are acceptable.',
  56: 'To be independent of politics or outside influence.',
  57: 'John Roberts. Verify this before your interview, current officials can change.',
  61: 'This answer depends on your state. Look up your governor before your interview.',
  62: 'This answer depends on your state. Look up your state capital before your interview.',
  65: 'Freedom of speech, freedom of religion, and freedom of assembly. Also acceptable: freedom of the press, the right to bear arms, or freedom to petition the government.',
  74: 'Native Americans, also called American Indians.',
  75: 'Africans, people from Africa.',
  76: 'The American Revolution, also called the Revolutionary War.',
  77: "High taxes, taxation without representation. Also acceptable: British soldiers stayed in their houses, or they didn't have self-government.",
  83: 'James Madison. Also acceptable: Alexander Hamilton, or John Jay. They published under the name Publius.',
  94: 'He freed the slaves with the Emancipation Proclamation. Also acceptable: he saved the Union, or was President during the Civil War.',
  102: 'After World War I, in 1920, with the 19th Amendment.',
  108: 'The Soviet Union, or Russia.',
  117: 'For example: Hopi, Navajo, Cherokee, Sioux, Apache, Iroquois, Pueblo, Chippewa, Choctaw, or Seminole. Any federally recognized tribe is acceptable.',
  120: 'New York Harbor, Liberty Island. Also acceptable: New Jersey, near New York City, or on the Hudson River.',
  125: "A holiday celebrating the country's birthday: the adoption of the Declaration of Independence, the Fourth of July.",
};

function splitAlternatives(x) {
  return x
    .split(/;\s*/)
    .join(', or ')
    .replace(/\s*\/\s*/g, ' or ');
}

function tidy(s) {
  return s
    .replace(/[“”]/g, '"')
    .replace(/\s*\/\s*/g, ' or ')
    .replace(/;\s+([a-z])/g, (_, c) => '. ' + c.toUpperCase())
    .replace(/\s+/g, ' ')
    .replace(/\s+\./g, '.')
    .replace(/\.\.+/g, '.')
    .replace(/, /g, ', ')
    .trim()
    .replace(/([^.])$/, '$1.');
}

function heuristicSpoken(answer) {
  let s = answer.replace(/[“”]/g, '"');
  // "(also: X)" -> ". Also acceptable: X"
  s = s.replace(/\s*\(also:\s*([^)]*)\)/g, (_, x) => `. Also acceptable: ${splitAlternatives(x)}`);
  // trailing parenthetical that lists alternatives (contains ";" or "/")
  s = s.replace(/\s*\(([^)]*[;/][^)]*)\)\s*$/g, (_, x) => `. Also acceptable: ${splitAlternatives(x)}`);
  // purely numeric parenthetical like "(27)" -> drop (keep the word form)
  s = s.replace(/\s*\(\d+\)/g, '');
  // remaining parentheticals are inline clarifications: drop the parens, keep the text
  s = s.replace(/[()]/g, '');
  return tidy(s);
}

// Extra languages (Spanish, Traditional Chinese) live in a separate file so the
// web tool's QZ map stays the Simplified-Chinese source of truth.
const extra = JSON.parse(
  readFileSync(new URL('./translations-extra.json', import.meta.url), 'utf8'),
);

const questions = Q.map((item) => {
  const spoken = SPOKEN_OVERRIDES[item.n] ?? heuristicSpoken(item.a);
  const zh = QZ[item.n];
  const translations = {
    'zh-Hans': { question: zh.q, answer: zh.a, spoken: zh.a, note: zh.note ?? null },
  };
  for (const code of ['es', 'zh-Hant', 'vi', 'tl', 'ko', 'ar', 'hi', 'pt', 'ru']) {
    const t = extra[code]?.[item.n];
    if (!t || !t.q || !t.a) throw new Error(`missing ${code} translation for question ${item.n}`);
    translations[code] = { question: t.q, answer: t.a, spoken: t.a, note: t.note ?? null };
  }
  return {
    n: item.n,
    category: item.c,
    question: item.q.replace(/[“”]/g, '"'),
    answer: item.a,
    spoken,
    dynamic: item.dyn === true,
    note: item.note ? item.note.replace(/<[^>]+>/g, '') : null,
    translations,
  };
});

// audit: no leftover parens or double spaces in spoken text (all languages)
const bad = questions.filter(
  (q) =>
    /[()]/.test(q.spoken) ||
    / {2}/.test(q.spoken) ||
    Object.values(q.translations).some((t) => /[()（）]/.test(t.spoken)),
);
if (bad.length) {
  console.error('suspicious spoken text:', bad.map((q) => q.n));
  process.exit(1);
}

const out = { version: '2025', count: questions.length, questions };
const json = JSON.stringify(out, null, 2) + '\n';
const targets = [
  new URL('../app/src/main/assets/questions.json', import.meta.url),
  new URL('../../apple/Civics/Civics/Resources/questions.json', import.meta.url),
];
for (const target of targets) {
  mkdirSync(new URL('.', target), { recursive: true });
  writeFileSync(target, json);
}
console.log(`wrote ${questions.length} questions to ${targets.length} targets`);
