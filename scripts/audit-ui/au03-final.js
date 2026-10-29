// AU03 — Clienti: prova E2E completa (creazione, VIES, ricerca, duplicato, modifica,
// persistenza, negativo, isolamento, eliminazione).
// Richiede due utenti di test (azienda A e azienda B) e il database di TEST.
// Uso: AUDIT_CRED_A=... AUDIT_CRED_B=... node au03-final.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const h = require('/Users/andreabotti/Documents/commerciali/scripts/audit-ui/helpers');

const BASE = process.env.AUDIT_BASE || 'https://commerciali-app.web.app/';
const API = 'AIzaSyC1u1OVQxcgHXoKx_oWq_9Rv_YUqW43da4';
const TMP = process.env.AUDIT_OUT || '/private/var/folders/7y/_z37qnm16b73jbqgc5kysdvw0000gn/T/opencode/audit';
const EVID = path.join(TMP, 'evidenze-AU03-final');
fs.mkdirSync(EVID, { recursive: true });
const CRED_A = JSON.parse(fs.readFileSync(process.env.AUDIT_CRED_A || path.join(TMP, 'utente-audit-28.json')));
const CRED_B = JSON.parse(fs.readFileSync(process.env.AUDIT_CRED_B || path.join(TMP, 'utente-b-29.json')));
const NOME = `AU03 Cliente ${Date.now().toString().slice(-5)}`;
const PIVA = '00159560366';
const TEL = '029999888';
const TEL_MOD = '029999777';
const TEL_ATTESO = process.env.AU03_TEL_ATTESO || TEL_MOD;
const log = { nome: NOME, passi: [], esito: 'IN CORSO' };

function passo(nome, esito, dettaglio = '') {
  log.passi.push({ nome, esito, dettaglio });
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
  if (r.status !== 200) throw new Error('login REST fallito: ' + r.status);
  return { token: r.corpo.idToken, uid: r.corpo.localId };
}

async function query(token, collezione, campo, valore) {
  const q = { structuredQuery: { from: [{ collectionId: collezione }], where: { fieldFilter: { field: { fieldPath: campo }, op: 'EQUAL', value: { stringValue: valore } } }, limit: 50 } };
  const r = await api(`https://firestore.googleapis.com/v1/projects/commerciali-app/databases/(default)/documents:runQuery`, {
    method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(q),
  });
  if (r.status !== 200) throw new Error('query ' + collezione + ' HTTP ' + r.status + ': ' + JSON.stringify(r.corpo).slice(0, 200));
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

async function clientiDi(token, azienda) {
  return query(token, 'clienti', 'azienda_id', azienda);
}

async function creaClienteRest(token, azienda, nome, codiceFiscale) {
  const campi = {
    azienda_id: { stringValue: azienda },
    nome: { stringValue: nome },
    tipo_cliente: { stringValue: 'azienda' },
    codice_fiscale: { stringValue: codiceFiscale },
  };
  const r = await api('https://firestore.googleapis.com/v1/projects/commerciali-app/databases/(default)/documents/clienti', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: campi }),
  });
  if (r.status !== 200) throw new Error('seed cliente HTTP ' + r.status);
  return r.corpo;
}

async function eliminaDoc(token, doc) {
  const r = await api(`https://firestore.googleapis.com/v1/${doc.name}`, { method: 'DELETE', headers: { Authorization: 'Bearer ' + token } });
  if (r.status !== 200) throw new Error('delete ' + doc.name + ' HTTP ' + r.status);
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

async function login(page, cred) {
  await page.goto(BASE, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(1500);
  await semantica(page);
  if (await page.locator('input[aria-label="Email"]').count()) {
    await scrivi(page, 'Email', cred.email);
    await scrivi(page, 'Password', cred.password);
    const accedi = page.locator('flt-semantics[role="button"]').filter({ hasText: /^Accedi$/ }).first();
    const b = await accedi.boundingBox();
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
  await page.waitForTimeout(1500);
}

async function chiudiForm(page) {
  await page.mouse.click(112, 84);
  await page.waitForTimeout(2500);
  await semantica(page);
  if (await page.locator('input[aria-label="Ragione sociale"]').count()) {
    const annulla = page.locator('flt-semantics[role="button"]').filter({ hasText: /^Annulla$/ }).last();
    const b = await annulla.boundingBox();
    if (b) await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(2000);
  }
  if (await page.locator('input[aria-label="Ragione sociale"]').count()) {
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);
    await semantica(page);
  }
}

async function attendiTesto(page, testo, timeout = 20000) {
  const fine = Date.now() + timeout;
  while (Date.now() < fine) {
    if ((await h.testo(page).catch(() => '')).includes(testo)) return true;
    await page.waitForTimeout(800);
  }
  return false;
}

async function attendiCella(page, testo, timeout = 20000) {
  const fine = Date.now() + timeout;
  while (Date.now() < fine) {
    const n = await page.locator('flt-semantics[role="cell"], flt-semantics[role="row"]').filter({ hasText: testo }).count().catch(() => 0);
    if (n > 0) return true;
    await page.waitForTimeout(800);
  }
  return false;
}

async function cerca(page, testo) {
  const input = page.locator('input').first();
  await input.waitFor({ state: 'attached', timeout: 15000 });
  const b = await input.boundingBox();
  if (!b) throw new Error('campo Cerca non trovato');
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  await page.waitForTimeout(300);
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(testo, { delay: 12 });
  await page.waitForTimeout(2500);
}

async function cliccaCella(page, nome) {
  const cella = page.locator('flt-semantics[role="cell"]').filter({ hasText: nome }).first();
  await cella.waitFor({ state: 'attached', timeout: 15000 });
  const b = await cella.boundingBox();
  if (!b) throw new Error('riga non cliccabile: ' + nome);
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  await page.waitForTimeout(3000);
}

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctxA = await browser.newContext({ viewport: { width: 1400, height: 1100 }, locale: 'it-IT', serviceWorkers: 'block' });
  const page = await ctxA.newPage();
  let authA = null;
  let azA = null;
  try {
    authA = await accediRest(CRED_A);
    azA = await aziendaDi(authA.token, authA.uid);
    const authB = await accediRest(CRED_B);
    const azB = await aziendaDi(authB.token, authB.uid);
    log.aziendaA = azA; log.aziendaB = azB;

    // Pulizia dei clienti di prova AU03 della sola azienda A (database di test).
    const esistenti = await clientiDi(authA.token, azA);
    let puliti = 0;
    for (const doc of esistenti) {
      if (campo(doc, 'nome').startsWith('AU03 ') || campo(doc, 'nome').startsWith('Audit Cliente')) { await eliminaDoc(authA.token, doc); puliti++; }
    }
    passo('pulizia dati di prova AU03', 'OK', `${puliti} clienti rimossi`);

    if (!(await login(page, CRED_A))) throw new Error('login A non riuscito');
    passo('login A', 'OK');
    await vaiClienti(page);

    // Creazione + VIES
    await h.cliccaTesto(page, 'Nuovo cliente');
    await page.waitForTimeout(2500);
    await scrivi(page, 'Ragione sociale', NOME);
    await scrivi(page, 'Partita IVA', PIVA);
    await scrivi(page, 'Email', 'au03@example.it');
    await scrivi(page, 'Telefono', TEL);
    await h.cliccaTesto(page, 'Verifica P.IVA');
    const vies = await attendiTesto(page, 'P.IVA valida', 25000);
    const ferrari = vies ? await attendiTesto(page, 'FERRARI', 10000) : false;
    passo('VIES P.IVA valida', vies && ferrari ? 'OK' : 'FALLITA', vies ? (ferrari ? 'FERRARI S.P.A.' : 'ragione sociale non mostrata') : 'nessun esito');
    await page.screenshot({ path: path.join(EVID, '01-vies.png'), fullPage: true });
    const chiudi = (await h.elencoPulsanti(page)).find(b => /^Chiudi$/i.test(b.testo));
    if (chiudi) { await h.cliccaTesto(page, 'Chiudi'); await page.waitForTimeout(1500); }
    await h.cliccaTesto(page, 'Crea cliente');
    await page.waitForTimeout(6000);

    let docs = (await clientiDi(authA.token, azA)).filter(d => campo(d, 'nome') === NOME);
    if (docs.length !== 1) throw new Error('cliente non creato in Firestore: ' + docs.length);
    if (campo(docs[0], 'piva') !== PIVA) throw new Error('P.IVA errata in Firestore');
    passo('creazione cliente', 'OK', `${NOME} in Firestore`);
    await page.screenshot({ path: path.join(EVID, '02-creato.png'), fullPage: true });

    // Ricerca in UI
    await cerca(page, NOME);
    if (!(await attendiCella(page, NOME, 15000))) throw new Error('ricerca non mostra il cliente');
    passo('ricerca', 'OK');

    // Duplicato: stesso nome e P.IVA
    await h.cliccaTesto(page, 'Nuovo cliente');
    await page.waitForTimeout(2500);
    await scrivi(page, 'Ragione sociale', NOME);
    await scrivi(page, 'Partita IVA', PIVA);
    await h.cliccaTesto(page, 'Crea cliente');
    await page.waitForTimeout(5000);
    const dup = await h.testo(page).then(t => t.includes('Esiste già un cliente')).catch(() => false);
    docs = (await clientiDi(authA.token, azA)).filter(d => campo(d, 'nome') === NOME);
    if (!dup || docs.length !== 1) throw new Error('duplicato non bloccato: avviso=' + dup + ' docs=' + docs.length);
    passo('duplicato bloccato', 'OK');
    await page.screenshot({ path: path.join(EVID, '03-duplicato.png'), fullPage: true });
    await h.cliccaTesto(page, 'Annulla');
    await page.waitForTimeout(2500);

    // Modifica telefono
    await cerca(page, NOME);
    await cliccaCella(page, NOME);
    await scrivi(page, 'Telefono', TEL_MOD);
    await h.cliccaTesto(page, 'Salva modifiche');
    await page.waitForTimeout(6000);
    docs = (await clientiDi(authA.token, azA)).filter(d => campo(d, 'nome') === NOME);
    if (docs.length !== 1 || campo(docs[0], 'telefono') !== TEL_ATTESO) throw new Error('telefono non salvato in Firestore: ' + campo(docs[0] || {}, 'telefono'));
    passo('modifica', 'OK', TEL_MOD + ' in Firestore');
    if (TEL_ATTESO !== TEL_MOD) throw new Error('controllo rosso: atteso ' + TEL_ATTESO + ', trovato ' + TEL_MOD);
    await page.screenshot({ path: path.join(EVID, '04-modifica.png'), fullPage: true });
    await page.waitForTimeout(2500);

    // Persistenza dopo reload
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);
    await semantica(page);
    await attendiTesto(page, 'Clienti', 15000);
    await cerca(page, NOME);
    if (!(await attendiCella(page, NOME, 15000))) throw new Error('cliente non presente dopo reload');
    passo('persistenza', 'OK');

    // Caso negativo: nome obbligatorio
    await h.cliccaTesto(page, 'Nuovo cliente');
    await page.waitForTimeout(2500);
    await h.cliccaTesto(page, 'Crea cliente');
    await page.waitForTimeout(2500);
    const err = await h.testo(page).then(t => t.includes('Inserisci il nome del cliente')).catch(() => false);
    if (!err) throw new Error('validazione nome assente');
    passo('negativo nome obbligatorio', 'OK');
    await page.screenshot({ path: path.join(EVID, '05-negativo.png'), fullPage: true });
    await h.cliccaTesto(page, 'Annulla');
    await page.waitForTimeout(2500);

    // Isolamento: utente B non vede il cliente di A
    const ctxB = await browser.newContext({ viewport: { width: 1400, height: 1100 }, locale: 'it-IT', serviceWorkers: 'block' });
    const pageB = await ctxB.newPage();
    try {
      if (!(await login(pageB, CRED_B))) throw new Error('login B non riuscito');
      await vaiClienti(pageB);
      await cerca(pageB, NOME.slice(0, 8));
      const visibile = await pageB.locator('flt-semantics[role="cell"]').filter({ hasText: NOME }).count();
      const docsB = (await clientiDi(authB.token, azB)).filter(d => campo(d, 'nome') === NOME);
      if (visibile !== 0 || docsB.length !== 0) throw new Error('isolamento violato');
      passo('isolamento azienda', 'OK', 'B non vede il cliente di A');
      await pageB.screenshot({ path: path.join(EVID, '06-isolamento.png'), fullPage: true });
    } finally { await ctxB.close(); }

    // Eliminazione
    await vaiClienti(page);
    await cerca(page, NOME);
    const menu = page.locator('flt-semantics[role="button"]').filter({ hasText: /Azioni cliente/i }).first();
    const bm = await menu.boundingBox();
    await page.mouse.click(bm.x + bm.width / 2, bm.y + bm.height / 2);
    await page.waitForTimeout(1200);
    await h.cliccaAria(page, 'Elimina');
    await page.waitForTimeout(1500);
    await h.cliccaTesto(page, 'Elimina');
    await page.waitForTimeout(6000);
    docs = (await clientiDi(authA.token, azA)).filter(d => campo(d, 'nome') === NOME);
    if (docs.length !== 0) throw new Error('cliente ancora in Firestore dopo eliminazione');
    if (await page.locator('flt-semantics[role="cell"]').filter({ hasText: NOME }).count() !== 0) throw new Error('cliente ancora in UI');
    passo('eliminazione', 'OK');
    await page.screenshot({ path: path.join(EVID, '07-eliminato.png'), fullPage: true });

    // Persistenza eliminazione
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);
    await semantica(page);
    await attendiTesto(page, 'Clienti', 15000);
    await cerca(page, NOME);
    docs = (await clientiDi(authA.token, azA)).filter(d => campo(d, 'nome') === NOME);
    if (docs.length !== 0) throw new Error('cliente ricomparso dopo reload');
    passo('persistenza eliminazione', 'OK');

    // Controllo di sensibilità: un nome inesistente non deve risultare
    const falso = await page.locator('flt-semantics[role="cell"]').filter({ hasText: NOME + '-INESISTENTE' }).count();
    if (falso !== 0) throw new Error('controllo di sensibilità fallito');
    passo('controllo di sensibilità', 'OK', 'nome inesistente non trovato');

    // Pulizia finale dei dati di prova AU03 (inclusi i clienti seminati per i duplicati)
    const residui = (await clientiDi(authA.token, azA)).filter(d => campo(d, 'nome').startsWith('AU03 '));
    for (const doc of residui) await eliminaDoc(authA.token, doc);
    if (residui.length) passo('pulizia finale', 'OK', `${residui.length} clienti rimossi`);
    const dopoPulizia = (await clientiDi(authA.token, azA)).filter(d => campo(d, 'nome').startsWith('AU03 '));
    if (dopoPulizia.length !== 0) throw new Error('residui AU03 dopo la pulizia');

    log.esito = 'PROVATA';
  } catch (e) {
    log.esito = 'FALLITA';
    log.errore = String(e).slice(0, 500);
    passo('esecuzione', 'FALLITA', log.errore);
    await page.screenshot({ path: path.join(EVID, '99-errore.png'), fullPage: true }).catch(() => {});
  } finally {
    // Pulizia anche sul percorso di errore: nessun dato di prova residuo.
    if (authA && azA) {
      try {
        const residui = (await clientiDi(authA.token, azA)).filter(d => {
          const nome = campo(d, 'nome');
          return nome.startsWith('AU03 ') || nome.startsWith('Audit Cliente');
        });
        for (const doc of residui) await eliminaDoc(authA.token, doc);
      } catch (_) { /* la pulizia non deve nascondere l'esito */ }
    }
    fs.writeFileSync(path.join(EVID, 'esito.json'), JSON.stringify(log, null, 2));
    await browser.close();
    if (log.esito !== 'PROVATA') process.exitCode = 1;
    console.log(JSON.stringify({ esito: log.esito, nome: NOME, errore: log.errore || null }, null, 2));
  }
})();
