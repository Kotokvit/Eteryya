// POLER WebLens — side panel: поиск по общему индексу движка,
// захват текущей страницы, подсветка терминов результата.

const $ = (id) => document.getElementById(id);
const resultsEl = $('results');

/** Статус демона движка (GET /health без токена — smoke-проба). */
async function checkStatus() {
  const el = $('status');
  try {
    const cfg = await fetch(chrome.runtime.getURL('config.json')).then((r) => r.json());
    const res = await fetch(cfg.endpoint.replace(/\/$/, '') + '/health', {
      method: 'GET',
    });
    el.textContent = res.ok ? 'движок: на связи' : 'движок: нет ответа';
    el.className = 'status ' + (res.ok ? 'online' : 'offline');
  } catch {
    el.textContent = 'движок: офлайн (запустите --web-lens)';
    el.className = 'status offline';
  }
}

/** tools/call через service worker (релей: без CORS-зависимости). */
function mcp(tool, args) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendMessage({ type: 'poler:mcp', tool, args }, (resp) => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
      } else if (resp && resp.ok) {
        resolve(resp.text);
      } else {
        reject(new Error(resp ? resp.error : 'нет ответа'));
      }
    });
  });
}

/** Разбор текста poler_web_search:
 *  "poler web-search «q»: N из M страниц\n\n1. [score] url — title\n   snippet\n\n…" */
function parseHits(text) {
  const hits = [];
  let pages = null;
  const head = text.match(/:\s*(\d+)\s*из\s*(\d+)\s*страниц/);
  if (head) pages = head[2];
  const re = /^(\d+)\.\s*\[([\d.]+)\]\s+(\S+)\s*—\s*(.*)$|^\s{3,}(.+)$/gm;
  let m;
  let cur = null;
  while ((m = re.exec(text)) !== null) {
    if (m[3]) {
      cur = { score: m[2], url: m[3], title: m[4] || '-', snippet: '' };
      hits.push(cur);
    } else if (cur && m[5]) {
      cur.snippet = m[5].trim();
    }
  }
  return { hits, pages };
}

/** Термы запроса → подсветка на активной вкладке. */
async function highlightTerms(query) {
  const terms = (query.match(/[\p{L}\p{N}]{2,}/gu) || []).slice(0, 20);
  if (!terms.length) return 0;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !/^https?:/.test(tab.url || '')) return 0;
  return new Promise((resolve) => {
    chrome.tabs.sendMessage(tab.id, { type: 'poler:highlight', terms }, (resp) => {
      if (chrome.runtime.lastError) resolve(0);
      else resolve(resp ? resp.count : 0);
    });
  });
}

async function clearHighlight() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab) return;
  chrome.tabs.sendMessage(tab.id, { type: 'poler:clear' }, () => {
    void chrome.runtime.lastError; // вкладка без content script — не ошибка
  });
}

function renderHits(query, text) {
  const { hits, pages } = parseHits(text);
  if (pages !== null) $('pages').textContent = 'в индексе: ' + pages + ' стр.';
  resultsEl.innerHTML = '';
  if (!hits.length) {
    const d = document.createElement('div');
    d.className = 'hint';
    d.textContent = text.trim() || 'Ничего не найдено.';
    resultsEl.appendChild(d);
    return;
  }
  for (const h of hits) {
    const box = document.createElement('div');
    box.className = 'hit';

    const top = document.createElement('div');
    top.className = 'hit-top';
    const score = document.createElement('span');
    score.className = 'score';
    score.textContent = h.score;
    top.appendChild(score);
    const title = document.createElement('span');
    title.className = 'title';
    title.textContent = h.title;
    top.appendChild(title);
    box.appendChild(top);

    const url = document.createElement('a');
    url.className = 'url';
    url.href = h.url;
    url.textContent = h.url;
    url.addEventListener('click', (e) => {
      e.preventDefault();
      chrome.tabs.create({ url: h.url });
    });
    box.appendChild(url);

    if (h.snippet) {
      const sn = document.createElement('div');
      sn.className = 'snippet';
      sn.textContent = h.snippet;
      box.appendChild(sn);
    }

    const act = document.createElement('div');
    act.className = 'hit-actions';
    const hl = document.createElement('button');
    hl.textContent = ' подсветить на странице';
    hl.addEventListener('click', async () => {
      const n = await highlightTerms(query);
      hl.textContent = n > 0 ? ' подсвечено: ' + n : ' нет совпадений';
    });
    act.appendChild(hl);
    box.appendChild(act);

    resultsEl.appendChild(box);
  }
}

async function doSearch() {
  const query = $('q').value.trim();
  if (!query) return;
  $('go').disabled = true;
  resultsEl.innerHTML = '';
  const busy = document.createElement('div');
  busy.className = 'busy';
  busy.textContent = 'резонансный поиск…';
  resultsEl.appendChild(busy);
  try {
    const text = await mcp('poler_web_search', { query, top: 15 });
    renderHits(query, text);
    await highlightTerms(query);
  } catch (e) {
    resultsEl.innerHTML = '';
    const err = document.createElement('div');
    err.className = 'err';
    err.textContent = String(e.message || e);
    resultsEl.appendChild(err);
  } finally {
    $('go').disabled = false;
  }
}

/** Захват: текущая страница → общий индекс (respect_robots=false —
 *  явная команда пользователя; движок честно пишет это в audit-notes). */
async function doCapture() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !/^https?:/.test(tab.url || '')) {
    alert('Откройте обычную веб-страницу (http/https) — текущая не индексируется.');
    return;
  }
  const btn = $('capture');
  btn.disabled = true;
  btn.textContent = '⟕ индексирую…';
  try {
    const text = await mcp('poler_crawl', {
      seed_url: tab.url,
      depth: 0,
      max_pages: 1,
      respect_robots: false,
      page_timeout_ms: 45000,
    });
    btn.textContent = '✓ страница в индексе';
    $('pages').textContent = '';
    // поиск сразу по заголовку вкладки — юзер видит результат захвата
    const t = (tab.title || '').split(/[\s—–:]+/).filter((w) => w.length > 3)[0];
    if (t) {
      $('q').value = t;
      await doSearch();
    }
  } catch (e) {
    btn.textContent = '⟕ Индексировать эту страницу';
    alert('Захват не удался: ' + (e.message || e));
  } finally {
    setTimeout(() => {
      btn.disabled = false;
      btn.textContent = '⟕ Индексировать эту страницу';
    }, 2500);
  }
}

$('go').addEventListener('click', doSearch);
$('q').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') doSearch();
});
$('capture').addEventListener('click', doCapture);
$('clear').addEventListener('click', clearHighlight);

checkStatus();
setInterval(checkStatus, 15000);
