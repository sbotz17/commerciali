import test from "node:test";
import assert from "node:assert/strict";

import { annullaPromemoria } from "../src/index.js";

class KvFinto {
  constructor(voci = {}) {
    this.mappa = new Map(Object.entries(voci));
    this.listChiamate = 0;
    this.listErrore = null;
  }

  async get(chiave) {
    return this.mappa.has(chiave) ? this.mappa.get(chiave) : null;
  }

  async put(chiave, valore) {
    this.mappa.set(chiave, valore);
  }

  async delete(chiave) {
    this.mappa.delete(chiave);
  }

  async list({ prefix }) {
    this.listChiamate += 1;
    if (this.listErrore) throw this.listErrore;
    const keys = [...this.mappa.keys()]
      .filter((chiave) => chiave.startsWith(prefix))
      .map((name) => ({ name }));
    return { keys };
  }
}

const APP = "app1";
const INDICE = `promemoria-indice:${APP}`;

test("cancellazione con indice: niente list sul KV", async () => {
  const kv = new KvFinto({
    [`promemoria:${APP}:a`]: "{}",
    [`promemoria:${APP}:b`]: "{}",
    [INDICE]: JSON.stringify([`promemoria:${APP}:a`, `promemoria:${APP}:b`]),
  });
  await annullaPromemoria({ PROMEMORIA: kv }, APP);
  assert.equal(kv.listChiamate, 0, "la list non deve essere chiamata");
  assert.equal(kv.mappa.has(`promemoria:${APP}:a`), false);
  assert.equal(kv.mappa.has(`promemoria:${APP}:b`), false);
  assert.equal(kv.mappa.get(INDICE), "[]");
});

test("indice vuoto: nessuna list e nessuna cancellazione", async () => {
  const kv = new KvFinto({ [INDICE]: "[]" });
  await annullaPromemoria({ PROMEMORIA: kv }, APP);
  assert.equal(kv.listChiamate, 0);
  assert.equal(kv.mappa.get(INDICE), "[]");
});

test("dati vecchi senza indice: una list, poi il marcatore", async () => {
  const kv = new KvFinto({
    [`promemoria:${APP}:vecchio`]: "{}",
  });
  await annullaPromemoria({ PROMEMORIA: kv }, APP);
  assert.equal(kv.listChiamate, 1);
  assert.equal(kv.mappa.has(`promemoria:${APP}:vecchio`), false);
  assert.equal(kv.mappa.get(INDICE), "[]");
});

test("quota list esaurita sui dati vecchi: non blocca il salvataggio", async () => {
  const kv = new KvFinto({
    [`promemoria:${APP}:vecchio`]: "{}",
  });
  kv.listErrore = new Error("KV list() limit exceeded for the day.");
  await annullaPromemoria({ PROMEMORIA: kv }, APP);
  assert.equal(kv.listChiamate, 1);
  assert.equal(kv.mappa.has(`promemoria:${APP}:vecchio`), true);
  assert.equal(kv.mappa.has(INDICE), false);
});

test("senza binding KV non fa nulla", async () => {
  await annullaPromemoria({}, APP);
});
