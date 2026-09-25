// POLER WebLens — content script: подсветка термов поиска POLER
// на любой странице. TreeWalker по текстовым узлам + <mark> без
// вмешательства в разметку; стили изолированы классом poler-hl.

(() => {
  'use strict';

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
    // склейка разорванных текстовых узлов — DOM как был
    if (marks.length === 0 && document.body) {
      document.body.normalize();
    }
  }

  function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /** Видим ли узел (offsetParent есть, размер ненулевой). */
  function visible(node) {
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
    // композитный regex: термин с границей слова (unicode-aware)
    const pattern = terms
      .slice(0, 20)
      .map(escapeRe)
      .sort((a, b) => b.length - a.length)
      .join('|');
    let re;
    try {
      re = new RegExp('(?<![\\p{L}\\p{N}])(' + pattern + ')(?![\\p{L}\\p{N}])', 'giu');
    } catch {
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
      if (!visible(node)) continue;
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
      if (count > 0 || frag.childNodes.length) {
        node.parentNode.replaceChild(frag, node);
      }
    }
    return count;
  }

  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (!msg) return;
    if (msg.type === 'poler:highlight') {
      sendResponse({ count: highlightTerms(msg.terms || []) });
    } else if (msg.type === 'poler:clear') {
      clearHighlights();
      sendResponse({ ok: true });
    }
  });
})();
