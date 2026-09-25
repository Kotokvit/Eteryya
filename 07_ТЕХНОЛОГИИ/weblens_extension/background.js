// POLER WebLens v2.0 — service worker (MV3).
// Роли:
//   1) side panel по клику на иконку (поиск по индексам движка);
//   2) релей сообщений content/panel → MCP-шлюз движка
//      (Streamable HTTP / JSON-RPC, http://127.0.0.1:8765/mcp, Bearer из config.json;
//       fetch из extension-контекста не подчиняется CORS страницы —
//       host_permissions покрывают localhost);
//   3) Alt+P («harvest-thread») — мгновенный захват активной вкладки:
//      контент-скрипт уже стоит на всех http/https; если нет — программная инъекция.
//
// Контур данных комбайна:
//   content.js ──chrome.runtime.sendMessage──▶ background.js ──POST /mcp──▶ poler-engine
//   {type:'poler:harvest', payload:{source,title,url,content}}
//       → tools/call poler_chunk {source, title, url, content}

'use strict';

chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch(() => {});

let configPromise = null;

/** config.json пишется движком при материализации расширения:
 *  { endpoint: "http://127.0.0.1:8765/", token: "…" }.
 *  Локальные переопределения (из panel) хранятся в chrome.storage.local. */
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
      stored = await chrome.storage.local.get(['endpoint', 'token', 'timeout_ms']);
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
        /* комбайн: ветка диалога / папка → poler_chunk */
        case 'poler:harvest': {
          const a = msg.payload || {};
          const text = await mcpCall('poler_chunk', {
            source: a.source,
            title: a.title,
            url: a.url,
            content: a.content,
          });
          sendResponse({ ok: true, text: text || '(движок принял пакет)', chars: (a.content || '').length });
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
          });
          break;
        }
        case 'poler:config-set': {
          const p = msg.payload || {};
          const patch = {};
          ['endpoint', 'token', 'timeout_ms'].forEach((k) => {
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
  } catch (_) {
    /* тихо: команда не на своей странице */
  }
});
