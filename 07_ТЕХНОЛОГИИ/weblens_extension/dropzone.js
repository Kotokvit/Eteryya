// POLER WebLens v2.1 — DropZone: перетащил файлы мышью → кнопка → всё в POLER.
//
// Человек работает мышью: drag&drop, «выбрать на диске», Ctrl+V (текст и
// скриншоты). Сеть — только через background.js ('poler:send'), чтобы не
// дублировать авторизацию и обработку ответов MCP-шлюза.

'use strict';

const CH = (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.id)
  ? chrome
  : null;

const $ = (id) => document.getElementById(id);

const TEXT_FILE_RE =
  /\.(txt|md|markdown|json|jsonl|csv|tsv|log|xml|html?|js|mjs|cjs|ts|tsx|jsx|py|rs|go|java|c|h|cpp|hpp|cs|rb|php|sh|bash|zsh|yaml|yml|toml|ini|cfg|conf|sql|tex|bib|srt|vtt|css|scss|less|svg|diff|patch)$/i;

const IMAGE_CAP = 3 * 1024 * 1024; // картинки крупнее — не тащим (data-URL распухает)

/** @type Array<{id:number,name:string,size:number,kind:'text'|'image'|'skip',
 *              content:string,state:'ready'|'send'|'ok'|'err'|'skip',error?:string}> */
let queue = [];
let uid = 0;
let sending = false;

/* ------------------------------- утилиты ------------------------------- */

function fmtKB(bytes) {
  const kb = bytes / 1024;
  return kb >= 1024 ? (kb / 1024).toFixed(1) + ' МБ' : kb.toFixed(1) + ' КБ';
}

function fmtTime(ts) {
  try {
    return new Date(ts).toLocaleString('ru-RU', {
      day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
    });
  } catch (_) { return ''; }
}

function iconFor(kind) {
  return kind === 'image' ? '🖼' : kind === 'skip' ? '⚠️' : '📄';
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
    if (r && r.ok && r.hasChunk) {
      dot.className = 'dot online';
      dot.textContent = 'шлюз: на связи';
      dot.title = r.rpc || '';
    } else if (r && r.ok) {
      dot.textContent = 'шлюз: жив, но poler_chunk недоступен';
      dot.title = r.rpc || '';
    } else {
      dot.textContent = 'шлюз: офлайн — запустите poler-engine';
      dot.title = (r && r.error) || '';
    }
  } catch (e) {
    dot.textContent = 'шлюз: офлайн';
  }
}

/* ---------------------------- приём файлов ---------------------------- */

function isTextFile(file) {
  return (file.type && file.type.startsWith('text/')) ||
         (!file.type && TEXT_FILE_RE.test(file.name)) ||
         (file.type === 'application/json') ||
         TEXT_FILE_RE.test(file.name);
}

async function addItemFromFile(file) {
  const id = ++uid;
  if (file.type && file.type.startsWith('image/')) {
    if (file.size > IMAGE_CAP) {
      queue.push({ id, name: file.name, size: file.size, kind: 'skip',
        content: '', state: 'skip', error: 'картинка больше 3 МБ — пропущена' });
    } else {
      const dataUrl = await new Promise((resolve, reject) => {
        const fr = new FileReader();
        fr.onload = () => resolve(String(fr.result || ''));
        fr.onerror = () => reject(fr.error);
        fr.readAsDataURL(file);
      }).catch(() => '');
      queue.push({
        id, name: file.name || 'скриншот.png', size: file.size, kind: 'image',
        content: '## ' + (file.name || 'скриншот') + '\n\n![' + (file.name || 'скриншот') +
          '](<' + dataUrl + '>)\n\n*Вложено из DropZone ' + fmtTime(Date.now()) + '*\n',
        state: 'ready',
      });
    }
  } else if (isTextFile(file)) {
    const text = await file.text();
    queue.push({
      id, name: file.name, size: file.size, kind: 'text',
      content: '# ' + file.name + '\n\n' + text, state: 'ready',
    });
  } else {
    queue.push({ id, name: file.name, size: file.size, kind: 'skip', content: '',
      state: 'skip',
      error: 'бинарный/нечитаемый формат — в POLER не отправляется' });
  }
  render();
}

async function addFiles(fileList) {
  for (const f of fileList) {
    try { await addItemFromFile(f); } catch (e) {
      queue.push({ id: ++uid, name: f.name, size: f.size, kind: 'skip', content: '',
        state: 'skip', error: 'не прочитан: ' + String((e && e.message) || e) });
      render();
    }
  }
}

/* Ctrl+V: скриншоты и текст из буфера */
document.addEventListener('paste', async (e) => {
  const files = e.clipboardData && e.clipboardData.files;
  if (files && files.length) {
    e.preventDefault();
    await addFiles(files);
    return;
  }
  const text = e.clipboardData && e.clipboardData.getData('text/plain');
  if (text && text.trim()) {
    e.preventDefault();
    const id = ++uid;
    queue.push({
      id, name: 'Заметка — ' + fmtTime(Date.now()), size: text.length, kind: 'text',
      content: '# Заметка из буфера\n\n' + text, state: 'ready',
    });
    render();
  }
});

/* drag&drop на всю зону */
const zone = $('zone');
for (const ev of ['dragover', 'dragenter']) {
  document.addEventListener(ev, (e) => {
    e.preventDefault();
    zone.classList.add('drag');
  });
}
for (const ev of ['dragleave', 'drop']) {
  document.addEventListener(ev, (e) => {
    e.preventDefault();
    zone.classList.remove('drag');
  });
}
document.addEventListener('drop', (e) => {
  const files = e.dataTransfer && e.dataTransfer.files;
  if (files && files.length) addFiles(files);
});

/* «выбрать на диске» — классический клик мышью */
$('file-pick').addEventListener('change', (e) => {
  if (e.target.files && e.target.files.length) addFiles(e.target.files);
  e.target.value = ''; // чтобы тот же файл можно было выбрать повторно
});

/* ------------------------------ очередь ------------------------------ */

function render() {
  const box = $('items');
  box.innerHTML = '';
  const visible = queue.filter((it) => it.state !== 'done');
  $('queue').hidden = visible.length === 0;
  $('q-count').textContent = String(visible.length);
  $('send-all').disabled = sending || !queue.some((it) => it.state === 'ready' || it.state === 'err');

  for (const it of visible) {
    const card = document.createElement('div');
    card.className = 'item ' + (it.state === 'ok' ? 'ok' : it.state === 'err' ? 'err' :
      it.state === 'skip' ? 'skip' : '');

    const top = document.createElement('div');
    top.className = 'item-top';
    const ic = document.createElement('span');
    ic.className = 'item-icon';
    ic.textContent = iconFor(it.kind);
    const nm = document.createElement('span');
    nm.className = 'item-name';
    nm.textContent = it.name;
    nm.title = it.name;
    const st = document.createElement('span');
    st.className = 'state ' + it.state;
    st.textContent = it.state === 'ready' ? 'готов' :
      it.state === 'send' ? '⏳ отправка…' :
      it.state === 'ok' ? '✓ в POLER' :
      it.state === 'skip' ? 'пропущен' : '✕ ошибка';
    top.appendChild(ic);
    top.appendChild(nm);
    top.appendChild(st);
    card.appendChild(top);

    const meta = document.createElement('div');
    meta.className = 'item-meta';
    meta.textContent = fmtKB(it.size || (it.content || '').length) +
      (it.error ? ' · ' + it.error : '');
    card.appendChild(meta);

    if (it.kind === 'text' && it.content) {
      const pv = document.createElement('div');
      pv.className = 'item-preview';
      pv.textContent = it.content.replace(/^#.*\n+/, '').slice(0, 160).replace(/\s+/g, ' ');
      card.appendChild(pv);
    }

    const act = document.createElement('div');
    act.className = 'item-actions';
    if (it.state === 'ready' || it.state === 'err') {
      const one = document.createElement('button');
      one.textContent = '↗ Отправить';
      one.addEventListener('click', () => sendOne(it.id));
      act.appendChild(one);
    }
    const rm = document.createElement('button');
    rm.textContent = '✕ Убрать';
    rm.addEventListener('click', () => {
      queue = queue.filter((x) => x.id !== it.id);
      render();
    });
    act.appendChild(rm);
    card.appendChild(act);

    box.appendChild(card);
  }
}

/* ------------------------------ отправка ------------------------------ */

function patch(id, fields) {
  const it = queue.find((x) => x.id === id);
  if (it) Object.assign(it, fields);
}

async function polerSend(item) {
  const r = await CH.runtime.sendMessage({
    type: 'poler:send',
    payload: {
      source: item.kind === 'image' ? 'dropzone-image' : 'dropzone',
      title: item.name,
      url: 'dropzone://local/' + encodeURIComponent(item.name),
      content: item.content,
    },
  });
  return r;
}

async function sendOne(id) {
  if (!CH || sending) return;
  const it = queue.find((x) => x.id === id);
  if (!it || it.state !== 'ready' && it.state !== 'err') return;
  sending = true;
  patch(id, { state: 'send' });
  render();
  try {
    const r = await polerSend(it);
    if (r && r.ok) patch(id, { state: 'ok', error: undefined });
    else patch(id, { state: 'err', error: (r && r.error) || 'нет ответа шлюза' });
  } catch (e) {
    patch(id, { state: 'err', error: String((e && e.message) || e) });
  } finally {
    sending = false;
    render();
  }
}

async function sendAll() {
  if (!CH || sending) return;
  const targets = queue.filter((it) => it.state === 'ready' || it.state === 'err');
  if (!targets.length) return;
  sending = true;
  $('send-all').disabled = true;
  let done = 0;
  for (const it of targets) {
    patch(it.id, { state: 'send' });
    render();
    try {
      const r = await polerSend(it);
      if (r && r.ok) patch(it.id, { state: 'ok', error: undefined });
      else patch(it.id, { state: 'err', error: (r && r.error) || 'нет ответа шлюза' });
    } catch (e) {
      patch(it.id, { state: 'err', error: String((e && e.message) || e) });
    }
    done++;
    $('progress').textContent = 'отправлено ' + done + ' из ' + targets.length + '…';
  }
  sending = false;
  const okN = targets.filter((it) => it.state === 'ok').length;
  const errN = targets.length - okN;
  $('progress').textContent = errN
    ? 'готово: ' + okN + ' ✓, ошибок: ' + errN + ' — шлюз запущен?'
    : 'готово: ' + okN + ' из ' + targets.length + ' ✓';
  render();
  refreshDot();
}

$('send-all').addEventListener('click', sendAll);
$('q-clear').addEventListener('click', () => {
  if (sending) return;
  queue = [];
  $('progress').textContent = '';
  render();
});

/* --------------------------- настройки-шапка --------------------------- */

async function refreshCfg() {
  if (!CH) return;
  try {
    const r = await CH.runtime.sendMessage({ type: 'poler:config-get' });
    if (r && r.ok) {
      $('cfg-endpoint').value = r.endpoint || '';
      $('cfg-token').placeholder = r.token || '(пусто)';
    }
  } catch (_) {}
}

async function saveCfg() {
  if (!CH) return;
  const payload = { endpoint: $('cfg-endpoint').value.trim() };
  const token = $('cfg-token').value.trim();
  if (token) payload.token = token;
  try {
    await CH.runtime.sendMessage({ type: 'poler:config-set', payload });
    $('cfg-token').value = '';
    cfgStatus('✅ Сохранено', 'ok');
    await refreshCfg();
    await refreshDot();
  } catch (e) {
    cfgStatus('❌ ' + String((e && e.message) || e), 'err');
  }
}

function cfgStatus(text, cls) {
  const el = $('cfg-status');
  el.hidden = false;
  el.textContent = text;
  el.className = 'cfg-status ' + (cls || '');
}

async function testGateway() {
  if (!CH) return;
  cfgStatus('🧪 Проверяю…', '');
  try {
    const r = await CH.runtime.sendMessage({ type: 'poler:health' });
    if (r && r.ok) {
      cfgStatus('✅ Шлюз жив · poler_chunk ' + (r.hasChunk ? 'доступен' : 'НЕ найден') +
        '\n' + r.rpc, 'ok');
    } else {
      cfgStatus('❌ ' + ((r && r.error) || 'нет ответа') + '\nЗапущен poler-engine?', 'err');
    }
  } catch (e) {
    cfgStatus('❌ ' + String((e && e.message) || e), 'err');
  }
}

$('cfg-save').addEventListener('click', saveCfg);
$('cfg-test').addEventListener('click', testGateway);

$('foot-panel').addEventListener('click', async (e) => {
  e.preventDefault();
  if (!CH) return;
  try {
    const [tab] = await CH.tabs.query({ active: true, currentWindow: true });
    if (tab && tab.id != null) await CH.sidePanel.open({ tabId: tab.id });
  } catch (_) { /* панель недоступна — не критично */ }
});

/* ------------------------------- старт ------------------------------- */

render();
if (CH) {
  refreshDot();
  refreshCfg();
} else {
  $('dot').textContent = 'шлюз: нет chrome.* (просмотр)';
}
