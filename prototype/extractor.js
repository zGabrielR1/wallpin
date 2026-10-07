// Exact copy of PinterestScraper._extractJs from
// lib/services/pinterest_scraper.dart — the prototype tests THIS string.
const EXTRACT_JS = `
(() => {
  const out = [];
  const seen = new Set();
  document.querySelectorAll('a[href*="/pin/"]').forEach(a => {
    const m = a.href.match(/\\/pin\\/(\\d+)/);
    if (!m) return;
    const id = m[1];
    if (seen.has(id)) return;
    seen.add(id);
    const img = a.querySelector('img');
    if (!img) return;
    let src = img.currentSrc || img.src || '';
    // NOTE: keep the RAW thumbnail URL here. The originals-upgrade happens
    // in WallpaperService with fallback ('/originals/' 403s for ~25% of pins).
    const title = img.alt || '';
    out.push({id, img: src, title, w: img.naturalWidth || 0, h: img.naturalHeight || 0});
  });
  return JSON.stringify(out);
})()
`;
module.exports = { EXTRACT_JS };
