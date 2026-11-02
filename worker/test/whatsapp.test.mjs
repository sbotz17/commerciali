import test from "node:test";
import assert from "node:assert/strict";

import {
  inviaWhatsapp,
  normalizzaStatoServerWhatsapp,
} from "../src/whatsapp.mjs";

function risposta(status, body) {
  return {
    status,
    ok: status >= 200 && status < 300,
    async text() {
      return typeof body === "string" ? body : JSON.stringify(body);
    },
  };
}

test("usa /invia del server VOLTY", async () => {
  const chiamate = [];
  const esito = await inviaWhatsapp(
    { url: "https://wa.example.com/", apiKey: "k" },
    "393331234567",
    "Ciao",
    async (url, opzioni) => {
      chiamate.push({ url, opzioni });
      return risposta(200, { ok: true, messageId: "m1" });
    },
  );
  assert.equal(chiamate.length, 1);
  assert.equal(chiamate[0].url, "https://wa.example.com/invia");
  assert.deepEqual(JSON.parse(chiamate[0].opzioni.body), {
    numero: "393331234567",
    testo: "Ciao",
  });
  assert.equal(chiamate[0].opzioni.headers["x-api-key"], "k");
  assert.equal(esito.id, "m1");
});

test("ripiega su /send quando /invia non esiste", async () => {
  const chiamate = [];
  const esito = await inviaWhatsapp(
    { url: "https://wa.example.com", apiKey: "k" },
    "393331234567",
    "Ciao",
    async (url, opzioni) => {
      chiamate.push(url);
      return url.endsWith("/invia")
        ? risposta(404, "Cannot POST /invia")
        : risposta(200, { ok: true, id: "m2" });
    },
  );
  assert.deepEqual(chiamate, [
    "https://wa.example.com/invia",
    "https://wa.example.com/send",
  ]);
  assert.equal(esito.id, "m2");
});

test("un 401 non fa scattare il fallback e riporta l'errore", async () => {
  let chiamate = 0;
  await assert.rejects(
    inviaWhatsapp(
      { url: "https://wa.example.com", apiKey: "k" },
      "393331234567",
      "Ciao",
      async () => {
        chiamate++;
        return risposta(401, { error: "unauthorized" });
      },
    ),
    /unauthorized/,
  );
  assert.equal(chiamate, 1);
});

test("normalizza lo stato VOLTY e il vecchio stato", () => {
  assert.deepEqual(
    normalizzaStatoServerWhatsapp({
      connesso: true,
      numero: "393331234567",
      stato: "aperta",
    }),
    { connected: true, number: "393331234567", state: "aperta" },
  );
  assert.deepEqual(
    normalizzaStatoServerWhatsapp({ connected: false, number: null }),
    { connected: false, number: null, state: null },
  );
});
