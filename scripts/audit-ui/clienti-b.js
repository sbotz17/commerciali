const { chromium } = require('playwright');
const h = require('./helpers');

const NOME = process.env.AUDIT_CLIENTE || 'Audit Cliente 2026-10-25';
const PIVA = process.env.AUDIT_PIVA || '00159560366';

(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 900 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  try {
    await page.goto(process.env.AUDIT_BASE || 'https://commerciali-app.web.app/', { waitUntil: 'domcontentloaded', timeout: 45000 });
    await h.login(page);
    const intro = (await h.elencoPulsanti(page)).find(b => /inizia|ho capito/i.test(b.testo));
    if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2500); }

    await h.cliccaTesto(page, 'Clienti Tab 2 of 10');
    await page.waitForTimeout(2000);

    const apriNuovo = async () => {
      const b = (await h.elencoPulsanti(page)).find(x => /nuovo cliente/i.test(x.testo));
      await h.cliccaTesto(page, b.testo);
      await page.waitForTimeout(2000);
    };

    // --- creazione ---
    await apriNuovo();
    await h.scrivi(page, 'Ragione sociale', NOME);
    await h.scrivi(page, 'Partita IVA', PIVA);
    await h.scrivi(page, 'Email', 'audit@example.com');
    out.step = 'compilato';
    await h.cliccaTesto(page, 'Crea cliente');
    await page.waitForTimeout(4000);
    out.dopoSalvataggio = (await h.testo(page)).slice(0, 300);
    out.creato = (await h.testo(page)).includes(NOME);
    out.step = 'salvato';

    // --- persistenza dopo ricarica ---
    await page.reload({ waitUntil: 'domcontentloaded' });
    await h.abilitaSemantica(page);
    await page.waitForTimeout(4000);
    const introDopo = (await h.elencoPulsanti(page)).find(b => /inizia|ho capito/i.test(b.testo));
    if (introDopo) { await h.cliccaTesto(page, introDopo.testo); await page.waitForTimeout(2000); }
    await h.cliccaTesto(page, 'Clienti Tab 2 of 10');
    await page.waitForTimeout(2500);
    out.dopoReload = (await h.testo(page)).slice(0, 300);
    out.persistito = (await h.testo(page)).includes(NOME);

    // --- duplicato ---
    await apriNuovo();
    await h.scrivi(page, 'Ragione sociale', NOME);
    await h.cliccaTesto(page, 'Crea cliente');
    await page.waitForTimeout(3500);
    out.duplicatoTesto = (await h.testo(page)).slice(0, 350);
    out.avvisoDuplicato = /duplicat|esiste già|già presente/i.test(out.duplicatoTesto);
    out.step = 'duplicato-provato';
  } catch (e) {
    out.error = String(e).slice(0, 400);
  } finally {
    await browser.close();
    require('fs').writeFileSync('/tmp/clienti-b.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify(out, null, 2).slice(0, 2500));
  }
})();
