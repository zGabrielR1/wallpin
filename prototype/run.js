// Harness: loads sample_feed.html (or a live-saved HTML file) into jsdom,
// runs the REAL extractor JS, applies a FilterService-equivalent, prints results.
// Usage: node run.js [htmlFile]
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');
const { EXTRACT_JS } = require('./extractor.js');

const htmlFile = process.argv[2] || path.join(__dirname, 'sample_feed.html');
const html = fs.readFileSync(htmlFile, 'utf8');

const dom = new JSDOM(html, { url: 'https://www.pinterest.com/', pretendToBeVisual: true, runScripts: 'dangerously' });
const script = dom.window.document.createElement('script');
script.textContent = 'window.__wallpin = ' + EXTRACT_JS + ';';
dom.window.document.body.appendChild(script);
const json = dom.window.__wallpin;
const pins = JSON.parse(json);

console.log(`EXTRACTED ${pins.length} pins from ${path.basename(htmlFile)}:`);
for (const p of pins) console.log(`  - id=${p.id} img=${p.img} title=${JSON.stringify(p.title)}`);

// --- FilterService equivalent (mirrors lib/services/filter_service.dart) ---
const EXCLUDE = ['meme', 'funny', 'quote', 'screenshot', 'infographic', 'chart'];
const kept = pins.filter((p) => !EXCLUDE.some((k) => (p.title || '').toLowerCase().includes(k)));
console.log(`\nAFTER exclude-filter: ${kept.length} kept (${pins.length - kept.length} dropped as meme/quote/etc)`);
for (const p of kept) console.log(`  + id=${p.id} img=${p.img}`);

// --- Assertions for the mocked feed ---
if (path.basename(htmlFile) === 'sample_feed.html') {
  const assert = require('assert');
  const ids = pins.map((p) => p.id);
  assert(ids.includes('1111111111'), 'classic pin missing');
  assert(ids.includes('2222222222'), 'srcset pin missing');
  assert(ids.includes('3333333333'), 'meme pin should still EXTRACT (filter drops it later)');
  assert.strictEqual(ids.filter((i) => i === '4444444444').length, 1, 'duplicate pin not deduped');
  assert(!ids.includes('5555555555'), 'video pin without img must be skipped');
  assert(!ids.some((i) => i === '12345'), 'non-pin /ideas/ link must be ignored');
  const p1 = pins.find((p) => p.id === '1111111111');
  assert(p1.img.includes('/236x/'), `raw thumbnail size must be preserved for downloader upgrade: ${p1.img}`);
  const p7 = pins.find((p) => p.id === '7777777777');
  assert(p7.img.includes('/originals/'), 'originals URL mangled');
  assert(!kept.some((p) => p.id === '3333333333'), 'meme pin should be FILTERED out');
  console.log('\nALL ASSERTIONS PASSED ✔  extractor + filter behave as designed.');
}
