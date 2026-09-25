// POLER WebLens v2.0 — content script: Universal AI & Cloud Harvester.
//
// ЧАСТЬ A (легаси, v0.19): подсветка термов поиска POLER на любой странице.
// ЧАСТЬ B (новое, v2.0):  комбайн — детекция платформы → авто-скролл
//   виртуализированного DOM (двухфазный sweep: вверх = подгрузка истории,
//   вниз = докрутка ответов) → сбор ветки → чистка UI-мусора (кнопки
//   Copy/Retry, иконки, аватары) → реставрация LaTeX (KaTeX/MathJax) →
//   сборка чистого Markdown (CoT-блоки в <thinking>…</thinking>) →
//   отправка через background в MCP-шлюз poler-engine (poler_chunk).
//
// Поддерживаемые платформы: Grok (x.com), ChatGPT, Claude, Gemini,
//   DeepSeek-R1, NotebookLM, Google Drive (папки + Docs), OneDrive.
// Горячая клавиша: Alt+P → background → {type:'poler:harvest-run'}.
//
// Инженерное правило: DOM чатов волатилен (hashed-классы меняются от
// релиза к релизу) — все конфиги селекторов многослойные (кандидаты
// перебираются до первого непустого), а последним рубежом работает
// универсальный bubble-движок. Использованная стратегия сообщается
// в отчёте захвата.

(() => {
  'use strict';

  if (window.__WEBLENS_CONTENT__) return; // защита от повторной инъекции
  window.__WEBLENS_CONTENT__ = true;

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  /* ====================== ЧАСТЬ A: ПОДСВЕТКА (легаси) ====================== */

  const HL_CLASS = 'poler-hl';
  const MAX_HIGHLIGHTS = 500;

  let styleEl = null;
  let marks = [];

  function ensureStyle() {
    if (styleEl) return;
    styleEl = document.createElement('style');
    styleEl.textContent =
      '.' + HL_CLASS + '{background:#22d3ee55;outline:1px solid #22d3ee88;' +
      'border-radius:2px;color:inherit;}' +
      '.' + HL_CLASS + '::selection{background:#e83e8c66;}';
    document.documentElement.appendChild(styleEl);
  }

  function clearHighlights() {
    for (const mark of marks) {
      if (!mark.parentNode) continue;
      const parent = mark.parentNode;
      while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
      mark.remove();
    }
    marks = [];
    if (document.body) document.body.normalize();
  }

  function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function visibleNode(node) {
    const el = node.parentElement;
    if (!el) return false;
    const st = getComputedStyle(el);
    if (st.display === 'none' || st.visibility === 'hidden' || +st.opacity === 0) {
      return false;
    }
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  }

  function highlightTerms(terms) {
    clearHighlights();
    if (!terms || !terms.length || !document.body) return 0;
    ensureStyle();
    const pattern = terms
      .slice(0, 20)
      .map(escapeRe)
      .sort((a, b) => b.length - a.length)
      .join('|');
    let re;
    try {
      re = new RegExp('(?<![\\p{L}\\p{N}])(' + pattern + ')(?![\\p{L}\\p{N}])', 'giu');
    } catch (_) {
      re = new RegExp('\\b(' + pattern + ')\\b', 'gi');
    }

    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode(node) {
          if (!node.nodeValue || node.nodeValue.trim().length < 2) {
            return NodeFilter.FILTER_REJECT;
          }
          const name = node.parentElement ? node.parentElement.tagName : '';
          if (name === 'SCRIPT' || name === 'STYLE' || name === 'NOSCRIPT' ||
              name === 'TEXTAREA' || name === 'INPUT') {
            return NodeFilter.FILTER_REJECT;
          }
          if (node.parentElement && node.parentElement.closest('.' + HL_CLASS)) {
            return NodeFilter.FILTER_REJECT;
          }
          return re.test(node.nodeValue)
            ? NodeFilter.FILTER_ACCEPT
            : NodeFilter.FILTER_REJECT;
        },
      }
    );

    let count = 0;
    let node;
    while ((node = walker.nextNode()) && count < MAX_HIGHLIGHTS) {
      if (!visibleNode(node)) continue;
      const text = node.nodeValue;
      re.lastIndex = 0;
      const frag = document.createDocumentFragment();
      let last = 0;
      let m;
      while ((m = re.exec(text)) !== null) {
        if (m.index > last) frag.appendChild(document.createTextNode(text.slice(last, m.index)));
        const mark = document.createElement('mark');
        mark.className = HL_CLASS;
        mark.textContent = m[0];
        frag.appendChild(mark);
        marks.push(mark);
        last = m.index + m[0].length;
        count++;
        if (count >= MAX_HIGHLIGHTS) break;
      }
      if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
      if (frag.childNodes.length) {
        node.parentNode.replaceChild(frag, node);
      }
    }
    return count;
  }

  /* ==================== ЧАСТЬ B: КОМБАЙН (HARVESTER) ====================== */

  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));

  /* ---------- 1. Реестр платформ (детекция по hostname) ---------- */

  const PLATFORMS = [
    { id: 'grok',       source: 'grok',       label: 'Grok (X)',      kind: 'chat',  host: /^([a-z0-9-]+\.)?(x\.com|twitter\.com)$/, path: /\/(i\/)?grok/ },
    { id: 'chatgpt',    source: 'chatgpt',    label: 'ChatGPT',       kind: 'chat',  host: /^(chatgpt\.com|chat\.openai\.com)$/ },
    { id: 'claude',     source: 'claude',     label: 'Claude',        kind: 'chat',  host: /^claude\.ai$/ },
    { id: 'gemini',     source: 'gemini',     label: 'Gemini',        kind: 'chat',  host: /^gemini\.google\.com$/ },
    { id: 'deepseek',   source: 'deepseek',   label: 'DeepSeek (R1)', kind: 'chat',  host: /^chat\.deepseek\.com$/ },
    { id: 'notebooklm', source: 'notebooklm', label: 'NotebookLM',    kind: 'notes', host: /^notebooklm\.google\.com$/ },
    { id: 'gdrive',     source: 'gdrive',     label: 'Google Drive',  kind: 'drive', host: /^(drive|docs)\.google\.com$/ },
    { id: 'onedrive',   source: 'onedrive',   label: 'OneDrive',      kind: 'drive', host: /(^([a-z0-9-]+\.)?onedrive\.live\.com$)|(\.microsoftpersonalcontent\.com$)/ }
  ];

  function detectPlatform() {
    const h = location.hostname.toLowerCase();
    for (const p of PLATFORMS) {
      if (!p.host.test(h)) continue;
      if (p.path && !p.path.test(location.pathname)) continue;
      return p;
    }
    return null;
  }

  const platform = detectPlatform();

  /* ---------- 2. Конфиги селекторов платформ (многослойные) ----------
   * turns:      кандидаты контейнеров сообщений (до первого непустого);
   * role(el):   'user' | 'assistant';
   * thinking:   селекторы блоков размышлений (CoT) → <thinking>…</thinking>;
   * artifacts:  селекторы артефактов Claude → отдельные секции Markdown;
   * drafts:     черновики Gemini (Draft 1..3);
   * citations:  цитаты поиска Gemini. */

  const CONF = {
    chatgpt: {
      turns: ['div[data-testid="conversation-turn"]', '[data-message-id]'],
      role: (el) => {
        const r = el.querySelector('[data-message-author-role]');
        if (r) return r.getAttribute('data-message-author-role') === 'user' ? 'user' : 'assistant';
        return el.querySelector('.whitespace-pre-wrap, .markdown') ? 'assistant' : 'user';
      },
      thinking: []
    },
    claude: {
      turns: ['[data-testid="user-message"]', 'div.font-claude-message',
              '[data-testid="assistant-message"]', 'div[data-is="reply"]'],
      role: (el) => {
        const marker = String(el.className) + ' ' + String(el.getAttribute('data-is') || '');
        return el.matches('[data-testid="user-message"]') || /(^|[\s_-])(user|human)/i.test(marker)
          ? 'user' : 'assistant';
      },
      thinking: [],
      artifacts: ['[data-testid="artifact-container"]', '[class*="artifact" i]']
    },
    gemini: {
      turns: ['user-query', '.user-query-prompt', '.model-response-text',
              '.response-container-content', '.markdown-main-panel'],
      role: (el) => (/user/i.test(String(el.className)) ? 'user' : 'assistant'),
      thinking: [],
      drafts: ['[data-test-id="draft-content"]', '.draft-content', '[class*="draft" i]'],
      citations: ['[data-test-id="citation"]', '.citation']
    },
    deepseek: {
      turns: ['.ds-markdown--container', '[class*="chat-message" i]',
              '[class*="message-item" i]', '[class*="message" i]'],
      role: (el) => (el.classList.contains('ds-markdown--container') ||
                     el.querySelector('.ds-markdown, pre, code')) ? 'assistant' : 'user',
      thinking: ['.ds-think-content', '[class*="think-content" i]',
                 '[class*="thinking" i]', '[class*="reasoning" i]']
    },
    grok: {
      turns: ['[data-testid="conversation-turn"]', '[class*="message" i]',
              '[class*="response" i]', '[class*="conversation" i] > div'],
      role: (el) => (el.querySelector('[class*="markdown" i], pre, code, table')) ? 'assistant' : 'user',
      thinking: ['[class*="reasoning" i]', '[class*="thought" i]', '[class*="think" i]']
    }
  };

  /* ---------- 3. Чистка UI-мусора ----------
   * innerText игнорирует svg/img (иконки/аватары); тексты кнопок
   * («Copy code», «Retry», «Good response»…) вычищаются построчно. */

  const NOISE_LINE = [
    /^\s*(copy|copy code|копировать( код)?|скопировать( код)?)\s*$/i,
    /^\s*(retry|try again|regenerate|повторить|перегенерировать)\s*$/i,
    /^\s*(edit|редактировать)\s*$/i,
    /^\s*(good response|bad response|report)\s*$/i,
    /^\s*(like|dislike|лайк|дизлайк)\s*$/i,
    /^\s*(show thinking|hide thinking|показать размышления|скрыть размышления)\s*$/i,
    /^\s*(share|поделиться|отправить|share response)\s*$/i,
    /^\s*\d+\s*(копир|copy)/i
  ];

  function scrub(text) {
    return String(text || '')
      .split('\n')
      .map((l) => l.replace(/[ \t]+$/g, ''))
      .filter((l) => !NOISE_LINE.some((rx) => rx.test(l)))
      .join('\n');
  }

  /* ---------- 4. Реставрация LaTeX ----------
   * KaTeX хранит исходный TeX в <annotation encoding="application/x-tex">;
   * MathJax — в script[type="math/tex"] / атрибутах контейнера. */

  function restoreLatex(root) {
    root.querySelectorAll('.katex').forEach((k) => {
      const ann = k.querySelector('annotation[encoding="application/x-tex"]');
      if (ann && ann.textContent.trim()) {
        k.replaceWith(document.createTextNode('$' + ann.textContent.trim() + '$'));
      }
    });
    root.querySelectorAll('script[type="math/tex"]').forEach((s) => {
      const span = document.createElement('span');
      span.textContent = '$' + s.textContent.trim() + '$';
      s.replaceWith(span);
    });
    root.querySelectorAll('mjx-container, .MathJax').forEach((m) => {
      const tex = m.getAttribute('data-latex') || m.getAttribute('alttext') ||
        (m.previousElementSibling && m.previousElementSibling.matches('script[type="math/tex"]')
          ? m.previousElementSibling.textContent : '');
      if (tex && tex.trim()) {
        const span = document.createElement('span');
        span.textContent = '$' + tex.trim() + '$';
        m.replaceWith(span);
      }
    });
  }

  /* ---------- 5. DOM-элемент → Markdown-поворот ----------
   * pre → ```-заборы (язык из class="language-*");
   * CoT-блоки → выносятся в <thinking>…</thinking>;
   * артефакты Claude → секция «🧩 Artifact»;
   * iframe (Canvas/песочницы) → пометка (их DOM недоступен). */

  function turnToMarkdown(turnEl, conf) {
    const opts = conf || {};
    const clone = turnEl.cloneNode(true);
    restoreLatex(clone);

    clone.querySelectorAll('iframe').forEach((f) => {
      const note = document.createElement('span');
      note.textContent = '\n> ⚙ Встроенный блок (iframe): ' + (f.src || 'sandbox') + '\n';
      f.replaceWith(note);
    });

    let thinking = '';
    if (opts.thinking && opts.thinking.length) {
      const parts = [];
      for (const sel of opts.thinking) {
        $$(sel, clone).forEach((el) => {
          const t = scrub(el.innerText || '');
          if (t.trim()) parts.push(t.trim());
          el.remove();
        });
      }
      thinking = parts.join('\n\n');
    }

    const artifacts = [];
    if (opts.artifacts && opts.artifacts.length) {
      for (const sel of opts.artifacts) {
        $$(sel, clone).forEach((el) => {
          const t = el.querySelector('h1,h2,h3,h4,[class*="title" i]');
          const title = ((t && t.innerText) || 'artifact').trim();
          const body = scrub(el.innerText || '').trim();
          if (body) artifacts.push({ title, body });
          el.remove();
        });
      }
    }

    const fences = [];
    clone.querySelectorAll('pre').forEach((pre) => {
      const code = pre.querySelector('code');
      const lang = code ? ((code.className.match(/language-([\w+#.-]+)/) || [])[1] || '') : '';
      const raw = (code || pre).innerText || (code || pre).textContent || '';
      fences.push('```' + lang + '\n' + raw.replace(/\s+$/, '') + '\n```');
      const ph = document.createElement('span');
      ph.textContent = '@@WL-FENCE-' + (fences.length - 1) + '@@';
      pre.replaceWith(ph);
    });

    let text = scrub(clone.innerText || clone.textContent || '');
    text = text.replace(/@@WL-FENCE-(\d+)@@/g, (m, i) => '\n' + fences[Number(i)] + '\n');
    artifacts.forEach((a) => {
      text += '\n\n#### 🧩 Artifact: ' + a.title + '\n\n```\n' + a.body + '\n```';
    });
    text = text.replace(/\n{3,}/g, '\n\n').trim();
    return { text, thinking };
  }

  /* ---------- 6. Сопоставление сообщений + универсальный bubble-движок ---------- */

  function isVisible(el) {
    if (!el || !el.getBoundingClientRect) return false;
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    const st = getComputedStyle(el);
    return st.visibility !== 'hidden' && st.display !== 'none';
  }

  function genericBubbles() {
    const sels = ['.message', '.msg', '[class*="message" i]', '[class*="turn" i]',
                  '[class*="bubble" i]', '[class*="prompt" i]',
                  '[class*="response" i]', '[class*="query" i]'];
    let best = [];
    for (const sel of sels) {
      const found = $$(sel).filter((el) => isVisible(el) && (el.innerText || '').trim().length > 0);
      if (found.length > best.length) best = found;
    }
    return best;
  }

  function matchTurns() {
    const conf = CONF[platform.id] || {};
    let els = [];
    let strategy = 'generic-bubble-engine';
    if (conf.turns) {
      for (const sel of conf.turns) {
        const found = $$(sel).filter(isVisible);
        if (found.length) { els = found; strategy = sel; break; }
      }
    }
    if (els.length < 2) els = genericBubbles();
    // «листья»: контейнер и потомок не должны попасть в выдачу дважды
    els = els.filter((el) => !els.some((o) => o !== el && el.contains(o)));
    return { els, strategy, conf };
  }

  function elToTurn(el, conf) {
    let role = 'assistant';
    if (conf && conf.role) {
      role = conf.role(el);
    } else {
      role = /user|self|query|prompt/i.test(String(el.className) + ' ' + String(el.id))
        ? 'user' : 'assistant';
    }
    const t = turnToMarkdown(el, conf);
    const text = (t.text || '').trim();
    if (!text && !t.thinking) return null;
    return { role: role === 'user' ? 'user' : 'assistant', text, thinking: t.thinking };
  }

  /* ---------- 7. Двухфазный sweep: авто-скролл виртуализированного DOM ----------
   * Фаза 1 — прокрутка ВВЕРХ до упора (подгрузка истории в ленивых чатах);
   * фаза 2 — прокрутка ВНИЗ (докрутка поздних ответов/блоков).
   * На каждом шаге собираются только НОВЫЕ DOM-узлы (WeakSet): устойчивые
   * сообщения обрабатываются один раз, виртуализированные (выгружаемые
   * из DOM) — фиксируются в момент видимости. Дедуп — по ключу роли+
   * первых 80 символов текста. Вверх — новые (старейшие) в начало,
   * вниз — новые в конец: хронология восстанавливается аппроксимацией. */

  const SCROLL = { maxSteps: 160, stepDelay: 280, stallLimit: 4 };

  function scrollRoot() {
    const doc = document.scrollingElement || document.documentElement;
    if (doc.scrollHeight > window.innerHeight + 50) return null; // страничный скролл
    const cands = $$('[role="log"], main, [class*="conversation" i], [class*="chat" i], [class*="scroll" i]');
    let best = null;
    let bestOver = 0;
    for (const el of cands) {
      const st = getComputedStyle(el);
      if (!/(auto|scroll)/.test(st.overflowY)) continue;
      const over = el.scrollHeight - el.clientHeight;
      if (over > bestOver) { bestOver = over; best = el; }
    }
    return best;
  }

  async function sweepStep(root, dir) {
    if (root) {
      root.scrollTop = dir === 'top' ? 0 : root.scrollHeight;
    } else {
      window.scrollTo(0, dir === 'top' ? 0 : document.documentElement.scrollHeight);
    }
    await sleep(SCROLL.stepDelay);
  }

  function docHeight(root) {
    return root ? root.scrollHeight : document.documentElement.scrollHeight;
  }

  async function sweepAndCollect() {
    const root = scrollRoot();
    const y0 = root ? root.scrollTop : window.scrollY;
    const seenEls = new WeakSet();
    const seenKeys = new Set();
    const list = [];
    let strategy = '';

    function harvestNew(where) {
      const { els, strategy: strat } = matchTurns();
      if (!strategy && strat) strategy = strat;
      for (const el of els) {
        if (seenEls.has(el)) continue;
        seenEls.add(el);
        const turn = elToTurn(el, CONF[platform.id]);
        if (!turn) continue;
        const key = turn.role + '::' + String(turn.text || '')
          .replace(/\s+/g, ' ').slice(0, 80);
        if (seenKeys.has(key)) continue;
        seenKeys.add(key);
        if (where === 'front') list.unshift(turn); else list.push(turn);
      }
    }

    harvestNew('back');

    let lastH = -1;
    let stall = 0;
    for (let i = 0; i < SCROLL.maxSteps; i++) { // фаза 1: вверх — история
      await sweepStep(root, 'top');
      harvestNew('front');
      const h = docHeight(root);
      if (h === lastH) { if (++stall >= SCROLL.stallLimit) break; } else stall = 0;
      lastH = h;
    }

    stall = 0;
    lastH = -1;
    for (let i = 0; i < SCROLL.maxSteps; i++) { // фаза 2: вниз — хвосты
      await sweepStep(root, 'bottom');
      harvestNew('back');
      const h = docHeight(root);
      if (h === lastH) { if (++stall >= SCROLL.stallLimit) break; } else stall = 0;
      lastH = h;
    }

    if (root) root.scrollTop = y0; else window.scrollTo(0, y0); // вернуть как было
    return { turns: list, strategy };
  }

  /* ---------- 8. Экстры: черновики и цитаты Gemini ---------- */

  function collectExtras() {
    const conf = CONF[platform.id] || {};
    const extras = {};
    if (conf.drafts) {
      const ds = [];
      for (const sel of conf.drafts) {
        $$(sel).forEach((el) => {
          const t = scrub(el.innerText || '').trim();
          if (t) ds.push(t);
        });
      }
      if (ds.length) extras.drafts = ds;
    }
    if (conf.citations) {
      const cs = [];
      for (const sel of conf.citations) {
        $$(sel).forEach((el) => {
          const a = el.tagName === 'A' ? el : el.querySelector('a');
          const href = a ? a.href : '';
          const txt = scrub(el.innerText || '').replace(/\s+/g, ' ').trim();
          if (txt || href) cs.push((txt || '(без названия)') + (href ? ' — ' + href : ''));
        });
      }
      if (cs.length) extras.citations = Array.from(new Set(cs));
    }
    return extras;
  }

  /* ---------- 9. Заголовок и сборка Markdown ---------- */

  function pageTitle() {
    const raw = (document.title || '').trim() || location.href;
    const cleaned = raw.replace(
      /\s*[·|—-]\s*(ChatGPT|Claude|Gemini|DeepSeek|Grok|X(\s\(formerly\sTwitter\))?|Google Drive|Docs|OneDrive|NotebookLM)\s*$/i,
      ''
    ).trim();
    return cleaned || raw;
  }

  function mdHeader(strategy) {
    return [
      '> **WebLens Harvest** — источник: `' + platform.source + '` (' + platform.label + ')',
      '> URL: ' + location.href,
      '> Захват: ' + new Date().toISOString() +
        (strategy ? ' · стратегия DOM: ' + strategy : '')
    ];
  }

  function buildChatMarkdown(turns, strategy) {
    const L = ['# ' + pageTitle(), ''].concat(mdHeader(strategy));
    L.push('', '---', '');
    turns.forEach((t) => {
      L.push('## ' + (t.role === 'user' ? '👤 User' : '🤖 Assistant'), '');
      if (t.thinking) {
        L.push('<thinking>', t.thinking.trim(), '</thinking>', '');
      }
      L.push(t.text.trim(), '', '---', '');
    });
    const extras = collectExtras();
    if (extras.drafts) {
      L.push('### ✏️ Альтернативные черновики (Drafts)', '');
      extras.drafts.forEach((d, i) => { L.push('**Draft ' + (i + 1) + ':**\n\n' + d, ''); });
      L.push('---', '');
    }
    if (extras.citations) {
      L.push('### 🔗 Цитаты поиска', '');
      extras.citations.forEach((c) => L.push('- ' + c));
      L.push('');
    }
    return L.join('\n').replace(/\n{4,}/g, '\n\n\n').trim() + '\n';
  }

  /* ---------- 10. Облака: Google Drive / Docs / OneDrive ---------- */

  function harvestGoogleDoc() {
    const ed = $('.kix-appleditor') || $('[role="textbox"][aria-label]');
    const body = ed ? scrub(ed.innerText || '') : '';
    return {
      kind: body ? 'google-doc (kix)' : 'gdrive-page (документ не распознан)',
      title: pageTitle(),
      body: body.trim()
    };
  }

  async function fetchGoogleFileContent(id, name) {
    if (!id || id.length < 5) return null;
    const endpoints = [
      `https://docs.google.com/document/d/${id}/export?format=txt`,
      `https://docs.google.com/spreadsheets/d/${id}/export?format=csv`,
      `https://docs.google.com/presentation/d/${id}/export?format=txt`,
      `https://drive.google.com/uc?id=${id}&export=download`,
      `https://drive.usercontent.google.com/download?id=${id}&export=download&authuser=0`
    ];
    for (const url of endpoints) {
      try {
        const res = await fetch(url, { credentials: 'include' });
        if (!res.ok) continue;
        const contentType = res.headers.get('content-type') || '';
        if (contentType.includes('text/html') && !url.includes('docs.google.com')) {
          // HTML-страница подтверждения или логина вместо файла — пропускаем
          continue;
        }
        const text = await res.text();
        if (text && text.trim().length > 0 && !text.includes('<!DOCTYPE html>')) {
          return { url, text };
        }
      } catch (_) {
        // Ошибка сети или CORS — пробуем следующий эндпоинт
      }
    }
    return null;
  }

  async function harvestDriveOrOneDrive() {
    const isOne = platform.id === 'onedrive';
    const items = [];
    const seenIds = new Set();
    const seenNames = new Set();

    // Автоматический скролл до самого низа для подгрузки всех файлов виртуализированного списка
    toast('⏳ Авто-прокрутка папки до конца для подгрузки всех файлов…');
    const scrollContainer = $('[role="main"], [data-target="doc"], .drive-list-container, c-wiz, div[tabindex="-1"]') || window;
    let prevCount = 0;
    let stableTicks = 0;
    for (let s = 0; s < 35; s++) {
      if (scrollContainer && scrollContainer.scrollTo) {
        scrollContainer.scrollTo(0, scrollContainer.scrollHeight || 9999999);
      }
      window.scrollTo(0, document.body.scrollHeight || 9999999);
      await new Promise((r) => setTimeout(r, 350));
      
      const currentEls = $$('[data-id], [role="row"], [data-target="doc"]');
      if (currentEls.length === prevCount && currentEls.length > 0) {
        stableTicks++;
        if (stableTicks >= 3) break; // список полностью загружен
      } else {
        stableTicks = 0;
        prevCount = currentEls.length;
      }
    }

    // Поиск элементов с ID и ссылками
    const sels = isOne
      ? ['[role="row"][aria-label]', '[data-listindex][aria-label]', '[role="gridcell"] [aria-label]']
      : ['[data-id]', '[data-target="doc"]', 'c-wiz[data-item-id]', '[role="row"]', 'a[href*="/file/d/"]', 'a[href*="/drive/folders/"]'];

    for (const sel of sels) {
      $$(sel).forEach((el) => {
        let id = el.getAttribute('data-id') || el.getAttribute('data-item-id') || '';
        if (!id) {
          const href = el.getAttribute('href') || (el.querySelector('a') && el.querySelector('a').getAttribute('href')) || '';
          const m = href.match(/\/d\/([a-zA-Z0-9_-]+)/) || href.match(/id=([a-zA-Z0-9_-]+)/);
          if (m) id = m[1];
        }
        const name = (el.getAttribute('aria-label') || el.getAttribute('data-tooltip') ||
          String(el.innerText || '').split('\n')[0] || '').trim();
        
        if (id && !seenIds.has(id)) {
          seenIds.add(id);
          items.push({ id, name: name || ('file_' + id) });
        } else if (name && !seenNames.has(name)) {
          seenNames.add(name);
          items.push({ id: '', name });
        }
      });
    }

    let preview = '';
    const pv = $('.drive-viewer-text, [role="document"]');
    if (pv) preview = scrub(pv.innerText || '').trim();

    // Прямая выкачка файлов сессии
    let downloadedCount = 0;
    const fetchedFiles = [];
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      if (it.id) {
        toast(`⏳ Сессионная загрузка [${i + 1}/${items.length}]: ${it.name.slice(0, 30)}...`);
        const fetched = await fetchGoogleFileContent(it.id, it.name);
        if (fetched && fetched.text) {
          downloadedCount++;
          fetchedFiles.push({ name: it.name, id: it.id, text: fetched.text });
          // Стримим файл прямо в poler-engine
          await chrome.runtime.sendMessage({
            type: 'poler:harvest',
            payload: {
              source: 'gdrive-file',
              title: it.name,
              url: `https://drive.google.com/file/d/${it.id}/view`,
              content: `# 📄 ${it.name}\n\nURL: https://drive.google.com/file/d/${it.id}/view\n\n---\n\n${fetched.text}`
            }
          }).catch(() => {});
        }
      }
    }

    return {
      kind: isOne ? 'onedrive-folder' : 'gdrive-folder',
      title: pageTitle(),
      items,
      downloadedCount,
      fetchedFiles,
      preview
    };
  }

  function buildDriveMarkdown(r) {
    const L = ['# ' + (r.title || 'Облако'), ''].concat(mdHeader(r.kind));
    L.push('', '---', '');
    if (r.body) {
      L.push(r.body.trim());
    } else if (r.items && r.items.length) {
      L.push('## 📁 Состав папки (' + r.items.length + ' объектов, загружено напрямую: ' + (r.downloadedCount || 0) + ')', '');
      r.items.forEach((it) => {
        const status = it.id ? ' [ID: `' + it.id + '`]' : '';
        L.push('- ' + it.name + status);
      });
      L.push('');
      if (r.downloadedCount > 0) {
        L.push(`> ✅ Успешно извлечено и отправлено в архив ${r.downloadedCount} файлов через сессию браузера.`);
      }
    } else {
      L.push('_Папка/документ не распознаны — захват дал пустой результат._');
    }
    if (r.preview) {
      L.push('', '## 👁 Доступный предпросмотр', '', r.preview);
    }
    return L.join('\n').replace(/\n{4,}/g, '\n\n\n').trim() + '\n';
  }

  /* ---------- 11. NotebookLM: Studio Notes + история чата ---------- */

  async function harvestNotebookLM() {
    const r = await sweepAndCollect(); // чат — универсальным движком
    const notes = [];
    const seen = new Set();
    $$('[data-test-id*="note" i], [class*="note-item" i], [class*="studio-note" i]')
      .forEach((el) => {
        const t = scrub(el.innerText || '').trim();
        const key = t.replace(/\s+/g, ' ').slice(0, 80);
        if (t && !seen.has(key)) { seen.add(key); notes.push(t); }
      });
    const L = ['# ' + pageTitle(), ''].concat(mdHeader(r.strategy));
    L.push('', '---', '');
    if (notes.length) {
      L.push('## 📝 Studio Notes', '');
      notes.forEach((n, i) => { L.push('**Note ' + (i + 1) + ':**\n\n' + n, ''); });
      L.push('---', '');
    }
    if (r.turns.length) {
      L.push('## 💬 История чата', '');
      r.turns.forEach((t) => {
        L.push('### ' + (t.role === 'user' ? '👤 User' : '🤖 Assistant'), '');
        if (t.thinking) { L.push('<thinking>', t.thinking.trim(), '</thinking>', ''); }
        L.push(t.text.trim(), '');
      });
    }
    if (!notes.length && !r.turns.length) {
      L.push('_Заметки и чат не найдены — откройте ноутбук полностью._');
    }
    return { md: L.join('\n').replace(/\n{4,}/g, '\n\n\n').trim() + '\n', strategy: r.strategy };
  }

  /* ---------- 12. Плавающая кнопка (Shadow DOM, изоляция стилей) ---------- */

  function buttonLabel() {
    if (!platform) return '';
    if (platform.kind === 'drive') return '📥 Собрать папку в POLER';
    if (platform.id === 'notebooklm') return '📥 Собрать NotebookLM в POLER';
    return '📥 Захватить ветку в POLER';
  }

  function mountFloatButton() {
    if (!platform) return; // неподдерживаемый сайт — не мешаем
    if ($('weblens-float-host')) return;
    const host = document.createElement('div');
    host.id = 'weblens-float-host';
    host.style.cssText = 'position:fixed;top:14px;right:14px;z-index:2147483647;';
    const sh = host.attachShadow({ mode: 'open' });
    sh.innerHTML = [
      '<style>',
      '#btn{font:600 13px/1.25 system-ui,-apple-system,"Segoe UI",sans-serif;',
      '  background:linear-gradient(135deg,#0f172a,#1e293b);color:#e2e8f0;',
      '  border:1px solid #38bdf8;border-radius:10px;padding:10px 14px;',
      '  cursor:pointer;opacity:.55;transition:all .2s;',
      '  box-shadow:0 4px 18px rgba(2,6,23,.45);}',
      '#btn:hover{opacity:1;transform:translateY(-1px);}',
      '#btn.busy{border-color:#f59e0b;color:#fde68a;}',
      '#toast{font:12px/1.4 system-ui,sans-serif;color:#e2e8f0;max-width:340px;',
      '  background:#0f172aee;border:1px solid #38bdf8;border-radius:10px;',
      '  padding:8px 12px;margin-top:6px;box-shadow:0 4px 18px rgba(2,6,23,.5);',
      '  white-space:pre-wrap;}',
      '</style>',
      '<button id="btn">' + buttonLabel() + '</button>',
      '<div id="toast" hidden></div>'
    ].join('\n');
    sh.getElementById('btn').addEventListener('click', () => { void harvest(); });
    document.documentElement.appendChild(host);
    window.__WL_UI = {
      btn: sh.getElementById('btn'),
      toast: sh.getElementById('toast')
    };
  }

  function setButton(txt) {
    const b = window.__WL_UI && window.__WL_UI.btn;
    if (!b) return '';
    const old = b.textContent;
    b.textContent = txt;
    b.classList.toggle('busy', /^⏳/.test(txt));
    return old;
  }

  function toast(msg) {
    const ui = window.__WL_UI;
    if (!ui || !ui.toast) return;
    ui.toast.textContent = msg;
    ui.toast.hidden = false;
    clearTimeout(window.__WL_TOAST_TIMER);
    window.__WL_TOAST_TIMER = setTimeout(() => { ui.toast.hidden = true; }, 6000);
  }

  /* ---------- 13. Оркестратор: сбор → Markdown → шлюз ---------- */

  let busy = false;

  async function sendToPoler(md) {
    return chrome.runtime.sendMessage({
      type: 'poler:harvest',
      payload: { source: platform.source, title: pageTitle(), url: location.href, content: md }
    });
  }

  async function harvest() {
    if (busy) return { ok: false, error: 'сбор уже выполняется' };
    if (!platform) {
      return { ok: false, error: 'платформа не опознана: ' + location.hostname };
    }
    busy = true;
    setButton('⏳ Сбор и авто-скролл…');
    const t0 = Date.now();
    try {
      let md = '';
      let strategy = '';
      if (platform.kind === 'chat') {
        const r = await sweepAndCollect();
        if (!r.turns.length) {
          return { ok: false, error: 'сообщения не найдены — DOM платформы изменился, обновите конфиг селекторов' };
        }
        md = buildChatMarkdown(r.turns, r.strategy);
        strategy = r.strategy;
      } else if (platform.kind === 'drive') {
        const r = /docs\.google\.com$/.test(location.hostname)
          ? harvestGoogleDoc()
          : harvestDriveOrOneDrive();
        md = buildDriveMarkdown(r);
        strategy = r.kind;
      } else { // notes: NotebookLM
        const r = await harvestNotebookLM();
        md = r.md;
        strategy = r.strategy;
      }

      const send = await sendToPoler(md);
      const chars = md.length;
      const secs = ((Date.now() - t0) / 1000).toFixed(1);
      if (send && send.ok) {
        toast('✅ В POLER: ' + chars + ' симв. за ' + secs + ' с');
        setButton(buttonLabel());
        return { ok: true, chars, strategy };
      }
      const err = (send && (send.error || 'HTTP ' + send.status)) || 'шлюз poler-engine недоступен';
      toast('❌ ' + err + '\n(запущен ли poler-engine --web-lens ?)');
      setButton(buttonLabel());
      return { ok: false, error: err };
    } catch (e) {
      setButton(buttonLabel());
      return { ok: false, error: String((e && e.message) || e) };
    } finally {
      busy = false;
    }
  }


  /* ======================= РЕЕСТР СООБЩЕНИЙ + INIT ========================= */

  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (!msg) return;
    if (msg.type === 'poler:highlight') {
      sendResponse({ count: highlightTerms(msg.terms || []) });
    } else if (msg.type === 'poler:clear') {
      clearHighlights();
      sendResponse({ ok: true });
    } else if (msg.type === 'poler:harvest-run') {
      harvest().then((r) => sendResponse(r || { ok: false, error: 'пустой ответ' }));
      return true; // async
    } else if (msg.type === 'poler:harvest-info') {
      sendResponse(platform
        ? { ok: true, id: platform.id, source: platform.source, label: platform.label, kind: platform.kind }
        : { ok: false, label: location.hostname });
    }
  });

  /* ==================== АВТО-КОПИРОВАНИЕ ПРИ ПРАВОМ КЛИКЕ ==================== */
  document.addEventListener('contextmenu', (e) => {
    try {
      const sel = window.getSelection();
      const txt = sel ? String(sel.toString() || '').trim() : '';
      if (txt && txt.length > 0) {
        navigator.clipboard.writeText(txt).then(() => {
          toast(`📋 Скопировано в буфер (${txt.length} симв.)`);
        }).catch(() => {
          const ta = document.createElement('textarea');
          ta.value = txt;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          ta.style.left = '-9999px';
          document.body.appendChild(ta);
          ta.select();
          document.execCommand('copy');
          document.body.removeChild(ta);
          toast(`📋 Скопировано в буфер (${txt.length} симв.)`);
        });
      }
    } catch (_) {}
  }, true);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mountFloatButton);
  } else {
    mountFloatButton();
  }
})();
