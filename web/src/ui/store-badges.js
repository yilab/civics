// Mobile app store badges. Store links — paste each URL when the app is published.
// While a store's URL is empty its badge renders inert (not a link) with a
// "Coming soon" tag; paste a URL and the badge becomes a real link automatically.
const STORE_LINKS = { ios: '', mac: '', android: '' };  // TODO: paste store URLs when published

import { el, setText } from './dom.js';
import { t } from '../i18n.js';

const APPLE_SVG = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>';
const PLAY_SVG = '<svg viewBox="0 0 24 24" aria-hidden="true"><polygon points="3,2.5 11,8.5 21,12" fill="#00F076"/><polygon points="3,21.5 11,15.5 21,12" fill="#FFE000"/><polygon points="3,2.5 3,21.5 11,15.5 11,8.5" fill="#00D2FF"/><polygon points="11,8.5 11,15.5 21,12" fill="#FF3A44"/></svg>';
const STORE_DEFS = [
  { key: 'ios', topKey: 'store_download_on', name: 'App Store', logo: APPLE_SVG },
  { key: 'mac', topKey: 'store_download_on', name: 'Mac App Store', logo: APPLE_SVG },
  { key: 'android', topKey: 'store_get_it_on', name: 'Google Play', logo: PLAY_SVG },
];
function platformRec() {
  const ua = navigator.userAgent || '';
  if (/iPhone|iPad|iPod/.test(ua)) return 'ios';
  if (/Android/.test(ua)) return 'android';
  if (/Macintosh|Mac OS X/.test(ua)) return 'mac';
  return null;
}
export function renderStore() {
  setText('store-eyebrow', t('store_eyebrow'));
  setText('store-heading', t('store_heading'));
  setText('store-sub', t('store_sub'));
  const rec = platformRec();
  const wrap = el('store-badges');
  wrap.innerHTML = '';
  STORE_DEFS.forEach(d => {
    const url = STORE_LINKS[d.key];
    const top = t(d.topKey);
    const node = document.createElement(url ? 'a' : 'span');
    node.className = 'store-badge' + (url ? '' : ' off') + (rec === d.key ? ' rec' : '');
    const aria = top + ' ' + d.name + (url ? '' : ' — ' + t('store_coming_soon'));
    node.setAttribute('aria-label', rec === d.key ? aria + ' — ' + t('store_recommended') : aria);
    if (url) {
      node.href = url;
      node.target = '_blank';
      node.rel = 'noopener';
    } else {
      node.setAttribute('aria-disabled', 'true');
      const soon = document.createElement('span');
      soon.className = 'soon-tag';
      soon.textContent = t('store_coming_soon');
      node.appendChild(soon);
    }
    if (rec === d.key) node.title = t('store_recommended');
    node.insertAdjacentHTML('beforeend', d.logo);
    const text = document.createElement('span');
    text.className = 'sb-text';
    const topEl = document.createElement('span');
    topEl.className = 'sb-top';
    topEl.textContent = top;
    const nameEl = document.createElement('span');
    nameEl.className = 'sb-name';
    nameEl.textContent = d.name;
    text.appendChild(topEl);
    text.appendChild(nameEl);
    node.appendChild(text);
    wrap.appendChild(node);
  });
}
