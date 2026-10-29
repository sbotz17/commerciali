// AU03 — duplicati per singolo campo e VIES non valida.
// Ogni caso usa un contesto browser nuovo, così il form non va chiuso.
// Richiede un utente di test dell'azienda A e il database di TEST.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const h = require('/Users/andreabotti/Documents/commerciali/scripts/audit-ui/helpers');

const BASE = process.env.AUDIT_BASE || 'https://commerciali-app.web.app/';
const API = 'AIzaSyC1u1OVQxcgHXoKx_oWq_9Rv_YUqW43da4';
const TMP = process.env.AUDIT_OUT || '/private/var/folders/7y/_z37qnm16b73jbqgc5kysdvw0000gn/T/opencode/audit';
const EVID = path.join(TMP, 'evidenze-AU03-duplicati');
fs.mkdirSync(EVID, { recursive: true });
const CRED_A = JSON.parse(fs.readFileSync(process.env.AUDIT_CRED_A || path.join(TMP, 'utente-audit-28.json')));
const PIVA = '00159560366';
const CF = 'RSSMRA80A01H501U';
const SUFFISSO = Date.now().toString().slice(-5);
const log = { suffisso: SUFFISSO, casi: [], esito: 'IN CORSO' };

function passo(nome, esito, dettaglio = '') {
  log.casi.push({ nome, esito, dettaglio });
  console.log(`${esito}\t${nome}\t${dettaglio}`);
}

async function api(url, opzioni = {}) {
  const r = await fetch(url, opzioni);
  const testo = await r.text();
  let corpo = null;
  try { corpo = testo ? JSON.parse(testo) : null; } catch (_) { corpo = testo; }
  return { status: r.status, corpo };
}

async function accediRest(cred) {
  const r = await api(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: cred.email, password: cred.password, returnSecureToken: true }),
  });
  if (r.status !== 200) throw new Error('login REST fallito');
  return { token: r.corpo.idToken, uid: r.corpo.localId };
}

async function query(token, collezione, campo, valore) {
  const q = { structuredQuery: { from: [{ collectionId: collezione }], where: { fieldFilter: { field: { fieldPath: campo }, op: 'EQUAL', value: { stringValue: valore } } }, limit: 50 } };
  const r = await api(`https://firestore.googleapis.com/v1/projects/commerciali-app/databases/(default)/documents:runQuery`, {
    method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(q),
  });
  if (r.status !== 200) throw new Error('query HTTP ' + r.status);
  return (r.corpo || []).map(x => x.document).filter(Boolean);
}

async function aziendaDi(token, uid) {
  const docs = await query(token, 'membri', 'utente_id', uid);
  if (!docs.length) throw new Error('membership assente');
  return docs[0].fields.azienda_id.stringValue;
}

function campo(doc, nome) {
  const c = doc.fields && doc.fields[nome];
  if (!c) return '';
  return c.stringValue ?? c.booleanValue ?? c.integerValue ?? '';
}

async function creaDoc(token, azienda, nome, campiExtra = {}) {
  const campi = {
    azienda_id: { stringValue: azienda },
    nome: { stringValue: nome },
    tipo_cliente: { stringValue: 'azienda' },
  };
  for (const [k, v] of Object.entries(campiExtra)) campi[k] = { stringValue: v };
  const r = await api('https://firestore.googleapis.com/v1/projects/commerciali-app/databases/(default)/documents/clienti', {
    method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: campi }),
  });
  if (r.status !== 200) throw new Error('seed HTTP ' + r.status);
  return r.corpo;
}

async function eliminaDoc(token, doc) {
  await api(`https://firestore.googleapis.com/v1/${doc.name}`, { method: 'DELETE', headers: { Authorization: 'Bearer ' + token } });
}

async function semantica(page) {
  const gia = await page.evaluate(() => { const x = document.querySelector('flt-semantics-host'); return !!(x && x.children.length); }).catch(() => false);
  if (gia) return;
  try {
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 20000 });
    await page.waitForTimeout(1000);
    await page.evaluate(() => { const p = document.querySelector('flt-semantics-placeholder'); if (!p) return; ['pointerdown','mousedown','pointerup','mouseup','click'].forEach(t => p.dispatchEvent(new MouseEvent(t, {bubbles:true,cancelable:true}))); });
  } catch (_) {}
  await page.waitForTimeout(1800);
}

async function scrivi(page, campoAria, valore) {
  const el = page.locator(`input[aria-label="${campoAria}"], textarea[aria-label="${campoAria}"]`).first();
  await el.waitFor({ state: 'attached', timeout: 15000 });
  const b = await el.boundingBox();
  if (!b) throw new Error('campo non trovato: ' + campoAria);
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  await page.waitForTimeout(300);
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(valore, { delay: 12 });
}

async function attendiTesto(page, testo, timeout = 20000) {
  const fine = Date.now() + timeout;
  while (Date.now() < fine) {
    if ((await h.testo(page).catch(() => '')).includes(testo)) return true;
    await page.waitForTimeout(800);
  }
  return false;
}

async function login(page, cred) {
  await page.goto(BASE, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(1500);
  await semantica(page);
  if (await page.locator('input[aria-label="Email"]').count()) {
    await scrivi(page, 'Email', cred.email);
    await scrivi(page, 'Password', cred.password);
    const a = page.locator('flt-semantics[role="button"]').filter({ hasText: /^Accedi$/ }).first();
    const b = await a.boundingBox();
    await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(12000);
  }
  for (let i = 0; i < 4; i++) {
    await semantica(page);
    const intro = (await h.elencoPulsanti(page)).find(x => /inizia|ho capito/i.test(x.testo));
    if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(5000); continue; }
    if ((await h.testo(page)).includes('Dashboard')) return true;
    await page.waitForTimeout(2000);
  }
  return false;
}

async function vaiClienti(page) {
  await page.goto(BASE + 'clienti', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(1500);
  await semantica(page);
  await attendiTesto(page, 'Clienti', 15000);
  await page.waitForTimeout(2000);
}

async function apriNuovo(page) {
  await h.cliccaTesto(page, 'Nuovo cliente');
  await page.waitForTimeout(2500);
}

async function caso(token, azienda, nomeCaso, prepara, compila) {
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1100 }, locale: 'it-IT', serviceWorkers: 'block' });
  const page = await ctx.newPage();
  try {
    if (prepara) await prepara();
    if (!(await login(page, CRED_A))) throw new Error('login non riuscito');
    await vaiClienti(page);
    await apriNuovo(page);
    await compila(page);
    await page.screenshot({ path: path.join(EVID, `${nomeCaso}.png`), fullPage: true });
    passo(nomeCaso, 'OK');
  } catch (e) {
    passo(nomeCaso, 'FALLITA', String(e).slice(0, 250));
    await page.screenshot({ path: path.join(EVID, `${nomeCaso}-errore.png`), fullPage: true }).catch(() => {});
  } finally { await browser.close(); }
}

(async () => {
  let auth = null;
  let az = null;
  try {
    auth = await accediRest(CRED_A);
    az = await aziendaDi(auth.token, auth.uid);

    // Pulizia iniziale
    for (const doc of (await query(auth.token, 'clienti', 'azienda_id', az)).filter(d => campo(d, 'nome').startsWith('AU03 '))) {
      await eliminaDoc(auth.token, doc);
    }

    // 1. Duplicato per sola P.IVA
    await caso(auth.token, az, 'dup-piva', async () => {
      if (process.env.AU03_DUP_ROMPI !== '1') {
        await creaDoc(auth.token, az, `AU03 Base PIVA ${SUFFISSO}`, { piva: PIVA });
      }
    }, async (page) => {
      await scrivi(page, 'Ragione sociale', `AU03 Dup PIVA ${SUFFISSO}`);
      await scrivi(page, 'Partita IVA', PIVA);
      await h.cliccaTesto(page, 'Crea cliente');
      if (!(await attendiTesto(page, 'Esiste già un cliente', 8000))) throw new Error('duplicato P.IVA non bloccato');
    });

    // 1b. Duplicato con P.IVA formattata (IT, spazi, punti)
    await caso(auth.token, az, 'dup-piva-formattata', async () => {
      if (process.env.AU03_DUP_ROMPI !== '1' && process.env.AU03_FMT_ROMPI !== '1') {
        await creaDoc(auth.token, az, `AU03 Base PIVA FMT ${SUFFISSO}`, { piva: '01879020517' });
      }
    }, async (page) => {
      await scrivi(page, 'Ragione sociale', `AU03 Dup PIVA FMT ${SUFFISSO}`);
      await scrivi(page, 'Partita IVA', 'IT 018 790 205 17');
      await h.cliccaTesto(page, 'Crea cliente');
      if (!(await attendiTesto(page, 'Esiste già un cliente', 8000))) throw new Error('duplicato P.IVA formattata non bloccato');
    });

    // 2. Duplicato per solo nome
    await caso(auth.token, az, 'dup-nome', async () => {
      await creaDoc(auth.token, az, `AU03 Base Nome ${SUFFISSO}`);
    }, async (page) => {
      await scrivi(page, 'Ragione sociale', `AU03 Base Nome ${SUFFISSO}`);
      await h.cliccaTesto(page, 'Crea cliente');
      if (!(await attendiTesto(page, 'Esiste già un cliente', 8000))) throw new Error('duplicato nome non bloccato');
    });

    // 3. Duplicato per solo codice fiscale
    await caso(auth.token, az, 'dup-cf', async () => {
      await creaDoc(auth.token, az, `AU03 Base CF ${SUFFISSO}`, { codice_fiscale: CF });
    }, async (page) => {
      await scrivi(page, 'Ragione sociale', `AU03 Dup CF ${SUFFISSO}`);
      await scrivi(page, 'Codice fiscale', CF);
      await h.cliccaTesto(page, 'Crea cliente');
      if (!(await attendiTesto(page, 'Esiste già un cliente', 8000))) throw new Error('duplicato CF non bloccato');
    });

    // 4. VIES non valida: modale informativa, cliente invariato
    await caso(auth.token, az, 'vies-non-valida', null, async (page) => {
      const nome = `AU03 VIES ${SUFFISSO}`;
      await scrivi(page, 'Ragione sociale', nome);
      await scrivi(page, 'Partita IVA', '00000000000');
      await h.cliccaTesto(page, 'Verifica P.IVA');
      if (!(await attendiTesto(page, 'P.IVA non valida', 25000))) throw new Error('VIES non valida non mostrata');
      const chiudi = (await h.elencoPulsanti(page)).find(b => /^Chiudi$/i.test(b.testo));
      if (chiudi) { await h.cliccaTesto(page, 'Chiudi'); await page.waitForTimeout(1200); }
      // Se la modale avesse svuotato il nome, il salvataggio fallirebbe con
      // "Inserisci il nome del cliente". Salviamo e verifichiamo il nome reale.
      await h.cliccaTesto(page, 'Crea cliente');
      await page.waitForTimeout(6000);
      const docs = (await query(auth.token, 'clienti', 'azienda_id', az)).filter(d => campo(d, 'nome') === nome);
      if (docs.length !== 1) throw new Error('la modale VIES ha modificato il nome o il salvataggio è fallito');
    });

    log.esito = log.casi.every(c => c.esito === 'OK') ? 'PROVATA' : 'FALLITA';
  } catch (e) {
    log.esito = 'FALLITA';
    log.errore = String(e).slice(0, 400);
    passo('esecuzione', 'FALLITA', log.errore);
  } finally {
    if (auth && az) {
      try {
        const residui = (await query(auth.token, 'clienti', 'azienda_id', az)).filter(d => {
          const nome = campo(d, 'nome');
          return nome.startsWith('AU03 ') || nome.startsWith('Audit Cliente');
        });
        for (const doc of residui) await eliminaDoc(auth.token, doc);
        passo('pulizia finale', 'OK', `${residui.length} clienti rimossi`);
      } catch (e) {
        passo('pulizia finale', 'FALLITA', String(e).slice(0, 150));
        log.esito = 'FALLITA';
      }
    }
    fs.writeFileSync(path.join(EVID, 'esito.json'), JSON.stringify(log, null, 2));
    if (log.esito !== 'PROVATA') process.exitCode = 1;
    console.log(JSON.stringify({ esito: log.esito, errore: log.errore || null }, null, 2));
  }
})();
