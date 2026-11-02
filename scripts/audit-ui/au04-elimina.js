const { chromium } = require('playwright');
const h = require('./helpers');
(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1300 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  try {
    await page.goto(process.env.AUDIT_BASE, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await h.login(page);
    for (let i = 0; i < 8; i++) {
      const t = await h.testo(page);
      if (/Dashboard Scheda/.test(t)) break;
      const b = (await h.elencoPulsanti(page)).find(x => /inizia|ho capito/i.test(x.testo));
      if (b) { await h.cliccaTesto(page, b.testo); await page.waitForTimeout(3500); } else await page.waitForTimeout(2500);
    }
    await h.cliccaTesto(page, 'Catalogo Scheda 3 di 10');
    await page.waitForTimeout(2800);

    const az = page.locator('flt-semantics[role="button"]', { hasText: 'Azioni prodotto' }).last();
    const b = await az.boundingBox();
    await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
    await page.mouse.down(); await page.mouse.up();
    await page.waitForTimeout(1800);
    const elim = await page.evaluate(() => {
      const n = [...document.querySelectorAll('flt-semantics[role="menuitem"]')].find(x => (x.getAttribute('aria-label') || '') === 'Elimina');
      if (!n) return null;
      const r = n.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    out.trovatoElimina = !!elim;
    if (elim) {
      await page.mouse.click(elim.x, elim.y);
      await page.waitForTimeout(2200);
      out.dialogo = (await h.testo(page)).slice(-260);
      const m = out.dialogo.match(/Il prodotto "([^"]+)"/);
      out.prodottoEliminato = m ? m[1] : null;
      const conferma = (await h.elencoPulsanti(page)).find(x => /elimina/i.test(x.testo));
      out.bottoneConferma = conferma ? conferma.testo : null;
      if (conferma) {
        await h.cliccaTesto(page, conferma.testo);
        await page.waitForTimeout(3500);
      }
    }
    const lista = await h.testo(page);
    out.ancoraPresente = out.prodottoEliminato ? lista.includes(out.prodottoEliminato) : null;
    out.eliminato = out.prodottoEliminato ? !out.ancoraPresente : false;
    out.numeroProdotti = (lista.match(/Prodotto AU04/g) || []).length;

    // elimina anche la categoria
    await h.cliccaAria(page, 'Categorie');
    await page.waitForTimeout(2500);
    const azc = page.locator('flt-semantics[role="button"]', { hasText: 'Azioni categoria' }).last();
    const bc = await azc.boundingBox();
    await page.mouse.move(bc.x + bc.width / 2, bc.y + bc.height / 2);
    await page.mouse.down(); await page.mouse.up();
    await page.waitForTimeout(1600);
    const elimC = await page.evaluate(() => {
      const n = [...document.querySelectorAll('flt-semantics[role="menuitem"]')].find(x => (x.getAttribute('aria-label') || '') === 'Elimina');
      if (!n) return null;
      const r = n.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    out.trovatoEliminaCategoria = !!elimC;
    if (elimC) {
      await page.mouse.click(elimC.x, elimC.y);
      await page.waitForTimeout(2000);
      const conf = (await h.elencoPulsanti(page)).find(x => /elimina/i.test(x.testo));
      if (conf) { await h.cliccaTesto(page, conf.testo); await page.waitForTimeout(3000); }
    }
    out.categoriaAncora = (await h.testo(page)).includes('Categoria AU04');
  } catch (e) { out.error = String(e).slice(0, 220); }
  finally { await browser.close(); console.log(JSON.stringify(out, null, 2)); }
})();
