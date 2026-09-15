// Tiny DOM helpers shared by every tab renderer.
export function el(id) { return document.getElementById(id); }
export function setText(id, txt) { const n = el(id); if (n) n.textContent = txt; }
export function show(id, on) { const n = el(id); if (n) n.hidden = !on; }
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
