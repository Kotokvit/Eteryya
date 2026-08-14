Архитектура и интеграция z-ai-web-dev-sdk в poler_toolkit
1. АРХИТЕКТУРА z-ai-web-dev-sdk
Всё MUCH проще чем кажется. SDK — это тонкая HTTP-обёртка (494 строки). Вся магия на сервере.
Единая точка входа:
text
POST {baseUrl}/functions/invoke
Body: {"function_name": "web_search", "arguments": {"query": "...", "num": 10}}
Headers: Authorization: Bearer {apiKey}, X-Z-AI-From: Z
Конфиг: /etc/.z-ai-config — простой JSON:
json
{"baseUrl": "https://internal-api.z.ai/v1", "apiKey": "sk-..."}
--------------------------------------------------------------------------------
2. ИСХОДНЫЙ КОД — полный SDK (index.js, 494 строки)
Это весь SDK. Я его прочитал целиком:
javascript
// /home/z/.bun/install/global/node_modules/z-ai-web-dev-sdk/dist/index.js
// 494 строки — полный файл
import fs from 'fs/promises';
import path from 'path';
import os from 'os';
const loadConfig = async () => {
const homeDir = os.homedir();
const configPaths = [
path.join(process.cwd(), '.z-ai-config'),
path.join(homeDir, '.z-ai-config'),
'/etc/.z-ai-config'
];
for (const filePath of configPaths) {
try {
const configStr = await fs.readFile(filePath, 'utf-8');
const config = JSON.parse(configStr);
if (config.baseUrl && config.apiKey) {
return config;
}
} catch (error) { /* continue */ }
}
throw new Error('Configuration file not found');
};
class ZAI {
constructor(config) {
this.config = config;
// ... все методы (chat, audio, images, video, functions) через bind
this.functions = {
invoke: this.invokeFunction.bind(this),
};
}
static async create() {
const config = await loadConfig();
return new ZAI(config);
}
// ===== ЕДИНСТВЕННЫЙ МЕТОД ДЛЯ web_search И page_reader =====
async invokeFunction(function_name, args) {
const { baseUrl, apiKey } = this.config;
const url = `${baseUrl}/functions/invoke`;
const headers = {
'Content-Type': 'application/json',
'Authorization': `Bearer ${apiKey}`,
'X-Z-AI-From': 'Z',
};
const body = { function_name, arguments: args };
const response = await fetch(url, {
method: 'POST',
headers,
body: JSON.stringify(body),
});
const result = await response.json();
return result.result; // ← сервер оборачивает в {result: ...}
}
}
Всё. web_search и page_reader — это просто разные function_name. Логика на сервере.
--------------------------------------------------------------------------------
3. ИСХОДНЫЙ КОД — скрипт web_search.ts (44 строки)
typescript
// /home/z/my-project/skills/web-search/scripts/web_search.ts
import ZAI from 'z-ai-web-dev-sdk';
interface SearchFunctionResultItem {
url: string;
name: string;
snippet: string;
host_name: string;
rank: number;
date: string;
favicon: string;
}
async function main(query: string, num: number = 10) {
const zai = await ZAI.create();
const searchResult = await zai.functions.invoke('web_search', {
query: query,
num: num
});
// searchResult — массив SearchFunctionResultItem
searchResult.forEach((item, index) => {
console.log(`${index + 1}. ${item.name}`);
console.log(` URL: ${item.url}`);
console.log(` Snippet: ${item.snippet}`);
});
}
main('What is the capital of France?', 5);
--------------------------------------------------------------------------------
4. ИСХОДНЫЙ КОД — скрипт web-reader.ts (37 строк)
typescript
// /home/z/my-project/skills/web-reader/scripts/web-reader.ts
import ZAI from 'z-ai-web-dev-sdk';
interface PageReaderFunctionResult {
code: number;
data: {
html: string;
publishedTime?: string;
title: string;
url: string;
};
status: number;
}
async function main(url: string) {
const zai = await ZAI.create();
const results = await zai.functions.invoke('page_reader', {
url: url
});
// results.data.html — полный HTML страницы
// results.data.title — заголовок
}
main('https://www.google.com');
--------------------------------------------------------------------------------
5. КАК ИНТЕГРИРОВАТЬ В poler_toolkit
Ключевое: из Python это делается через urllib.request — zero dependencies, идеально для poler_v6.py:
python
# ЭТО ВСЁ ЧТО НУЖНО — чистый Python, без pip install
import json, urllib.request, re, os
def _load_zai_config():
for p in ['.z-ai-config',
os.path.expanduser('~/.z-ai-config'),
'/etc/.z-ai-config']:
if os.path.exists(p):
with open(p) as f:
return json.load(f)
return None
def _invoke(function_name, args):
cfg = _load_zai_config()
base = cfg['baseUrl'].rstrip('/')
body = json.dumps({
'function_name': function_name,
'arguments': args
}).encode()
headers = {
'Content-Type': 'application/json',
'Authorization': f'Bearer {cfg["apiKey"]}',
'X-Z-AI-From': 'Z',
}
req = urllib.request.Request(
f'{base}/functions/invoke',
data=body, headers=headers, method='POST'
)
with urllib.request.urlopen(req, timeout=30) as resp:
r = json.loads(resp.read())
return r.get('result', r)
def web_search(query, num=10):
return _invoke('web_search', {'query': query, 'num': num})
# → [{url, name, snippet, host_name, rank, date, favicon}]
def page_reader(url):
return _invoke('page_reader', {'url': url})
# → {code, data: {html, title, publishedTime}, status}
def html_to_text(html):
text = re.sub(r'