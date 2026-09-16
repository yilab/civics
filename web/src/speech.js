// Speech engine wrapper (Web Speech API; mirrors SpeechEngine) plus Media Session
// integration (headset / lock-screen buttons). Imports engine bindings only for
// media-session handlers and metadata; those run after both modules are live.
import { spokenLanguage, bilingual, TTS_LOCALE } from './i18n.js';
import { state, Phase, primaryAction, pause, next, previous } from './engine.js';

export const speech = {
  supported: typeof window !== 'undefined' && 'speechSynthesis' in window,
  voices: [],
  currentId: null,
  ondone: null,
  /** Word-boundary callback(id, start, end); never fires on some platforms. */
  onboundary: null,
  /** Called after the voice list (re)loads so the UI can refresh the TTS warning. */
  onvoiceschanged: null,
  init() {
    if (!this.supported) return;
    const load = () => {
      try { this.voices = window.speechSynthesis.getVoices() || []; } catch (e) { this.voices = []; }
      if (this.onvoiceschanged) this.onvoiceschanged();
    };
    load();
    try {
      if (typeof window.speechSynthesis.addEventListener === 'function') {
        window.speechSynthesis.addEventListener('voiceschanged', load);
      } else {
        window.speechSynthesis.onvoiceschanged = load;
      }
    } catch (e) {}
  },
  voiceFor(lang) {
    const norm = s => String(s || '').toLowerCase().replace(/_/g, '-');
    const want = norm(lang);
    const base = want.split('-')[0];
    const vs = this.voices;
    const exact = v => norm(v.lang) === want;
    const region = v => norm(v.lang).startsWith(want + '-');
    const anyBase = v => norm(v.lang) === base || norm(v.lang).startsWith(base + '-');
    // Prefer OS-local voices: desktop Chrome lists Google's network voices first,
    // and when one of those fails Chrome silently falls back to the default voice,
    // which reads non-Latin text as punctuation ("dot dot"). localService is
    // undefined on Safari — treat it as local.
    const local = v => v.localService !== false;
    return vs.find(v => local(v) && exact(v))
      || vs.find(exact)
      || vs.find(v => local(v) && region(v))
      || vs.find(region)
      || vs.find(v => local(v) && anyBase(v))
      || vs.find(anyBase)
      || null;
  },
  available(lang) { return this.supported && !!this.voiceFor(lang); },
  speak(opts) {
    const id = opts.id;
    const done = () => { if (this.ondone) this.ondone(id); };
    if (!this.supported) { setTimeout(done, 0); return; }
    const voice = this.voiceFor(opts.lang);
    if (!voice) { setTimeout(done, 0); return; } // no voice: no-op, keep the flow alive
    this.currentId = id;
    const u = new SpeechSynthesisUtterance(opts.text);
    u.lang = voice.lang;
    u.voice = voice;
    u.rate = opts.rate;
    u.onend = () => {
      if (this.currentId !== id) return; // stale
      this.currentId = null;
      done();
    };
    u.onerror = e => {
      const err = e && e.error;
      if (err === 'interrupted' || err === 'canceled') return; // expected from cancel()
      if (this.currentId !== id) return;
      this.currentId = null;
      // Skip a failed utterance rather than wedging the session (a flaky network
      // voice must not stall the deck); the flow continues as if it had ended.
      try { console.warn('speech: utterance failed (' + err + '), skipping', id); } catch (e2) {}
      done();
    };
    u.onboundary = e => {
      if (this.currentId !== id) return; // stale
      if (e.name && e.name !== 'word') return;
      const start = e.charIndex;
      if (typeof start !== 'number') return;
      // charLength is undefined on some browsers — scan to the next whitespace.
      let end = start;
      if (typeof e.charLength === 'number') end = start + e.charLength;
      else while (end < opts.text.length && !/\s/.test(opts.text.charAt(end))) end++;
      if (this.onboundary) this.onboundary(id, start, end);
    };
    try { window.speechSynthesis.cancel(); } catch (e) {} // QUEUE_FLUSH
    const self = this;
    // Safari needs a tick between cancel() and speak()
    setTimeout(() => {
      if (self.currentId !== id) return;
      try { window.speechSynthesis.speak(u); } catch (e) { self.currentId = null; done(); }
    }, 0);
  },
  stop() {
    this.currentId = null;
    if (this.supported) { try { window.speechSynthesis.cancel(); } catch (e) {} }
  },
};
export function ttsAvailable() {
  if (!speech.supported) return false;
  const lang = spokenLanguage();
  if (!speech.voiceFor(TTS_LOCALE.english)) return false;
  if (bilingual() && !speech.voiceFor(TTS_LOCALE[lang])) return false;
  return true;
}

/* ---------- media session (headset / lock-screen buttons) ---------- */
export function updateMediaSession() {
  if (!('mediaSession' in navigator)) return;
  try {
    if (state.current) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: 'Q' + state.current.n + ' · ' + state.current.category,
        artist: 'Civics Audio Prep',
      });
    }
    navigator.mediaSession.playbackState = state.phase === Phase.IDLE ? 'paused' : 'playing';
  } catch (e) {}
}
if ('mediaSession' in navigator) {
  const handle = (action, fn) => { try { navigator.mediaSession.setActionHandler(action, fn); } catch (e) {} };
  handle('play', () => primaryAction());
  handle('pause', () => pause());
  handle('nexttrack', () => next());
  handle('previoustrack', () => previous());
}
