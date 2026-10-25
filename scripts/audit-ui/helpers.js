const { chromium } = require('playwright');

const EMAIL = process.env.AUDIT_EMAIL;
const PASS = process.env.AUDIT_PASS;
const BASE = process.env.AUDIT_BASE || 'https://commerciali-app.web.app/';

async function abilitaSemantica(page) {
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30000 });
  await page.waitForTimeout(1500);
  await page.evaluate(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (!ph) return;
    ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(t =>
      ph.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true })));
  });
  await page.waitForTimeout(2000);
}

async function testo(page) {
  return (await page.locator('flt-semantics-host').innerText().catch(() => '')).replace(/\s+/g, ' ').trim();
}

async function cliccaTesto(page, needle, { timeout = 15000 } = {}) {
  const el = page.locator('flt-semantics[role="button"]', { hasText: needle }).first();
  await el.waitFor({ state: 'attached', timeout });
  await el.scrollIntoViewIfNeeded().catch(() => {});
  await page.waitForTimeout(200);
  const box = await el.boundingBox();
  if (!box || box.width === 0) throw new Error('elemento non cliccabile: ' + needle);
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
}

async function cliccaAria(page, label, { timeout = 15000 } = {}) {
  let el = page.locator(`flt-semantics[aria-label="${label}"]`).first();
  const trovato = await el.count().then(n => n > 0).catch(() => false);
  if (!trovato) el = page.locator('flt-semantics', { hasText: label }).last();
  await el.waitFor({ state: 'attached', timeout });
  await el.scrollIntoViewIfNeeded().catch(() => {});
  await page.waitForTimeout(200);
  const box = await el.boundingBox();
  if (!box) throw new Error('nessun box per aria ' + label);
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
}

async function scrivi(page, label, value) {
  const el = page.locator(`input[aria-label="${label}"]`).first();
  await el.waitFor({ state: 'attached', timeout: 15000 });
  const box = await el.boundingBox();
  if (!box) throw new Error('campo non trovato: ' + label);
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await page.waitForTimeout(350);
  // svuota il campo: selezione totale (Meta su macOS) + Backspace
  await page.keyboard.press(process.platform === 'darwin' ? 'Meta+A' : 'Control+A');
  await page.waitForTimeout(150);
  await page.keyboard.press('Backspace');
  await page.waitForTimeout(150);
  await page.keyboard.type(value, { delay: 12 });
}

async function elencoPulsanti(page) {
  return await page.evaluate(() => [...document.querySelectorAll('flt-semantics[role="button"], flt-semantics[role="link"], flt-semantics[role="tab"], flt-semantics[role="checkbox"], flt-semantics[role="switch"]')]
    .map(n => ({ role: n.getAttribute('role'), testo: (n.innerText || '').trim().slice(0, 50), aria: n.getAttribute('aria-label') || '', checked: n.getAttribute('aria-checked') || '' }))
    .filter(x => x.testo || x.aria));
}

async function login(page, email = EMAIL, pass = PASS) {
  await abilitaSemantica(page);
  await scrivi(page, 'Email', email);
  await scrivi(page, 'Password', pass);
  await cliccaTesto(page, 'Accedi');
  await page.waitForTimeout(9000);
}

module.exports = { abilitaSemantica, testo, cliccaTesto, cliccaAria, scrivi, elencoPulsanti, login };
