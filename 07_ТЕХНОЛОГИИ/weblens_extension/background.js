// POLER WebLens — service worker (MV3).
// Роли: открытие side panel по клику на иконку; релей сообщений
// content script → MCP-сервер движка (fetch из extension-контекста
// не подчиняется CORS страницы — host_permissions покрывают localhost).

chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch(() => {});

let configPromise = null;

/** config.json пишется движком при материализации расширения:
 *  { endpoint: "http://127.0.0.1:8765/", token: "…" } */
function loadConfig() {
  if (!configPromise) {
    configPromise = fetch(chrome.runtime.getURL('config.json')).then((r) => {
      if (!r.ok) throw new Error('config.json не найден: запустите poler-engine --web-lens');
      return r.json();
    });
  }
  return configPromise;
}

/** JSON-RPC tools/call → текст результата (или throw). */
async function mcpCall(tool, args) {
  const cfg = await loadConfig();
  const res = await fetch(cfg.endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + cfg.token,
    },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      method: 'tools/call',
      params: { name: tool, arguments: args },
    }),
  });
  if (!res.ok) {
    throw new Error('движок ответил HTTP ' + res.status + ' (запущен ли --web-lens?)');
  }
  const rpc = await res.json();
  if (rpc.error) throw new Error(rpc.error.message);
  const block = rpc.result && rpc.result.content && rpc.result.content[0];
  if (rpc.result && rpc.result.isError) throw new Error(block ? block.text : 'ошибка инструмента');
  return block ? block.text : '';
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (!msg || msg.type !== 'poler:mcp') return;
  mcpCall(msg.tool, msg.args || {})
    .then((text) => sendResponse({ ok: true, text }))
    .catch((err) => sendResponse({ ok: false, error: String(err && err.message ? err.message : err) }));
  return true; // ответ асинхронный
});
