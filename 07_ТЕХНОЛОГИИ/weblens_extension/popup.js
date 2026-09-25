// POLER WebLens v2.1 — popup-архиватор: «скопировал → клик → Ctrl+V → кнопка».
//
// Философия слоя: человек работает мышью и Ctrl+V, не видя ни JSON, ни консоли.
// Вся сетевая работа — в background.js (роутер 'poler:send').

'use strict';

/* В обычном браузере (без chrome.*)popup деградирует в заглушку —
 * это позволяет открывать popup.html для визуальной проверки. */
const CH = (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.id)
  ? chrome
  : null;

const $ = (id) => document.getElementById(id);

let sendSource = 'manual';   // chip источника: clipboard / selection / page / manual / history
let tabInfo = null;          // активная вкладка на момент открытия popup

/* ------------------------------- утилиты ------------------------------- */

function fmtKB(chars) {
  const kb = chars / 1024;
  return kb >= 1024 ? (kb / 1024).toFixed(1) + ' МБ' : kb.toFixed(1) + ' КБ';
}

function fmtTime(ts) {
  try {
    return new Date(ts).toLocaleString('ru-RU', {
      day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
    });
  } catch (_) { return new Date(ts).toISOString().slice(0, 16).replace('T', ' '); }
}

function autoTitle(text) {
  const line = String(text || '').split('\n').map((s) => s.trim())
    .find((s) => s.length > 0) || '';
  const clean = line.replace(/^#{1,6}\s*/, '').replace(/[*_`>]+/g, '').replace(/\s+/g, ' ');
  return clean.length > 80 ? clean.slice(0, 77) + '…' : clean;
}

function showStatus(text, cls) {
  const el = $('status');
  el.hidden = false;
  el.textContent = text;
  el.className = 'status ' + (cls || '');
}

function switchTab(name) {
  document.querySelectorAll('.tab').forEach((b) => {
    b.classList.toggle('active', b.dataset.tab === name);
  });
  document.querySelectorAll('.pane').forEach((p) => {
    p.classList.toggle('active', p.id === 'tab-' + name);
  });
}

/* ------------------------------ активная вкладка ------------------------------ */

async function detectTab() {
  if (!CH) return;
  try {
    const [tab] = await CH.tabs.query({ active: true, currentWindow: true });
    tabInfo = tab || null;
    if (tab && tab.url && /^https?:/.test(tab.url)) {
      $('url').value = tab.url;
      if (!$('title').value) {
        $('title').placeholder = 'авто: «' + String(tab.title || '').slice(0, 50) + '»';
      }
    }
  } catch (_) { /* вкладка недоступна — не критично */ }
}

/* ------------------------------ статус шлюза ------------------------------ */

async function refreshDot() {
  if (!CH) {
    $('dot').textContent = 'шлюз: нет chrome.* (просмотр)';
    return;
  }
  const dot = $('dot');
  dot.className = 'dot offline';
  dot.textContent = 'шлюз: проверяю…';
  try {
    const r = await CH.runtime.sendMessage({ type: 'poler:health' });
    if (r && r.ok) {
      dot.className = 'dot online';
      dot.textContent = 'шлюз: на связи' +
        (r.hasChunk ? '' : ' (poler_chunk не найден!)');
      dot.title = r.rpc || '';
      if (!r.hasChunk) {
        dot.className = 'dot offline';
        dot.textContent = 'шлюз: жив, но poler_chunk недоступен';
      }
    } else {
      dot.textContent = 'шлюз: офлайн — запустите poler-engine';
      dot.title = (r && r.error) || '';
    }
  } catch (e) {
    dot.textContent = 'шлюз: офлайн';
    dot.title = String((e && e.message) || e);
  }
}

/* --------------------------- быстрые кнопки мыши --------------------------- */

async function fromClipboard() {
  if (!CH) return;
  try {
    const text = await navigator.clipboard.readText();
    if (!text || !text.trim()) {
      showStatus('Буфер обмена пуст — скопируйте что-нибудь и повторите.', 'err');
      return;
    }
    $('content').value = text;
    if (!$('title').value) $('title').value = autoTitle(text);
    sendSource = 'clipboard';
    showStatus('📋 Взят текст из буфера: ' + fmtKB(text.length) + '. Жмите «Архивировать».', 'ok');
  } catch (e) {
    showStatus('Не удалось прочитать буфер: ' + String((e && e.message) || e) +
      '\nАльтернатива — просто нажмите Ctrl+V в поле текста.', 'err');
  }
}

async function injectAndGrab(func) {
  if (!CH || !tabInfo || tabInfo.id == null || !/^https?:/.test(tabInfo.url || '')) {
    showStatus('Откройте обычную веб-страницу (http/https) — текущая не читается.', 'err');
    return null;
  }
  const [res] = await CH.scripting.executeScript({
    target: { tabId: tabInfo.id },
    func,
  });
  return res && res.result;
}

async function fromSelection() {
  if (!CH) return;
  try {
    const text = await injectAndGrab(() => String(window.getSelection()));
    if (!text || !text.trim()) {
      showStatus('На странице ничего не выделено. Выделите текст мышью и повторите.', 'err');
      return;
    }
    $('content').value = text;
    if (!$('title').value) {
      $('title').value = 'Выделенное — ' + String(tabInfo.title || '').slice(0, 60);
    }
    sendSource = 'selection';
    showStatus('🖱 Взят выделенный фрагмент: ' + fmtKB(text.length) + '.', 'ok');
  } catch (e) {
    showStatus('Не удалось прочитать выделение: ' + String((e && e.message) || e), 'err');
  }
}

async function fromPage() {
  if (!CH) return;
  try {
    const data = await injectAndGrab(() => {
      const raw = (document.body && document.body.innerText) || '';
      const text = raw.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
      return { title: (document.title || '').trim(), text: text.slice(0, 500000) };
    });
    if (!data || !data.text) {
      showStatus('На странице не нашлось текста.', 'err');
      return;
    }
    $('content').value = data.text;
    $('title').value = data.title || String(tabInfo.title || 'Страница без заголовка');
    if (tabInfo.url) $('url').value = tabInfo.url;
    sendSource = 'page';
    showStatus('📄 Взят текст страницы: ' + fmtKB(data.text.length) + '.', 'ok');
  } catch (e) {
    showStatus('Не удалось прочитать страницу: ' + String((e && e.message) || e), 'err');
  }
}

/* ------------------------------ отправка ------------------------------ */

async function doSend() {
  if (!CH) {
    showStatus('Это предпросмотр без расширения — установите WebLens в Chrome.', 'err');
    return;
  }
  const content = $('content').value;
  if (!content.trim()) {
    showStatus('Поле текста пустое: нажмите Ctrl+V или кнопку «📋 Из буфера».', 'err');
    $('content').focus();
    return;
  }
  const title = $('title').value.trim() || autoTitle(content) || 'Ручная заметка';
  const url = $('url').value.trim();

  const btn = $('send');
  btn.disabled = true;
  const old = btn.textContent;
  btn.textContent = '⏳ Отправляю' + (content.length > 120000 ? ' (нарезаю на части)…' : '…');
  showStatus('⏳ Отправка в POLER: ' + fmtKB(content.length) + '…', '');

  try {
    const r = await CH.runtime.sendMessage({
      type: 'poler:send',
      payload: { source: sendSource, title, url, content },
    });
    if (r && r.ok) {
      showStatus('✅ Отправлено: ' + fmtKB(r.chars) +
        (r.chunks > 1 ? ' · частей: ' + r.chunks : '') +
        ' · за ' + (r.ms / 1000).toFixed(1) + ' с' +
        (r.text ? '\nДвижок: ' + String(r.text).slice(0, 160) : ''), 'ok');
      $('title').value = '';
      $('content').value = '';
      sendSource = 'manual';
      refreshHistBadge();
    } else {
      showStatus('❌ ' + ((r && r.error) || 'нет ответа шлюза') +
        '\n\nПроверьте: poler-engine запущен? endpoint и токен — вкладка ⚙️ Шлюз.', 'err');
    }
  } catch (e) {
    showStatus('❌ ' + String((e && e.message) || e), 'err');
  } finally {
    btn.disabled = false;
    btn.textContent = old;
  }
}

/* --------------------------- вставка файлов/текста --------------------------- */

const TEXT_FILE_RE =
  /\.(txt|md|markdown|json|jsonl|csv|tsv|log|xml|html?|js|mjs|cjs|ts|tsx|jsx|py|rs|go|java|c|h|cpp|hpp|cs|rb|php|sh|bash|zsh|yaml|yml|toml|ini|cfg|conf|sql|tex|bib|srt|vtt|css|scss|less|svg|diff|patch)$/i;

async function readTextFile(file) {
  const text = await file.text();
  if (!$('content').value) {
    $('content').value = text;
    if (!$('title').value) $('title').value = file.name;
  } else {
    $('content').value += '\n\n--- ' + file.name + ' ---\n\n' + text;
  }
  showStatus('📄 Файл «' + file.name + '» вставлен: ' + fmtKB(text.length) + '.', 'ok');
}

function hintImages() {
  showStatus('🖼 Картинки в это поле не вставляются — перетащите их в 📂 DropZone.', 'err');
}

/* paste с файлами (скриншоты Ctrl+V): текст берём, картинки отсылаем в DropZone */
$('content').addEventListener('paste', async (e) => {
  const files = e.clipboardData && e.clipboardData.files;
  if (files && files.length) {
    e.preventDefault();
    let handled = 0;
    for (const f of files) {
      if (f.type && f.type.startsWith('image/')) { hintImages(); continue; }
      if (f.type && f.type.startsWith('text/') || TEXT_FILE_RE.test(f.name)) {
        try { await readTextFile(f); handled++; } catch (_) {}
      }
    }
    if (!handled && ![...files].every((f) => f.type && f.type.startsWith('image/'))) {
      hintImages();
    }
    return;
  }
  // обычный текст вставится нативно; подставим авто-заголовок
  setTimeout(() => {
    if (!$('title').value && $('content').value) $('title').value = autoTitle($('content').value);
    sendSource = sendSource === 'manual' ? 'clipboard' : sendSource;
  }, 0);
});

/* перетаскивание текстовых файлов прямо в поле */
for (const ev of ['dragover', 'dragenter']) {
  $('content').addEventListener(ev, (e) => {
    e.preventDefault();
    $('content').style.borderColor = 'var(--cy)';
  });
}
for (const ev of ['dragleave', 'drop']) {
  $('content').addEventListener(ev, (e) => {
    e.preventDefault();
    $('content').style.borderColor = '';
  });
}
$('content').addEventListener('drop', async (e) => {
  const files = e.dataTransfer && e.dataTransfer.files;
  if (!files || !files.length) return;
  for (const f of files) {
    if (f.type && f.type.startsWith('image/')) { hintImages(); continue; }
    if ((f.type && f.type.startsWith('text/')) || TEXT_FILE_RE.test(f.name)) {
      try { await readTextFile(f); } catch (_) {}
    } else {
      hintImages();
    }
  }
});

/* Ctrl+Enter — отправить; Enter в полях — перейти к тексту */
$('content').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    doSend();
  }
});
$('title').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') { e.preventDefault(); $('content').focus(); }
});
$('url').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') { e.preventDefault(); $('content').focus(); }
});

/* ------------------------------ история ------------------------------ */

async function loadHistory() {
  if (!CH) return [];
  try {
    const st = await CH.storage.local.get('weblens_history');
    return Array.isArray(st.weblens_history) ? st.weblens_history : [];
  } catch (_) { return []; }
}

async function refreshHistBadge() {
  const list = await loadHistory();
  const n = $('hist-n');
  n.textContent = String(list.length);
  n.hidden = list.length === 0;
}

async function renderHistory() {
  const box = $('history');
  box.innerHTML = '';
  const list = await loadHistory();
  if (!list.length) {
    const d = document.createElement('div');
    d.className = 'hist-empty';
    d.textContent = 'Пока ничего не отправлено. Скопируйте текст → клик по иконке → Ctrl+V → «Архивировать».';
    box.appendChild(d);
    return;
  }
  for (const it of list) {
    const card = document.createElement('div');
    card.className = 'hist ' + (it.ok ? 'ok' : 'err');

    const top = document.createElement('div');
    top.className = 'hist-top';
    const dot = document.createElement('span');
    dot.className = 'hist-dot';
    dot.textContent = it.ok ? '●' : '✕';
    const t = document.createElement('span');
    t.className = 'hist-title';
    t.textContent = it.title || 'без названия';
    t.title = it.title || '';
    top.appendChild(dot);
    top.appendChild(t);
    card.appendChild(top);

    const meta = document.createElement('div');
    meta.className = 'hist-meta';
    meta.textContent = (it.source || '—') + ' · ' + fmtKB(it.chars || 0) +
      (it.chunks > 1 ? ' · частей: ' + it.chunks : '') + ' · ' + fmtTime(it.ts);
    card.appendChild(meta);

    if (it.url) {
      const u = document.createElement('a');
      u.className = 'hist-url';
      u.href = it.url;
      u.textContent = it.url;
      u.addEventListener('click', (e) => {
        e.preventDefault();
        if (CH) CH.tabs.create({ url: it.url });
        else window.open(it.url, '_blank');
      });
      card.appendChild(u);
    }

    if (!it.ok && it.error) {
      const er = document.createElement('div');
      er.className = 'hist-err';
      er.textContent = '⚠ ' + it.error;
      card.appendChild(er);
    }

    if (it.content) {
      const pv = document.createElement('div');
      pv.className = 'hist-preview';
      pv.textContent = String(it.content).slice(0, 200).replace(/\s+/g, ' ');
      card.appendChild(pv);
    }

    const act = document.createElement('div');
    act.className = 'hist-actions';

    const bCopy = document.createElement('button');
    bCopy.textContent = '📋 Скопировать';
    bCopy.title = 'Вернуть текст в буфер обмена';
    bCopy.addEventListener('click', async () => {
      const text = it.content || '';
      if (!text) return;
      try {
        await navigator.clipboard.writeText(text);
        bCopy.textContent = '✓ Скопировано';
        setTimeout(() => { bCopy.textContent = '📋 Скопировать'; }, 1600);
      } catch (_) {
        bCopy.textContent = '⚠ Не вышло';
        setTimeout(() => { bCopy.textContent = '📋 Скопировать'; }, 1600);
      }
    });
    act.appendChild(bCopy);

    const bRetry = document.createElement('button');
    bRetry.textContent = '↗ В форму';
    bRetry.title = 'Поставить этот текст обратно в поле отправки';
    bRetry.addEventListener('click', () => {
      $('content').value = it.content || '';
      $('title').value = it.title || '';
      $('url').value = it.url || '';
      sendSource = 'history';
      switchTab('send');
      $('content').focus();
    });
    act.appendChild(bRetry);

    card.appendChild(act);
    box.appendChild(card);
  }
}

$('hist-clear').addEventListener('click', async () => {
  if (!CH) return;
  if (!confirm('Очистить журнал отправок? Сами данные в POLER останутся.')) return;
  await CH.storage.local.remove('weblens_history');
  await renderHistory();
  await refreshHistBadge();
});

/* ------------------------------ настройки шлюза ------------------------------ */

async function refreshCfg() {
  if (!CH) return;
  try {
    const r = await CH.runtime.sendMessage({ type: 'poler:config-get' });
    if (r && r.ok) {
      $('cfg-endpoint').value = r.endpoint || '';
      $('cfg-token').placeholder = r.token || '(пусто)';
      $('cfg-chunk').value = r.chunk_size || '';
    }
  } catch (_) {}
}

async function saveCfg() {
  if (!CH) return;
  const payload = { endpoint: $('cfg-endpoint').value.trim() };
  const token = $('cfg-token').value.trim();
  if (token) payload.token = token; // пусто = не трогаем (там маска-плейсхолдер)
  const chunk = Number($('cfg-chunk').value);
  if (chunk >= 1000) payload.chunk_size = chunk;
  try {
    await CH.runtime.sendMessage({ type: 'poler:config-set', payload });
    $('cfg-token').value = '';
    showCfgStatus('✅ Сохранено. Проверяю шлюз…', 'ok');
    await refreshCfg();
    await refreshDot();
    await testGateway();
  } catch (e) {
    showCfgStatus('❌ Не сохранено: ' + String((e && e.message) || e), 'err');
  }
}

function showCfgStatus(text, cls) {
  const el = $('cfg-status');
  el.hidden = false;
  el.textContent = text;
  el.className = 'status ' + (cls || '');
}

async function testGateway() {
  if (!CH) return;
  showCfgStatus('🧪 Проверяю MCP-шлюз…', '');
  try {
    const r = await CH.runtime.sendMessage({ type: 'poler:health' });
    if (r && r.ok) {
      showCfgStatus('✅ Шлюз жив: ' + (r.tools >= 0 ? r.tools + ' tools' : 'JSON-RPC отвечает') +
        ' · poler_chunk ' + (r.hasChunk ? 'доступен' : 'НЕ найден') + '\n' + r.rpc, 'ok');
    } else {
      showCfgStatus('❌ ' + ((r && r.error) || 'нет ответа') +
        '\n\npoler-engine запущен? MCP-шлюз слушает этот адрес?', 'err');
    }
  } catch (e) {
    showCfgStatus('❌ ' + String((e && e.message) || e), 'err');
  }
}

$('cfg-save').addEventListener('click', saveCfg);
$('cfg-test').addEventListener('click', testGateway);

/* ------------------------------ навигация ------------------------------ */

document.querySelectorAll('.tab').forEach((b) => {
  b.addEventListener('click', () => {
    switchTab(b.dataset.tab);
    if (b.dataset.tab === 'history') renderHistory();
    if (b.dataset.tab === 'cfg') refreshCfg();
  });
});

function openDropzone() {
  if (CH) CH.tabs.create({ url: CH.runtime.getURL('dropzone.html') });
}
$('open-zone').addEventListener('click', (e) => { e.preventDefault(); openDropzone(); });
$('foot-zone').addEventListener('click', (e) => { e.preventDefault(); openDropzone(); });

$('foot-panel').addEventListener('click', async (e) => {
  e.preventDefault();
  if (!CH || !tabInfo || tabInfo.id == null) return;
  try {
    await CH.sidePanel.open({ tabId: tabInfo.id });
    window.close();
  } catch (_) {
    showStatus('Панель не открылась. Правый клик по иконке → «Панель поиска (side panel)».', 'err');
  }
});

/* кнопки-мышь */
$('q-clipboard').addEventListener('click', fromClipboard);
$('q-selection').addEventListener('click', fromSelection);
$('q-page').addEventListener('click', fromPage);
$('send').addEventListener('click', doSend);

/* ------------------------------ старт ------------------------------ */

if (!CH) {
  // режим предпросмотра: показываем форму, но без живого шлюза
  $('dot').textContent = 'шлюз: нет chrome.* (просмотр)';
} else {
  detectTab();
  refreshDot();
  refreshHistBadge();
  refreshCfg();
}
$('content').focus();
