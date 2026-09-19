// Native speech driver for the desktop (Tauri) build. desktop/build.mjs swaps
// this module in for web/src/speech.js at bundle time, so engine.js, main.js,
// and the UI modules — which import './speech.js' — run against it unchanged.
// Utterances go to the OS speech engine (Windows SAPI / Linux
// speech-dispatcher) via Tauri commands; word-boundary and completion events
// come back as `tts:boundary` / `tts:end` Tauri events, mirroring the
// SpeechSynthesisUtterance callbacks the web driver uses. Media keys arrive
// from the OS media session (SMTC / MPRIS) as `media:action` events and map to
// the same engine calls the web app wires to navigator.mediaSession.
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { spokenLanguage, bilingual, TTS_LOCALE } from '../../web/src/i18n.js';
import { state, Phase, primaryAction, pause, next, previous } from '../../web/src/engine.js';

export const speech = {
  supported: typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window,
  voices: [],
  currentId: null,
  ondone: null,
  /** Word-boundary callback(id, start, end); positions are UTF-16 indices. */
  onboundary: null,
  /** Called after the voice list (re)loads so the UI can refresh the TTS warning. */
  onvoiceschanged: null,
  init() {
    if (!this.supported) return;
    const self = this;
    listen('tts:boundary', e => {
      const p = e.payload || {};
      if (self.currentId !== p.utterance) return; // stale (superseded or stopped)
      if (self.onboundary) self.onboundary(p.utterance, p.start, p.end);
    });
    listen('tts:end', e => {
      const p = e.payload || {};
      if (self.currentId !== p.utterance) return; // stale, like the web driver's onerror 'canceled'
      self.currentId = null;
      if (self.ondone) self.ondone(p.utterance);
    });
    /* ---------- media keys (SMTC / MPRIS -> Rust -> here) ---------- */
    listen('media:action', e => {
      const a = e.payload;
      if (a === 'play') primaryAction();
      else if (a === 'pause' || a === 'stop') pause();
      else if (a === 'next') next();
      else if (a === 'previous') previous();
      else if (a === 'toggle') { if (state.phase === Phase.IDLE) primaryAction(); else pause(); }
    });
    this.refreshVoices();
  },
  refreshVoices() {
    const self = this;
    invoke('tts_voices')
      .then(vs => { self.voices = Array.isArray(vs) ? vs : []; })
      .catch(() => { self.voices = []; })
      .finally(() => { if (self.onvoiceschanged) self.onvoiceschanged(); });
  },
  voiceFor(lang) {
    // Same match ladder as the web driver (exact -> region -> base language),
    // minus the localService check — every OS voice is local.
    const norm = s => String(s || '').toLowerCase().replace(/_/g, '-');
    const want = norm(lang);
    const base = want.split('-')[0];
    const vs = this.voices;
    const exact = v => norm(v.lang) === want;
    const region = v => norm(v.lang).startsWith(want + '-');
    const anyBase = v => norm(v.lang) === base || norm(v.lang).startsWith(base + '-');
    return vs.find(exact)
      || vs.find(region)
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
    const self = this;
    invoke('tts_speak', { utteranceId: id, text: opts.text, voiceId: voice.id, rate: opts.rate })
      .catch(() => { // dispatch failed: skip the utterance rather than wedging the session
        if (self.currentId !== id) return;
        self.currentId = null;
        done();
      });
  },
  stop() {
    this.currentId = null;
    if (this.supported) { try { invoke('tts_stop').catch(() => {}); } catch (e) {} }
  },
};
export function ttsAvailable() {
  if (!speech.supported) return false;
  const lang = spokenLanguage();
  if (!speech.voiceFor(TTS_LOCALE.english)) return false;
  if (bilingual() && !speech.voiceFor(TTS_LOCALE[lang])) return false;
  return true;
}

/* ---------- media session (SMTC / MPRIS metadata + headset buttons) ---------- */
export function updateMediaSession() {
  if (!speech.supported) return;
  try {
    invoke('media_update', {
      title: state.current ? 'Q' + state.current.n + ' · ' + state.current.category : null,
      artist: 'Civics Audio Prep',
      playing: state.phase !== Phase.IDLE,
    }).catch(() => {});
  } catch (e) {}
}
