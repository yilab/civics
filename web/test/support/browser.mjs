// A minimal browser stand-in, installed as globals on import: just enough DOM,
// localStorage and speechSynthesis for the app's modules to load and run their
// real render and engine code in Node. Utterances "finish" a few ms after they
// start; elements are created on demand by id, as the app looks them up.

class TextNode {
  constructor(text) { this.nodeType = 3; this.textContent = String(text); }
}

class Elem {
  constructor(tag, id) {
    this.tagName = (tag || 'div').toUpperCase();
    this.id = id || '';
    this.childNodes = [];
    this.dataset = {};
    this.style = {};
    this.attrs = {};
    this.hidden = false;
    this.disabled = false;
    this.value = '';
    this.checked = false;
    this.listeners = {};
    const classes = new Set();
    this.classes = classes;
    this.classList = {
      toggle(c, on) { if (on === undefined) on = !classes.has(c); if (on) classes.add(c); else classes.delete(c); return on; },
      add(c) { classes.add(c); },
      remove(c) { classes.delete(c); },
      contains(c) { return classes.has(c); },
    };
  }
  get className() { return [...this.classes].join(' '); }
  set className(v) { this.classes.clear(); String(v).split(/\s+/).filter(Boolean).forEach(c => this.classes.add(c)); }
  get children() { return this.childNodes.filter(n => n instanceof Elem); }
  get firstChild() { return this.childNodes[0] || null; }
  get textContent() { return this.childNodes.map(n => n.textContent).join(''); }
  set textContent(v) { this.childNodes = [new TextNode(v)]; }
  get innerHTML() { return ''; }
  set innerHTML(v) { this.childNodes = []; }
  appendChild(node) { this.childNodes.push(node); return node; }
  insertAdjacentHTML() {}
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] ?? null; }
  addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn); }
  /** Fires an event's listeners (e.g. 'change' after setting value). */
  dispatch(type) { (this.listeners[type] || []).forEach(fn => fn({ target: this })); }
  click() {
    if (this.disabled) return;
    if (this.onclick) this.onclick({ target: this });
    this.dispatch('click');
  }
  /** Class selectors only (".name"). */
  querySelector(selector) {
    const name = selector.replace(/^\./, '');
    for (const child of this.children) {
      if (child.classes.has(name)) return child;
      const found = child.querySelector(selector);
      if (found) return found;
    }
    return null;
  }
  matches() { return false; }
  focus() {}
  blur() {}
}

const byId = new Map();
globalThis.document = {
  getElementById(id) {
    if (!byId.has(id)) byId.set(id, new Elem('div', id));
    return byId.get(id);
  },
  createElement: tag => new Elem(tag),
  createTextNode: text => new TextNode(text),
  documentElement: { lang: 'en' },
  addEventListener() {},
  hidden: false,
};
globalThis.window = globalThis;
window.addEventListener = () => {};

/** The localStorage backing map; seed it before importing the app. */
export const store = new Map();
Object.defineProperty(globalThis, 'localStorage', {
  configurable: true,
  value: {
    getItem: k => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: k => store.delete(k),
  },
});

globalThis.SpeechSynthesisUtterance = class { constructor(text) { this.text = text; } };
window.speechSynthesis = {
  getVoices: () => [{ lang: 'en-US', localService: true, name: 'Test voice' }],
  addEventListener() {},
  cancel() {},
  speak(u) { setTimeout(() => u.onend && u.onend({}), 5); },
};

export const $ = id => document.getElementById(id);
export const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
/** Resolves true once pred() holds, or false after ms. */
export async function until(pred, ms = 2000) {
  const t0 = Date.now();
  while (!pred() && Date.now() - t0 < ms) await sleep(2);
  return pred();
}
