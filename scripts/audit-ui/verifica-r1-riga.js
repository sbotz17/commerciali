const { chromium } = require('playwright');
const h = require('./helpers');
(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1100 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  try {
    await page.goto(process.env.AUDIT_BASE, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await h.login(page);
    for (let i = 0; i < 6; i++) {
      const b = await h.elencoPulsanti(page);
      const intro = b.find(x => /inizia|ho capito/i.test(x.testo));
      if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2500); continue; }
      if (b.some(x => /Preventivi Tab 4 of 10/.test(x.testo))) break;
      await page.waitForTimeout(2500);
    }
    await h.cliccaTesto(page, 'Preventivi Tab 4 of 10');
    await page.waitForTimeout(3500);
    const box = await page.evaluate(() => {
      const nodi = [...document.querySelectorAll('flt-semantics')].filter(n => (n.innerText || '').includes('PRV-'));
      const foglia = nodi.filter(n => ![...n.querySelectorAll('flt-semantics')].some(c => (c.innerText || '').includes('PRV-')));
      const n = foglia[0] || nodi[nodi.length - 1];
      const r = n.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    await page.mouse.click(box.x, box.y);
    await page.waitForTimeout(5000);
    out.titolo = (await h.testo(page)).slice(-420);
    out.descrizione = await page.evaluate(() => {
      const i = [...document.querySelectorAll('flt-semantics input')].find(x => x.getAttribute('aria-label') === 'Descrizione');
      return i ? i.value : 'campo assente';
    });
    out.esito = /Modifica preventivo/.test(out.titolo) && /PRV-0001/.test(out.titolo);
  } catch (e) { out.error = String(e).slice(0, 200); }
  finally { await browser.close(); console.log(JSON.stringify(out, null, 2)); }
})();
