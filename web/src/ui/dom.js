// Tiny DOM helpers shared by every tab renderer.
export function el(id) { return document.getElementById(id); }
export function setText(id, txt) { const n = el(id); if (n) n.textContent = txt; }
export function show(id, on) { const n = el(id); if (n) n.hidden = !on; }
/* Offset of the occurrence of display inside spoken that the spoken range
   start..end overlaps most, so a display text repeated in the spoken text
   lights the copy actually being read. Falls back to the first occurrence
   when none overlap; -1 when display never occurs. */
function bestOccurrence(spoken, display, start, end) {
  if (!display) return -1;
  let best = -1, bestOverlap = -1, from = 0;
  while (from <= spoken.length) {
    const at = spoken.indexOf(display, from);
    if (at < 0) break;
    const overlap = Math.max(0, Math.min(at + display.length, end) - Math.max(at, start));
    if (overlap > bestOverlap) { best = at; bestOverlap = overlap; }
    from = at + 1;
  }
  return best;
}
/* Splits a line's text around the spoken range for karaoke highlighting.
   display is the line's normal text; hl = {text, start, end} over the spoken
   string. When display isn't a substring of the spoken text (verbose English
   answer), the spoken text is shown instead. Pure — no DOM access. */
export function spokenSlices(display, hl) {
  const base = bestOccurrence(hl.text, display, hl.start, hl.end);
  const text = base >= 0 ? display : hl.text;
  const off = base >= 0 ? base : 0;
  const start = Math.min(Math.max(hl.start - off, 0), text.length);
  const end = Math.min(Math.max(hl.end - off, 0), text.length);
  return { text: text, start: start, end: Math.max(end, start) };
}
export function setSpokenText(id, display, hl) {
  const n = el(id);
  if (!n) return;
  if (!hl || hl.start == null || hl.end == null) { n.textContent = display; return; }
  const s = spokenSlices(display, hl);
  if (s.end <= s.start) { n.textContent = s.text; return; } // range inside the announce prefix
  n.textContent = '';
  n.appendChild(document.createTextNode(s.text.slice(0, s.start)));
  const mark = document.createElement('span');
  mark.className = 'spoken-word';
  mark.textContent = s.text.slice(s.start, s.end);
  n.appendChild(mark);
  n.appendChild(document.createTextNode(s.text.slice(s.end)));
}
export function makeChips(container, items, selected, onSelect) {
  const wrap = el(container);
  const key = JSON.stringify([items.map(it => it.label), selected]);
  if (wrap.dataset.key === key) return; // avoid focus-stealing rebuilds on every state change
  wrap.dataset.key = key;
  wrap.innerHTML = '';
  items.forEach(it => {
    const b = document.createElement('button');
    b.className = 'chip';
    b.textContent = it.label;
    b.setAttribute('aria-pressed', String(it.value === selected));
    b.onclick = () => onSelect(it.value);
    wrap.appendChild(b);
  });
}
