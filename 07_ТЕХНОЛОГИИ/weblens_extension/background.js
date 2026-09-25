// POLER WebLens v2.1 — service worker (MV3).
//
// Слои:
//   1) MCP-релей: content/panel/popup/dropzone → POST /mcp (Streamable HTTP,
//      JSON-RPC, http://127.0.0.1:8765/mcp, Bearer из config.json поверх
//      chrome.storage; fetch из extension-контекста не подчиняется CORS).
//   2) Комбайн: Alt+P («harvest-thread») — захват активной вкладки
//      (content.js на всех http/https; при необходимости — инъекция).
//   3) v2.1 — ЧЕЛОВЕКО-УДОБНЫЙ слой (мышь и Ctrl+V, без JSON и консоли):
//        • контекстное меню правой кнопки: выделенное / ссылка / картинка /
//          вся страница → POLER;
//        • omnibox «poler <текст>» — заметка прямо из адресной строки;
//        • popup (клик по иконке): Ctrl+V → «Архивировать»;
//        • DropZone: перетащить файлы мышью;
//        • нарезка крупных пакетов на части (chunk_size, авто по абзацам);
//        • история отправок (weblens_history) + уведомления ОС + бейджи.
//
// Контур данных:
//   popup/dropzone/content/panel ──sendMessage──▶ background ──POST /mcp──▶ poler-engine
//   {type:'poler:send'|'poler:harvest', payload:{source,title,url,content}}
//       → tools/call poler_chunk {source, title, url, content}

'use strict';

chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: false }) // клик по иконке = popup-архиватор
  .catch(() => {});

let configPromise = null;

/** config.json пишется движком при материализации расширения:
 *  { endpoint: "http://127.0.0.1:8765/", token: "…" }.
 *  Локальные переопределения (popup/dropzone/panel) — в chrome.storage.local. */
async function loadConfig() {
  if (configPromise) return configPromise;
  configPromise = (async () => {
    let packaged = { endpoint: 'http://127.0.0.1:8765/', token: '' };
    try {
      const r = await fetch(chrome.runtime.getURL('config.json'));
      if (r.ok) packaged = await r.json();
    } catch (_) {
      // config.json отсутствует — можно работать по storage-override
    }
    let stored = {};
    try {
      stored = await chrome.storage.local.get([
        'endpoint', 'token', 'timeout_ms', 'chunk_size',
      ]);
    } catch (_) { /* storage недоступен — редкий случай */ }
    return Object.assign({}, packaged, stored);
  })();
  return configPromise;
}

function invalidateConfig() {
  configPromise = null;
}

/** RPC-URL: ТЗ требует http://127.0.0.1:8765/mcp — суффикс добавляется,
 *  если endpoint задан корнем (совместимо со старым config.json). */
function rpcUrl(cfg) {
  const ep = String(cfg.endpoint || 'http://127.0.0.1:8765/').replace(/\/+$/, '');
  return /\/mcp$/.test(ep) ? ep : ep + '/mcp';
}

/** Streamable HTTP: ответ приходит либо application/json,
 *  либо text/event-stream (SSE) — берём последний data:{...}. */
function parseRpcPayload(text) {
  const t = String(text || '').trim();
  if (!t) return null;
  if (t.startsWith('{')) {
    try { return JSON.parse(t); } catch (_) { /* повреждённый JSON → SSE-путь */ }
  }
  let last = null;
  for (const line of t.split(/\r?\n/)) {
    if (line.startsWith('data:')) {
      try { last = JSON.parse(line.slice(5).trim()); } catch (_) {}
    }
  }
  return last;
}

/** Голый JSON-RPC вызов. Возвращает {ok, status?, result?, error?}. */
async function mcpRaw(method, params, id) {
  const cfg = await loadConfig();
  const timeout = Number(cfg.timeout_ms) || 600000; // большой пакет — большой таймаут
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), timeout);
  try {
    const res = await fetch(rpcUrl(cfg), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json, text/event-stream',
        ...(cfg.token ? { Authorization: 'Bearer ' + cfg.token } : {}),
      },
      body: JSON.stringify({ jsonrpc: '2.0', id: id || Date.now(), method, params }),
      signal: ctl.signal,
    });
    const text = await res.text();
    if (!res.ok) {
      return { ok: false, status: res.status, error: text.slice(0, 400) };
    }
    return { ok: true, result: parseRpcPayload(text) };
  } catch (e) {
    return { ok: false, error: String((e && e.message) || e) };
  } finally {
    clearTimeout(timer);
  }
}

/** tools/call → текст первого content-блока (или throw). Совместимо со старым релеем. */
async function mcpCall(tool, args) {
  const r = await mcpRaw('tools/call', { name: tool, arguments: args || {} });
  if (!r.ok) throw new Error(r.error || 'движок ответил HTTP ' + r.status);
  const rpc = r.result;
  if (rpc && rpc.error) throw new Error(rpc.error.message || 'JSON-RPC error');
  const block = rpc && rpc.result && rpc.result.content && rpc.result.content[0];
  if (rpc && rpc.result && rpc.result.isError) {
    throw new Error(block ? block.text : 'ошибка инструмента');
  }
  return block ? block.text : '';
}

/* ================== v2.1: нарезка, история, уведомления, бейджи ================== */

const DEFAULT_CHUNK = 120000;   // символов на часть poler_chunk
const HISTORY_KEY = 'weblens_history';
const HISTORY_CAP = 40;         // храним последние 40 отправок
const HISTORY_FULL = 65536;     // полный текст для «скопировать назад», остальное — превью

function humanSize(chars) {
  const kb = chars / 1024;
  return kb >= 1024 ? (kb / 1024).toFixed(1) + ' МБ' : kb.toFixed(1) + ' КБ';
}

/** Разбивка длинного текста на части по границам абзацев (fallback — жёсткий рез). */
function chunkContent(text, limit) {
  const s = String(text || '');
  if (s.length <= limit) return [s];
  const parts = [];
  let rest = s;
  while (rest.length > limit) {
    let cut = -1;
    // ищем конец абзаца/строки, отступая не дальше 20% назад от лимита
    const from = Math.max(limit - Math.floor(limit * 0.2), 1);
    for (let i = limit; i >= from; i--) {
      if (rest[i] === '\n') { cut = i + 1; break; }
    }
    if (cut <= 0) cut = limit;
    parts.push(rest.slice(0, cut));
    rest = rest.slice(cut);
  }
  if (rest.length) parts.push(rest);
  return parts;
}

/** Уведомление ОС — для фоновых отправок (правый клик, omnibox, Alt+P). */
function notify(title, message) {
  try {
    chrome.notifications.create({
      type: 'basic',
      iconUrl: chrome.runtime.getURL('icons/icon48.png'),
      title: 'POLER WebLens — ' + title,
      message: String(message || '').slice(0, 380),
    });
  } catch (_) { /* уведомления могут быть запрещены — молча */ }
}

let badgeTimer = null;
/** Короткий бейдж на иконке расширения: ⏳ / ✓ / N частей / ! */
function flashBadge(text, color) {
  try {
    chrome.action.setBadgeBackgroundColor({ color: color || '#0e7490' });
    chrome.action.setBadgeText({ text: String(text || '') });
    clearTimeout(badgeTimer);
    badgeTimer = setTimeout(() => {
      chrome.action.setBadgeText({ text: '' }).catch(() => {});
    }, 4000);
  } catch (_) { /* не критично */ }
}

/** Запись в историю отправок (chrome.storage.local). */
async function recordHistory(entry) {
  try {
    const store = await chrome.storage.local.get(HISTORY_KEY);
    const list = Array.isArray(store[HISTORY_KEY]) ? store[HISTORY_KEY] : [];
    list.unshift({
      ts: entry.ts,
      source: entry.source || 'manual',
      title: String(entry.title || 'без названия').slice(0, 200),
      url: String(entry.url || '').slice(0, 500),
      chars: entry.chars || 0,
      chunks: entry.chunks || 1,
      ok: !!entry.ok,
      error: entry.error ? String(entry.error).slice(0, 300) : null,
      content: String(entry.content || '').slice(0, HISTORY_FULL), // для «скопировать назад»
    });
    await chrome.storage.local.set({ [HISTORY_KEY]: list.slice(0, HISTORY_CAP) });
  } catch (_) { /* история не критична */ }
}

/** Отправка пакета в POLER: нарезка → poler_chunk × N → история → бейдж.
 *  Возвращает {ok, text?, chars, chunks, ms, error?}. */
async function sendChunked(payload, opts) {
  const o = opts || {};
  const started = Date.now();
  const content = String((payload && payload.content) || '');
  const baseTitle = String((payload && payload.title) || 'без названия').trim();
  if (!content.trim()) {
    return { ok: false, error: 'пустой пакет — нечего отправлять', chars: 0, chunks: 0, ms: 0 };
  }
  let cfg = { chunk_size: DEFAULT_CHUNK };
  try { cfg = Object.assign(cfg, await loadConfig()); } catch (_) {}
  const limit = Math.max(1000, Number(cfg.chunk_size) || DEFAULT_CHUNK);
  const parts = chunkContent(content, limit);

  flashBadge(parts.length > 1 ? '×' + parts.length : '⏳', '#0891b2');
  let lastText = '';
  for (let i = 0; i < parts.length; i++) {
    const title = parts.length > 1
      ? baseTitle + ' — часть ' + (i + 1) + '/' + parts.length
      : baseTitle;
    try {
      lastText = await mcpCall('poler_chunk', {
        source: (payload && payload.source) || 'manual',
        title,
        url: (payload && payload.url) || '',
        content: parts[i],
      });
    } catch (e) {
      const error = String((e && e.message) || e);
      await recordHistory({
        ts: started, source: payload && payload.source, title: baseTitle,
        url: payload && payload.url, chars: content.length, chunks: parts.length,
        ok: false, error, content,
      });
      flashBadge('!', '#b91c1c');
      if (o.notify) {
        notify('не отправлено', '❌ «' + baseTitle + '»: ' + error +
          '\n\nПроверьте: poler-engine запущен? endpoint и Bearer — ⚙️ в окне архиватора.');
      }
      return { ok: false, error, chars: content.length, chunks: parts.length, ms: Date.now() - started };
    }
  }
  const ms = Date.now() - started;
  await recordHistory({
    ts: started, source: payload && payload.source, title: baseTitle,
    url: payload && payload.url, chars: content.length, chunks: parts.length,
    ok: true, content,
  });
  flashBadge('✓', '#15803d');
  if (o.notify) {
    notify('отправлено', '✅ «' + baseTitle + '» → POLER · ' + humanSize(content.length) +
      (parts.length > 1 ? ' · частей: ' + parts.length : ''));
  }
  return {
    ok: true,
    text: lastText || '(движок принял пакет)',
    chars: content.length,
    chunks: parts.length,
    ms,
  };
}

/* --------------------------- Маршруты сообщений --------------------------- */

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (!msg) return;
  (async () => {
    try {
      switch (msg.type) {
        /* легаси-релей поиска/захвата страниц (panel) */
        case 'poler:mcp': {
          const text = await mcpCall(msg.tool, msg.args || {});
          sendResponse({ ok: true, text });
          break;
        }
        /* комбайн: ветка диалога / папка → poler_chunk (теперь с историей и нарезкой) */
        case 'poler:harvest': {
          const r = await sendChunked(msg.payload || {}, { notify: false });
          sendResponse({
            ok: r.ok,
            text: r.ok ? (r.text || '(движок принял пакет)') : undefined,
            error: r.ok ? undefined : r.error,
            chars: r.chars,
            chunks: r.chunks,
            ms: r.ms,
          });
          break;
        }
        /* v2.1: отправка из popup / dropzone */
        case 'poler:send': {
          const r = await sendChunked(msg.payload || {}, { notify: !!msg.notify });
          sendResponse(r);
          break;
        }
        /* v2.1: диагностика для человека — статус шлюза одной строкой */
        case 'poler:health': {
          const r = await mcpRaw('tools/list', {});
          if (r.ok) {
            const rpc = r.result;
            const tools = (rpc && rpc.result && rpc.result.tools) || (rpc && rpc.tools) || [];
            const names = tools.map ? tools.map((t) => t && t.name).filter(Boolean) : [];
            sendResponse({
              ok: true,
              tools: Array.isArray(tools) ? tools.length : -1,
              hasChunk: names.indexOf('poler_chunk') >= 0,
              rpc: rpcUrl(await loadConfig()),
            });
          } else {
            sendResponse({ ok: false, error: r.error || 'HTTP ' + r.status });
          }
          break;
        }
        /* диагностика шлюза: tools/list */
        case 'poler:ping': {
          const r = await mcpRaw('tools/list', {});
          if (r.ok) {
            const tools = (r.result && r.result.result && r.result.result.tools) ||
                          (r.result && r.result.tools) || [];
            sendResponse({ ok: true, tools: Array.isArray(tools) ? tools.length : -1 });
          } else {
            sendResponse({ ok: false, error: r.error || 'HTTP ' + r.status });
          }
          break;
        }
        /* конфиг шлюза (токен маскируется) */
        case 'poler:config-get': {
          const cfg = await loadConfig();
          sendResponse({
            ok: true,
            endpoint: cfg.endpoint,
            rpc: rpcUrl(cfg),
            token: cfg.token ? String(cfg.token).slice(0, 4) + '***' : '(пусто)',
            chunk_size: Number(cfg.chunk_size) || DEFAULT_CHUNK,
          });
          break;
        }
        case 'poler:config-set': {
          const p = msg.payload || {};
          const patch = {};
          ['endpoint', 'token', 'timeout_ms', 'chunk_size'].forEach((k) => {
            if (p[k] != null && p[k] !== '') patch[k] = p[k];
          });
          if (Object.keys(patch).length) await chrome.storage.local.set(patch);
          invalidateConfig();
          sendResponse({ ok: true });
          break;
        }
        default:
          sendResponse({ ok: false, error: 'WebLens: неизвестный тип сообщения' });
      }
    } catch (e) {
      sendResponse({ ok: false, error: String((e && e.message) || e) });
    }
  })();
  return true; // ответ асинхронный
});

/* ---------------- Alt+P: мгновенный захват активной вкладки ---------------- */

chrome.commands.onCommand.addListener(async (command) => {
  if (command !== 'harvest-thread') return;
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab || tab.id == null || !/^https?:/.test(tab.url || '')) return;
    await chrome.action.setBadgeText({ tabId: tab.id, text: 'RUN' });

    let reply = null;
    try {
      reply = await chrome.tabs.sendMessage(tab.id, { type: 'poler:harvest-run' });
    } catch (_) {
      // контент-скрипт не ответил (например, chrome://) — инъектируем и повторяем
      try {
        await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['content.js'] });
        reply = await chrome.tabs.sendMessage(tab.id, { type: 'poler:harvest-run' });
      } catch (e2) {
        reply = { ok: false, error: 'инъекция невозможна: ' + String((e2 && e2.message) || e2) };
      }
    }
    await chrome.action.setBadgeText({ tabId: tab.id, text: reply && reply.ok ? 'OK' : 'ERR' });
    setTimeout(() => {
      chrome.action.setBadgeText({ tabId: tab.id, text: '' }).catch(() => {});
    }, 3500);
    // v2.1: человеческий фидбек — итог жатвы уведомлением ОС
    if (reply && reply.ok) {
      notify('ветка захвачена', '✅ Alt+P → POLER · ' +
        (reply.chars || 0).toLocaleString('ru-RU') + ' симв.' +
        (reply.strategy ? ' · стратегия: ' + reply.strategy : ''));
    } else {
      notify('Alt+P не удался', '❌ ' + ((reply && reply.error) || 'нет ответа от content.js'));
    }
  } catch (_) {
    /* тихо: команда не на своей странице */
  }
});

/* ---------------- v2.1: контекстное меню правой кнопки мыши ---------------- */

const MENU = {
  ROOT: 'poler-root',
  SEL: 'poler-sel',
  LINK: 'poler-link',
  IMG: 'poler-img',
  PAGE: 'poler-page',
  ZONE: 'poler-zone',
  PANEL: 'poler-panel',
};

chrome.runtime.onInstalled.addListener(async () => {
  try {
    await chrome.contextMenus.removeAll();
    chrome.contextMenus.create({ id: MENU.ROOT, title: '📥 POLER — Архиватор' });
    chrome.contextMenus.create({
      id: MENU.SEL, parentId: MENU.ROOT, title: 'Выделенное — в POLER', contexts: ['selection'],
    });
    chrome.contextMenus.create({
      id: MENU.PAGE, parentId: MENU.ROOT, title: 'Всю страницу — в POLER', contexts: ['page'],
    });
    chrome.contextMenus.create({
      id: MENU.LINK, parentId: MENU.ROOT, title: 'Ссылку — в POLER', contexts: ['link'],
    });
    chrome.contextMenus.create({
      id: MENU.IMG, parentId: MENU.ROOT, title: 'Изображение — в POLER', contexts: ['image'],
    });
    chrome.contextMenus.create({
      id: MENU.ZONE, parentId: MENU.ROOT,
      title: '📂 DropZone — файлы в POLER', contexts: ['action', 'page'],
    });
    chrome.contextMenus.create({
      id: MENU.PANEL, parentId: MENU.ROOT,
      title: '🔍 Панель поиска (side panel)', contexts: ['action', 'page'],
    });
  } catch (_) { /* меню уже созданы — не критично */ }

  // однократное приветствие при установке: сразу показываем DropZone
  try {
    const st = await chrome.storage.local.get(['weblens_welcomed']);
    if (!st.weblens_welcomed) {
      await chrome.storage.local.set({ weblens_welcomed: 1 });
      chrome.tabs.create({ url: chrome.runtime.getURL('dropzone.html') });
      notify('установлен', 'Правый клик → «POLER — Архиватор» · клик по иконке → Ctrl+V · ' +
        'Alt+P — ветка чата. Удачной жатвы!');
    }
  } catch (_) {}
});

/** Текст страницы без комбайнового sweep-скролла — для «Всю страницу». */
async function archiveActivePage(tab) {
  const t = tab || (await chrome.tabs.query({ active: true, currentWindow: true }))[0];
  if (!t || t.id == null || !/^https?:/.test(t.url || '')) {
    notify('не отправлено', 'Это не веб-страница (http/https) — архивировать нечего.');
    return { ok: false, error: 'не веб-страница' };
  }
  let data = null;
  try {
    const [res] = await chrome.scripting.executeScript({
      target: { tabId: t.id },
      func: () => {
        // самодостаточная функция: выполняется в контексте страницы
        const raw = (document.body && document.body.innerText) || '';
        const text = raw.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
        return { title: (document.title || '').trim(), text: text.slice(0, 500000) };
      },
    });
    data = res && res.result;
  } catch (e) {
    const error = 'не удалось прочитать страницу: ' + String((e && e.message) || e);
    notify('не отправлено', '❌ ' + error);
    return { ok: false, error };
  }
  if (!data || !data.text) {
    notify('не отправлено', 'На странице не нашлось текста для архивации.');
    return { ok: false, error: 'пустая страница' };
  }
  return sendChunked({
    source: 'page',
    title: data.title || t.title || 'Страница без заголовка',
    url: t.url,
    content: '# ' + (data.title || '') + '\n\n' + data.text,
  }, { notify: true });
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  try {
    switch (info.menuItemId) {
      case MENU.ZONE: {
        chrome.tabs.create({ url: chrome.runtime.getURL('dropzone.html') });
        return;
      }
      case MENU.PANEL: {
        const t = tab || (await chrome.tabs.query({ active: true, currentWindow: true }))[0];
        if (t && t.id != null) await chrome.sidePanel.open({ tabId: t.id });
        return;
      }
      case MENU.SEL: {
        const text = String(info.selectionText || '').trim();
        if (!text) return;
        await sendChunked({
          source: 'selection',
          title: 'Выделенное — ' + ((tab && tab.title) || info.pageUrl || 'страница').slice(0, 80),
          url: info.pageUrl || (tab && tab.url) || '',
          content: text,
        }, { notify: true });
        return;
      }
      case MENU.LINK: {
        const url = String(info.linkUrl || '');
        const label = String(info.linkText || url).trim() || 'ссылка';
        await sendChunked({
          source: 'link',
          title: 'Ссылка: ' + label.slice(0, 100),
          url: info.pageUrl || '',
          content: '## Ссылка\n\n[' + label + '](' + url + ')\n\n' +
            'Сохранено со страницы: ' + (info.pageUrl || '') + '\n',
        }, { notify: true });
        return;
      }
      case MENU.IMG: {
        const src = String(info.srcUrl || '');
        let name = 'изображение';
        try {
          name = decodeURIComponent(src.split('/').pop() || '').split('?')[0].slice(0, 80) || name;
        } catch (_) {}
        await sendChunked({
          source: 'image',
          title: 'Изображение: ' + name,
          url: info.pageUrl || '',
          content: '## Изображение\n\n![' + name + '](' + src + ')\n\n' +
            'Сохранено со страницы: ' + (info.pageUrl || '') + '\n',
        }, { notify: true });
        return;
      }
      case MENU.PAGE: {
        await archiveActivePage(tab);
        return;
      }
      default:
        // чужие пункты — игнорируем
    }
  } catch (e) {
    notify('ошибка меню', String((e && e.message) || e));
  }
});

/* ---------------------- v2.1: omnibox «poler …» ---------------------- */

function omniboxEscape(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
}

chrome.omnibox.onInputChanged.addListener((text, suggest) => {
  const t = String(text || '').trim();
  if (!t) {
    suggest([{
      content: 'ping',
      description: '📥 POLER: <dim>введите текст заметки — Enter отправит её в POLER; «ping» — тест шлюза</dim>',
    }]);
    return;
  }
  if (/^(ping|тест|test)$/i.test(t)) {
    suggest([{ content: t, description: '🧪 POLER: <dim>проверить MCP-шлюз движка</dim>' }]);
    return;
  }
  suggest([{
    content: t,
    description: '📥 Архивировать в POLER: <match>' + omniboxEscape(t.slice(0, 60)) + '</match>',
  }]);
});

chrome.omnibox.onInputEntered.addListener(async (text) => {
  const t = String(text || '').trim();
  if (!t) return;
  if (/^(ping|тест|test)$/i.test(t)) {
    const r = await mcpRaw('tools/list', {});
    if (r.ok) {
      notify('шлюз жив', '✅ MCP-шлюз отвечает на ' + rpcUrl(await loadConfig()));
    } else {
      notify('шлюз молчит', '❌ ' + (r.error || 'HTTP ' + r.status) +
        '\nЗапустите poler-engine с MCP-шлюзом.');
    }
    return;
  }
  const first = t.split('\n')[0];
  const title = first.length > 80 ? first.slice(0, 77) + '…' : (first || 'Заметка из адресной строки');
  await sendChunked({ source: 'omnibox', title, url: '', content: t }, { notify: true });
});
