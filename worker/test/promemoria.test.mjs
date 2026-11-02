import test from "node:test";
import assert from "node:assert/strict";

import {
  canaliCliente,
  componiPromemoriaCliente,
  emailValida,
  formattaDataItaliana,
  normalizzaNumeroWhatsapp,
} from "../src/promemoria.mjs";

test("formattaDataItaliana converte ISO in italiano", () => {
  assert.equal(formattaDataItaliana("2026-10-25"), "25/10/2026");
  assert.equal(formattaDataItaliana(""), "");
  assert.equal(formattaDataItaliana("domani"), "domani");
});

test("normalizzaNumeroWhatsapp aggiunge il prefisso italiano", () => {
  assert.equal(normalizzaNumeroWhatsapp("351 672 2792"), "393516722792");
  assert.equal(normalizzaNumeroWhatsapp("+39 351 672 2792"), "393516722792");
  assert.equal(normalizzaNumeroWhatsapp("02 1234 5678"), "390212345678");
  assert.equal(normalizzaNumeroWhatsapp("0039 351 672 2792"), "393516722792");
  assert.equal(normalizzaNumeroWhatsapp(""), "");
});

test("emailValida accetta email semplici e rifiuta testi", () => {
  assert.equal(emailValida("mario.rossi@acme.it"), true);
  assert.equal(emailValida("  mario@acme.co.uk  "), true);
  assert.equal(emailValida("mario@acme"), false);
  assert.equal(emailValida("mario rossi@acme.it"), false);
  assert.equal(emailValida(""), false);
});

test("canaliCliente tiene solo whatsapp/email senza duplicati", () => {
  assert.deepEqual(canaliCliente(["email", "whatsapp", "email"]), [
    "whatsapp",
    "email",
  ]);
  assert.deepEqual(canaliCliente(["sms", "", null]), []);
  assert.deepEqual(canaliCliente("whatsapp"), []);
});

test("promemoria di creazione con orario e luogo", () => {
  const esito = componiPromemoriaCliente({
    titolo: "Visita ACME",
    data: "2026-10-25",
    ora: "10:00",
    oraFine: "11:30",
    luogo: "Sede ACME",
  });
  assert.equal(esito.oggetto, "Appuntamento confermato - Visita ACME");
  assert.match(esito.testo, /Gentile cliente,/);
  assert.match(
    esito.testo,
    /Le confermiamo l'appuntamento "Visita ACME" il 25\/10\/2026 dalle 10:00 alle 11:30 presso Sede ACME\./,
  );
  assert.match(esito.testo, /Per eventuali modifiche contatti il suo referente\./);
});

test("promemoria tutto il giorno e su più giorni", () => {
  const esito = componiPromemoriaCliente({
    titolo: "Fiera",
    data: "2026-10-25",
    dataFine: "2026-10-27",
    tuttoIlGiorno: true,
  });
  assert.match(esito.testo, /dal 25\/10\/2026 al 27\/10\/2026 \(tutto il giorno\)/);
});

test("promemoria di modifica usa la nuova data", () => {
  const esito = componiPromemoriaCliente({
    titolo: "Visita ACME",
    data: "2026-10-26",
    ora: "15:00",
    modifica: true,
  });
  assert.equal(esito.oggetto, "Appuntamento spostato - Visita ACME");
  assert.match(
    esito.testo,
    /Le confermiamo la nuova data dell'appuntamento "Visita ACME": il 26\/10\/2026 alle 15:00\./,
  );
});

test("promemoria privato non espone il titolo", () => {
  const esito = componiPromemoriaCliente({
    titolo: "Trattativa riservata",
    privato: true,
    data: "2026-10-25",
    ora: "09:00",
    luogo: "Milano",
  });
  assert.equal(esito.oggetto, "Appuntamento confermato");
  assert.ok(!esito.testo.includes("Trattativa riservata"));
  assert.match(esito.testo, /il suo appuntamento il 25\/10\/2026 alle 09:00 presso Milano/);
});

test("promemoria senza titolo usa la formula generica", () => {
  const esito = componiPromemoriaCliente({ data: "2026-10-25" });
  assert.equal(esito.oggetto, "Appuntamento confermato");
  assert.match(esito.testo, /Le confermiamo il suo appuntamento il 25\/10\/2026\./);
});
