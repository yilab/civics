// Language model and UI chrome strings (mirrors SpeechLanguage.kt, with the
// StudySettings.kt language derivation). The 4-language catalogs come from
// android/res values*.xml — see the note above CHROME for the es/zh-Hant caveat.

import { settings } from './settings.js';

/* ---------- language model (mirrors SpeechLanguage.kt) ---------- */
export const AUTONYM = {
  english: 'English', 'zh-Hans': '简体中文', 'zh-Hant': '繁體中文', es: 'Español',
  vi: 'Tiếng Việt', tl: 'Tagalog', ko: '한국어', ar: 'العربية', hi: 'हिन्दी',
  pt: 'Português', ru: 'Русский',
};
export const TTS_LOCALE = {
  english: 'en-US', 'zh-Hans': 'zh-CN', 'zh-Hant': 'zh-TW', es: 'es', vi: 'vi',
  tl: 'fil', ko: 'ko', ar: 'ar', hi: 'hi', pt: 'pt', ru: 'ru',
};
export const Q_PREFIX = {
  english: n => 'Question ' + n + '.',
  'zh-Hans': n => '第 ' + n + ' 题。',
  'zh-Hant': n => '第 ' + n + ' 題。',
  es: n => 'Pregunta ' + n + '.',
  vi: n => 'Câu ' + n + '.',
  tl: n => 'Tanong ' + n + '.',
  ko: n => '질문 ' + n + '.',
  ar: n => 'السؤال ' + n + '.',
  hi: n => 'प्रश्न ' + n + '.',
  pt: n => 'Pergunta ' + n + '.',
  ru: n => 'Вопрос ' + n + '.',
};
export const CHROME_LOCALE = { en: 'en-US', es: 'es', 'zh-Hans': 'zh-CN', 'zh-Hant': 'zh-TW' };

/* ---------- UI chrome strings (from android/res values*.xml; es and zh-Hant
   files in the repo still hold placeholder zh-CN text, so correct Spanish and
   Traditional Chinese are supplied here) ---------- */
const CHROME = {
  en: {
    tab_listen: 'Listen', tab_cards: 'Flashcards', tab_questions: 'Questions', tab_test: 'Test', tab_settings: 'Settings',
    header_sub: 'The officer asks up to 20 of these questions. You need 12 correct to pass. Listen hands-free, flip cards to learn, then take a practice test that stops the moment you pass — or fail — just like the real one.',
    no_tts: 'No text-to-speech voice is available for the selected language in this browser. Voice coverage depends on the browser and device — for all 11 languages, try Microsoft Edge or the Civics Audio Prep mobile app.',
    store_note: 'Spoken audio uses your device\'s built-in voices, so language coverage varies by browser — Safari, Chrome, and Firefox may be missing some languages. The mobile app includes clear voices for all 11 languages, plus offline use and lock-screen controls.',
    no_questions: 'No questions',
    question_of: 'Question {a} of {b}',
    known_count: '{a} known',
    app_title: 'Civics Audio Prep',
    onboarding: 'Press Start, put this window aside, and answer each question out loud. Press Space — or your headset button — once to hear the answer or continue. Glance at the screen anytime: the word being spoken is highlighted.',
    acceptable_answer: 'ACCEPTABLE ANSWER',
    phase_speaking_question: 'Speaking the question — press to hear the answer',
    phase_thinking: 'Your turn — answer out loud, then press',
    phase_speaking_answer: 'Speaking the answer',
    phase_awaiting_advance: 'Press for the next question',
    phase_awaiting_grade: 'Did you get it right?',
    button_start: 'Start listening',
    button_hear_answer: 'Hear the answer',
    button_next_question: 'Next question',
    button_got_it: 'I got it',
    button_missed_it: 'I missed it',
    previous_question: 'Previous question',
    stop: 'Stop',
    mark_known: 'Mark known',
    known_label: 'Known',
    playing_suffix: ' · playing',
    questions_mark: 'Mark as known',
    questions_unmark: 'Unmark as known',
    answer_label: 'Answer',
    acceptable_answer_card: 'Acceptable answer',
    flip_reveal: 'tap to reveal ↻',
    flip_back: 'tap for question ↻',
    flashcard_aria: 'Flashcard. Activate to reveal the answer.',
    test_title: 'Practice test',
    test_rules: [
      'Up to 20 questions, one at a time.',
      'Reveal the answer, then mark whether you got it right.',
      'Reach 12 correct to pass; miss 9 and the test ends — like the real interview.',
    ],
    test_start: 'Start practice test',
    test_passed: 'Passed',
    test_failed: 'Not yet',
    test_verdict_pass: "You reached 12 correct — that's a passing score.",
    test_verdict_fail: '9 missed ends the test. Review in study mode, then try again.',
    test_again: 'Take another test',
    test_back: 'Back to listening',
    test_history: 'Recent tests',
    correct_label: 'correct', missed_label: 'missed',
    settings_language: 'Language', settings_voice: 'Voice', settings_playback: 'Playback', settings_deck: 'Deck', settings_progress: 'Progress',
    settings_ui_language: 'App language', ui_system: 'System',
    speech_rate: 'Speech rate: {a}×',
    announce_meta: 'Announce question number',
    think_pause: 'Pause before revealing the answer',
    think_wait: 'Wait', think_none: 'None', think_seconds: '{a}s',
    auto_advance: 'Auto-advance after the answer',
    shuffle: 'Shuffle',
    known_progress: '{a} of 128 marked as known',
    clear_known: 'Clear known marks',
    cat_all: 'All 128', cat_gov: 'American Government', cat_hist: 'American History', cat_sym: 'Symbols & Holidays',
    filter_all: 'All', filter_known: 'Known', filter_not_known: 'Not known',
    feat_no_ads: 'No ads', feat_no_data: 'No data collection',
    feat_readalong: 'Read-along highlighting', feat_open_source: 'Open source',
    store_eyebrow: 'iOS · MAC · ANDROID',
    store_heading: 'Get the mobile app',
    store_sub: 'Hands-free listening with lock-screen controls and headset buttons — and it works offline.',
    store_download_on: 'Download on the', store_get_it_on: 'Get it on',
    store_coming_soon: 'Coming soon', store_recommended: 'Recommended',
  },
  es: {
    tab_listen: 'Escuchar', tab_cards: 'Tarjetas', tab_questions: 'Preguntas', tab_test: 'Examen', tab_settings: 'Ajustes',
    header_sub: 'El oficial hace hasta 20 de estas preguntas. Necesita 12 correctas para aprobar. Escuche con manos libres, practique con tarjetas y haga un examen de práctica que termina en el momento en que aprueba — o reprueba — igual que el real.',
    no_tts: 'No hay ninguna voz de texto a voz disponible para el idioma seleccionado en este navegador. La cobertura de voces depende del navegador y del dispositivo: para los 11 idiomas, pruebe Microsoft Edge o la app móvil Civics Audio Prep.',
    store_note: 'El audio usa las voces integradas de su dispositivo, por lo que la cobertura de idiomas varía según el navegador: Safari, Chrome y Firefox pueden no tener algunos idiomas. La app móvil incluye voces claras para los 11 idiomas, funciona sin conexión y tiene controles en la pantalla de bloqueo.',
    no_questions: 'No hay preguntas',
    question_of: 'Pregunta {a} de {b}',
    known_count: '{a} aprendidas',
    app_title: 'Preparación de civismo en audio',
    onboarding: 'Pulse Comenzar, deje esta ventana a un lado y responda cada pregunta en voz alta. Pulse la barra espaciadora — o el botón de sus auriculares — una vez para escuchar la respuesta o continuar. Mire la pantalla cuando quiera: la palabra que se pronuncia aparece resaltada.',
    acceptable_answer: 'RESPUESTA ACEPTABLE',
    phase_speaking_question: 'Leyendo la pregunta — pulse para escuchar la respuesta',
    phase_thinking: 'Su turno — responda en voz alta y luego pulse',
    phase_speaking_answer: 'Leyendo la respuesta',
    phase_awaiting_advance: 'Pulse para la siguiente pregunta',
    phase_awaiting_grade: '¿La acertó?',
    button_start: 'Comenzar a escuchar',
    button_hear_answer: 'Escuchar la respuesta',
    button_next_question: 'Siguiente pregunta',
    button_got_it: 'La acerté',
    button_missed_it: 'La fallé',
    previous_question: 'Pregunta anterior',
    stop: 'Detener',
    mark_known: 'Marcar aprendida',
    known_label: 'Aprendida',
    playing_suffix: ' · sonando',
    questions_mark: 'Marcar como aprendida',
    questions_unmark: 'Quitar la marca de aprendida',
    answer_label: 'Respuesta',
    acceptable_answer_card: 'Respuesta aceptable',
    flip_reveal: 'toque para revelar ↻',
    flip_back: 'toque para la pregunta ↻',
    flashcard_aria: 'Tarjeta. Actívela para revelar la respuesta.',
    test_title: 'Examen de práctica',
    test_rules: [
      'Hasta 20 preguntas, una a la vez.',
      'Revele la respuesta y luego marque si la acertó.',
      'Alcance 12 correctas para aprobar; falle 9 y el examen termina — igual que la entrevista real.',
    ],
    test_start: 'Comenzar examen de práctica',
    test_passed: 'Aprobado',
    test_failed: 'Aún no',
    test_verdict_pass: 'Alcanzó 12 correctas — es una puntuación aprobatoria.',
    test_verdict_fail: '9 falladas terminan el examen. Repase en el modo de estudio y vuelva a intentarlo.',
    test_again: 'Hacer otro examen',
    test_back: 'Volver a escuchar',
    test_history: 'Exámenes recientes',
    correct_label: 'correctas', missed_label: 'falladas',
    settings_language: 'Idioma', settings_voice: 'Voz', settings_playback: 'Reproducción', settings_deck: 'Mazo', settings_progress: 'Progreso',
    settings_ui_language: 'Idioma de la aplicación', ui_system: 'Sistema',
    speech_rate: 'Velocidad de voz: {a}×',
    announce_meta: 'Anunciar el número de pregunta',
    think_pause: 'Pausa antes de revelar la respuesta',
    think_wait: 'Esperar', think_none: 'Ninguna', think_seconds: '{a} s',
    auto_advance: 'Avanzar automáticamente tras la respuesta',
    shuffle: 'Aleatorio',
    known_progress: '{a} de 128 marcadas como aprendidas',
    clear_known: 'Borrar las marcas de aprendidas',
    cat_all: 'Todas las 128', cat_gov: 'Gobierno estadounidense', cat_hist: 'Historia estadounidense', cat_sym: 'Símbolos y feriados',
    filter_all: 'Todas', filter_known: 'Aprendidas', filter_not_known: 'Por aprender',
    feat_no_ads: 'Sin anuncios', feat_no_data: 'Sin recopilación de datos',
    feat_readalong: 'Resaltado palabra por palabra', feat_open_source: 'Código abierto',
    store_eyebrow: 'iOS · MAC · ANDROID',
    store_heading: 'Descarga la app',
    store_sub: 'Escucha con manos libres, con controles en la pantalla de bloqueo y botones de auriculares — y funciona sin conexión.',
    store_download_on: 'Descárgalo en la', store_get_it_on: 'Consíguelo en',
    store_coming_soon: 'Próximamente', store_recommended: 'Recomendado',
  },
  'zh-Hans': {
    tab_listen: '听题', tab_cards: '抽认卡', tab_questions: '题库', tab_test: '测试', tab_settings: '设置',
    header_sub: '移民官最多会问其中 20 道题，答对 12 题即通过。可免提听题、用抽认卡学习，再做模拟测试——一旦通过或失败立即结束，与真实面试相同。',
    no_tts: '当前浏览器没有所选语言的语音合成声音。语音支持因浏览器和设备而异——如需全部 11 种语言，请使用 Microsoft Edge 浏览器或 Civics Audio Prep 移动应用。',
    store_note: '朗读使用设备内置语音，语言覆盖因浏览器而异——Safari、Chrome 和 Firefox 可能缺少部分语言的语音。移动应用提供全部 11 种语言的清晰语音，支持离线使用和锁屏控制。',
    no_questions: '暂无题目',
    question_of: '第 {a} 题 / 共 {b} 题',
    known_count: '已掌握 {a}',
    app_title: '公民入籍听力备考',
    onboarding: '点击开始，把窗口放到一边，大声回答每道题。按一下空格键（或耳机按键）即可听答案或继续。随时看一眼屏幕：正在朗读的单词会高亮显示。',
    acceptable_answer: '可接受的答案',
    phase_speaking_question: '正在读题——按一下听答案',
    phase_thinking: '轮到你了——大声作答，然后按一下',
    phase_speaking_answer: '正在读答案',
    phase_awaiting_advance: '按一下进入下一题',
    phase_awaiting_grade: '答对了吗？',
    button_start: '开始听题',
    button_hear_answer: '听答案',
    button_next_question: '下一题',
    button_got_it: '答对了',
    button_missed_it: '答错了',
    previous_question: '上一题',
    stop: '停止',
    mark_known: '标记为已掌握',
    known_label: '已掌握',
    playing_suffix: ' · 播放中',
    questions_mark: '标记为已掌握',
    questions_unmark: '取消已掌握标记',
    answer_label: '答案',
    acceptable_answer_card: '可接受的答案',
    flip_reveal: '点击显示答案 ↻',
    flip_back: '点击看题目 ↻',
    flashcard_aria: '抽认卡，点击显示答案。',
    test_title: '模拟测试',
    test_rules: [
      '最多 20 道题，逐题作答。',
      '先看答案，再如实判断自己是否答对。',
      '答对 12 题即通过；答错 9 题测试结束——与真实面试相同。',
    ],
    test_start: '开始模拟测试',
    test_passed: '通过',
    test_failed: '未通过',
    test_verdict_pass: '你已答对 12 题——达到通过标准。',
    test_verdict_fail: '答错 9 题，测试结束。回到听题模式复习后再试。',
    test_again: '再测一次',
    test_back: '返回听题',
    test_history: '最近测试',
    correct_label: '答对', missed_label: '答错',
    settings_language: '语言', settings_voice: '语音', settings_playback: '播放', settings_deck: '题库', settings_progress: '进度',
    settings_ui_language: '界面语言', ui_system: '跟随系统',
    speech_rate: '语速：{a}×',
    announce_meta: '读出题号',
    think_pause: '显示答案前的停顿',
    think_wait: '手动继续', think_none: '不停顿', think_seconds: '{a} 秒',
    auto_advance: '答案结束后自动下一题',
    shuffle: '随机顺序',
    known_progress: '已掌握 {a} / 128 题',
    clear_known: '清除已掌握标记',
    cat_all: '全部 128 题', cat_gov: '美国政府', cat_hist: '美国历史', cat_sym: '象征与节日',
    filter_all: '全部', filter_known: '已掌握', filter_not_known: '未掌握',
    feat_no_ads: '无广告', feat_no_data: '不收集数据',
    feat_readalong: '逐词高亮', feat_open_source: '开源',
    store_eyebrow: 'iOS · MAC · ANDROID',
    store_heading: '下载移动应用',
    store_sub: '免提听题，支持锁屏控制与耳机按键——离线也能用。',
    store_download_on: '下载', store_get_it_on: '获取',
    store_coming_soon: '敬请期待', store_recommended: '推荐',
  },
  'zh-Hant': {
    tab_listen: '聽題', tab_cards: '抽認卡', tab_questions: '題庫', tab_test: '測試', tab_settings: '設定',
    header_sub: '移民官最多會問其中 20 道題，答對 12 題即通過。可免提聽題、用抽認卡學習，再做模擬測試——一旦通過或失敗立即結束，與真實面試相同。',
    no_tts: '此瀏覽器沒有所選語言的語音合成聲音。語音支援因瀏覽器與裝置而異——如需全部 11 種語言，請使用 Microsoft Edge 瀏覽器或 Civics Audio Prep 行動應用程式。',
    store_note: '朗讀使用裝置內建語音，語言覆蓋因瀏覽器而異——Safari、Chrome 和 Firefox 可能缺少部分語言的語音。行動應用程式提供全部 11 種語言的清晰語音，支援離線使用與鎖定畫面控制。',
    no_questions: '暫無題目',
    question_of: '第 {a} 題 / 共 {b} 題',
    known_count: '已掌握 {a}',
    app_title: '公民入籍聽力備考',
    onboarding: '點擊開始，把視窗放到一邊，大聲回答每道題。按一下空白鍵（或耳機按鍵）即可聽答案或繼續。隨時看一眼螢幕：正在朗讀的單字會醒目顯示。',
    acceptable_answer: '可接受的答案',
    phase_speaking_question: '正在讀題——按一下聽答案',
    phase_thinking: '輪到你了——大聲作答，然後按一下',
    phase_speaking_answer: '正在讀答案',
    phase_awaiting_advance: '按一下進入下一題',
    phase_awaiting_grade: '答對了嗎？',
    button_start: '開始聽題',
    button_hear_answer: '聽答案',
    button_next_question: '下一題',
    button_got_it: '答對了',
    button_missed_it: '答錯了',
    previous_question: '上一題',
    stop: '停止',
    mark_known: '標記為已掌握',
    known_label: '已掌握',
    playing_suffix: ' · 播放中',
    questions_mark: '標記為已掌握',
    questions_unmark: '取消已掌握標記',
    answer_label: '答案',
    acceptable_answer_card: '可接受的答案',
    flip_reveal: '點擊顯示答案 ↻',
    flip_back: '點擊看題目 ↻',
    flashcard_aria: '抽認卡，點擊顯示答案。',
    test_title: '模擬測試',
    test_rules: [
      '最多 20 道題，逐題作答。',
      '先看答案，再如實判斷自己是否答對。',
      '答對 12 題即通過；答錯 9 題測試結束——與真實面試相同。',
    ],
    test_start: '開始模擬測試',
    test_passed: '通過',
    test_failed: '未通過',
    test_verdict_pass: '你已答對 12 題——達到通過標準。',
    test_verdict_fail: '答錯 9 題，測試結束。回到聽題模式複習後再試。',
    test_again: '再測一次',
    test_back: '返回聽題',
    test_history: '最近測試',
    correct_label: '答對', missed_label: '答錯',
    settings_language: '語言', settings_voice: '語音', settings_playback: '播放', settings_deck: '題庫', settings_progress: '進度',
    settings_ui_language: '介面語言', ui_system: '跟隨系統',
    speech_rate: '語速：{a}×',
    announce_meta: '讀出題號',
    think_pause: '顯示答案前的停頓',
    think_wait: '手動繼續', think_none: '不停頓', think_seconds: '{a} 秒',
    auto_advance: '答案結束後自動下一題',
    shuffle: '隨機順序',
    known_progress: '已掌握 {a} / 128 題',
    clear_known: '清除已掌握標記',
    cat_all: '全部 128 題', cat_gov: '美國政府', cat_hist: '美國歷史', cat_sym: '象徵與節日',
    filter_all: '全部', filter_known: '已掌握', filter_not_known: '未掌握',
    feat_no_ads: '無廣告', feat_no_data: '不收集資料',
    feat_readalong: '逐字高亮', feat_open_source: '開源',
    store_eyebrow: 'iOS · MAC · ANDROID',
    store_heading: '下載行動應用程式',
    store_sub: '免提聽題，支援鎖定畫面控制與耳機按鍵——離線也能用。',
    store_download_on: '下載', store_get_it_on: '取得',
    store_coming_soon: '敬請期待', store_recommended: '推薦',
  },
};

/* ---------- language derivation (StudySettings.kt) ---------- */
export const spokenLanguage = () => settings.language === 'system' ? 'english' : settings.language;
export const bilingual = () => spokenLanguage() !== 'english';
export const translationPrimary = () => bilingual();
export function systemChrome() {
  const n = String(navigator.language || 'en').toLowerCase();
  if (n.startsWith('es')) return 'es';
  if (n.indexOf('hans') !== -1) return 'zh-Hans';
  if (n.indexOf('hant') !== -1 || n === 'zh-tw' || n === 'zh-hk' || n === 'zh-mo') return 'zh-Hant';
  if (n.startsWith('zh')) return 'zh-Hans';
  return 'en';
}
export function chromeLang() {
  const l = settings.language;
  if (l === 'system') return systemChrome();
  if (l === 'english') return 'en';
  if (l === 'es' || l === 'zh-Hans' || l === 'zh-Hant') return l;
  return 'en';
}
export function t(key, a, b) {
  let s = (CHROME[chromeLang()] || CHROME.en)[key];
  if (s == null) s = CHROME.en[key];
  if (a !== undefined) s = s.replace('{a}', a);
  if (b !== undefined) s = s.replace('{b}', b);
  return s;
}
export function catLabel(cat) {
  switch (cat) {
    case 'All': return t('cat_all');
    case 'American Government': return t('cat_gov');
    case 'American History': return t('cat_hist');
    case 'Symbols & Holidays': return t('cat_sym');
    default: return cat;
  }
}
export function translationFor(q, lang) {
  return (lang && lang !== 'english' && q.translations) ? (q.translations[lang] || null) : null;
}
/* Display pair: when bilingual, translation is primary with English muted below. */
export function displayPair(english, translated) {
  if (translationPrimary() && translated != null) return { primary: translated, secondary: english };
  return { primary: english, secondary: translationPrimary() ? null : translated };
}
