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
  onerror: null,
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
    return vs.find(v => norm(v.lang) === want)
      || vs.find(v => norm(v.lang).startsWith(want + '-'))
      || vs.find(v => norm(v.lang) === base || norm(v.lang).startsWith(base + '-'))
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
      if (this.onerror) this.onerror(id);
    };
    try { window.speechSynthesis.cancel(); } catch (e) {} // QUEUE_FLUSH
    const self = this;
    // Safari needs a tick between cancel() and speak()
    setTimeout(() => {
      if (self.currentId !== id) return;
      try { window.speechSynthesis.speak(u); } catch (e) { if (self.onerror) self.onerror(id); }
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
