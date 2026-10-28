import test from "node:test";
import assert from "node:assert/strict";

import {
  avvisoCoda,
  avvisoPrefisso,
  validaAvviso,
} from "../src/avvisi.mjs";

test("avvisoCoda separa progetto e azienda", () => {
  assert.equal(
    avvisoCoda("commerciali-app", "az1", "task:t1:u1:2026-10-27T08:00"),
    "avviso:commerciali-app:az1:task:t1:u1:2026-10-27T08:00",
  );
});

test("avvisoPrefisso copre tutte le occorrenze di un elemento", () => {
  const prefisso = avvisoPrefisso("commerciali-app", "az1", "task", "t1");
  assert.equal(prefisso, "avviso:commerciali-app:az1:task:t1:");
  assert.ok(
    "avviso:commerciali-app:az1:task:t1:u1:2026-10-27T08:00".startsWith(
      prefisso,
    ),
  );
});

test("validaAvviso accetta una voce completa", () => {
  const adesso = Date.parse("2026-10-26T08:00:00Z");
  const valido = validaAvviso(
    {
      chiave: "task:t1:u1:2026-10-27T08:00",
      utenteUid: "u1",
      dueAt: "2026-10-27T08:00:00.000Z",
      testo: "Closer · Task in scadenza",
      titolo: "Task in scadenza",
      tipo: "task",
      targetId: "t1",
    },
    adesso,
  );
  assert.ok(valido);
  assert.equal(valido.chiave, "task:t1:u1:2026-10-27T08:00");
  assert.equal(valido.uid, "u1");
  assert.equal(valido.tipo, "task");
});

test("validaAvviso rifiuta chiavi, date e testi non validi", () => {
  const adesso = Date.parse("2026-10-26T08:00:00Z");
  const base = {
    chiave: "task:t1:u1:2026-10-27T08:00",
    utenteUid: "u1",
    dueAt: "2026-10-27T08:00:00.000Z",
    testo: "Testo",
    titolo: "Titolo",
    tipo: "task",
    targetId: "t1",
  };
  assert.equal(validaAvviso({ ...base, chiave: "con spazio" }, adesso), null);
  assert.equal(validaAvviso({ ...base, utenteUid: "" }, adesso), null);
  assert.equal(validaAvviso({ ...base, dueAt: "domani" }, adesso), null);
  assert.equal(validaAvviso({ ...base, testo: "  " }, adesso), null);
  assert.equal(validaAvviso({ ...base, tipo: "Task!" }, adesso), null);
  assert.equal(validaAvviso(null, adesso), null);
});

test("validaAvviso rifiuta date oltre i 120 giorni", () => {
  const adesso = Date.parse("2026-10-26T08:00:00Z");
  const valido = validaAvviso(
    {
      chiave: "task:t1:u1:2027-10-27T08:00",
      utenteUid: "u1",
      dueAt: "2027-10-27T08:00:00.000Z",
      testo: "Testo",
      tipo: "task",
      targetId: "t1",
    },
    adesso,
  );
  assert.equal(valido, null);
});
