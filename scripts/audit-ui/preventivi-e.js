const { chromium } = require('playwright');
const h = require('./helpers');

function riepilogo(t) {
  const m = t.match(/RIEPILOGO(.*?)Salva preventivo/s);
  return m ? m[1].replace(/\s+/g, ' ').trim() : '';
}

(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1100 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  try {
    await page.goto('https://commerciali-app.web.app/', { waitUntil: 'domcontentloaded', timeout: 45000 });
    await h.login(page);
    const intro = (await h.elencoPulsanti(page)).find(b => /inizia|ho capito/i.test(b.testo));
    if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2500); }
    await h.cliccaTesto(page, 'Preventivi Tab 4 of 10');
    await page.waitForTimeout(2500);
    const nuovo = (await h.elencoPulsanti(page)).find(b => /nuovo preventivo/i.test(b.testo));
    await h.cliccaTesto(page, nuovo.testo);
    await page.waitForTimeout(3000);
    await h.cliccaTesto(page, 'Cliente Seleziona un cliente');
    await page.waitForTimeout(2500);
    await h.cliccaAria(page, 'Audit Cliente 2026-10-25');
    await page.waitForTimeout(2500);

    await h.cliccaTesto(page, 'Aggiungi riga');
    await page.waitForTimeout(2500);
    await h.scrivi(page, 'Descrizione', 'Audit servizio');
    await h.scrivi(page, '0,00', '100');
    await h.scrivi(page, '0', '2');
    await page.waitForTimeout(1500);
    out.riepilogoDopoRiga = riepilogo(await h.testo(page));

    await h.cliccaTesto(page, 'Salva preventivo');
    await page.waitForTimeout(6000);
    out.listaDopoSalva = (await h.testo(page)).slice(-350);
    out.numero = (out.listaDopoSalva.match(/PRV-[A-Z0-9-]+/) || [])[0] || null;

    await page.reload({ waitUntil: 'domcontentloaded' });
    await h.abilitaSemantica(page);
    await page.waitForTimeout(4500);
    const intro2 = (await h.elencoPulsanti(page)).find(b => /inizia|ho capito/i.test(b.testo));
    if (intro2) { await h.cliccaTesto(page, intro2.testo); await page.waitForTimeout(2000); }
    await h.cliccaTesto(page, 'Preventivi Tab 4 of 10');
    await page.waitForTimeout(3000);
    out.listaDopoReload = (await h.testo(page)).slice(-350);
    out.persistito = out.numero ? out.listaDopoReload.includes(out.numero) : false;
  } catch (e) {
    out.error = String(e).slice(0, 300);
  } finally {
    await browser.close();
    require('fs').writeFileSync('/tmp/preventivi-e.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify({ riepilogo: out.riepilogoDopoRiga, numero: out.numero, persistito: out.persistito, listaDopoSalva: (out.listaDopoSalva || '').slice(-200), error: out.error }, null, 2));
  }
})();
