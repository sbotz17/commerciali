const { chromium } = require('playwright');
const h = require('./helpers');

const BASE = process.env.AUDIT_BASE || 'http://localhost:8777/';
const NOME = 'Cliente R1 ' + Date.now().toString().slice(-5);

function riepilogo(t) {
  const m = t.match(/RIEPILOGO(.*?)Salva preventivo/s);
  return m ? m[1].replace(/\s+/g, ' ').trim() : '';
}

async function vaiAllaHome(page) {
  for (let i = 0; i < 8; i++) {
    const bottoni = await h.elencoPulsanti(page);
    if (bottoni.some(b => /Preventivi Tab 4 of 10/.test(b.testo))) return true;
    const intro = bottoni.find(b => /inizia|ho capito/i.test(b.testo));
    if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2500); continue; }
    await page.waitForTimeout(3000);
  }
  return false;
}

(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1100 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  const errori = [];
  page.on('console', m => { if (m.type() === 'error') errori.push(m.text().slice(0, 140)); });
  try {
    await page.goto(BASE, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await h.login(page);

    if (/Configura la tua azienda/.test(await h.testo(page))) {
      await h.scrivi(page, 'Il tuo nome', 'Tester R1');
      await h.scrivi(page, 'Nome azienda', 'Azienda R1 ' + Date.now().toString().slice(-4));
      await h.cliccaTesto(page, 'Crea azienda e inizia');
      out.onboarding = true;
      await page.waitForTimeout(10000);
    }
    out.home = await vaiAllaHome(page);
    if (!out.home) throw new Error('home non raggiunta: ' + (await h.testo(page)).slice(0, 120));

    await h.cliccaTesto(page, 'Clienti Tab 2 of 10');
    await page.waitForTimeout(3000);
    const nuovoCliente = (await h.elencoPulsanti(page)).find(b => /nuovo cliente/i.test(b.testo));
    await h.cliccaTesto(page, nuovoCliente.testo);
    await page.waitForTimeout(2000);
    await h.scrivi(page, 'Ragione sociale', NOME);
    await h.scrivi(page, 'CAP', '20100');
    await h.scrivi(page, 'Città', 'Milano');
    await h.cliccaTesto(page, 'Crea cliente');
    await page.waitForTimeout(4500);
    out.clienteCreato = (await h.testo(page)).includes(NOME);

    await h.cliccaTesto(page, 'Preventivi Tab 4 of 10');
    await page.waitForTimeout(3000);
    const nuovoPrev = (await h.elencoPulsanti(page)).find(b => /nuovo preventivo/i.test(b.testo));
    await h.cliccaTesto(page, nuovoPrev.testo);
    await page.waitForTimeout(3000);
    await h.cliccaTesto(page, 'Cliente Seleziona un cliente');
    await page.waitForTimeout(2500);
    await h.cliccaAria(page, NOME);
    await page.waitForTimeout(2500);
    await h.cliccaTesto(page, 'Aggiungi riga');
    await page.waitForTimeout(2500);
    await h.scrivi(page, 'Descrizione', 'Riga R1');
    await h.scrivi(page, '0,00', '100');
    await page.waitForTimeout(1200);
    out.riepilogo = riepilogo(await h.testo(page));
    await h.cliccaTesto(page, 'Salva preventivo');
    await page.waitForTimeout(6000);
    out.lista = (await h.testo(page)).slice(-200);
    out.numero = (out.lista.match(/PRV-\d+/) || [])[0] || null;

    // prova R-1: riaprire il preventivo dalla lista
    const box = await page.evaluate(() => {
      const nodi = [...document.querySelectorAll('flt-semantics')].filter(n => (n.innerText || '').includes('PRV-'));
      const foglia = nodi.filter(n => ![...n.querySelectorAll('flt-semantics')].some(c => (c.innerText || '').includes('PRV-')));
      const n = foglia[0] || nodi[nodi.length - 1];
      if (!n) return null;
      const r = n.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    out.nodoTrovato = !!box;
    if (box) await page.mouse.click(box.x, box.y);
    await page.waitForTimeout(5000);
    out.editor = (await h.testo(page)).slice(-450);
    out.riapreConDati = /Riga R1/.test(out.editor) && out.editor.includes(NOME);
    out.nonVuoto = !/Seleziona un cliente/.test(out.editor) && !/Nessuna riga/.test(out.editor);
    out.totale = (/Totale\s*([\d.,]+)\s*€/.exec(out.editor) || [])[1] || null;
  } catch (e) {
    out.error = String(e).slice(0, 250);
  } finally {
    out.errori = errori.slice(0, 4);
    await browser.close();
    require('fs').writeFileSync('/tmp/verifica-r1.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify(out, null, 2));
  }
})();
