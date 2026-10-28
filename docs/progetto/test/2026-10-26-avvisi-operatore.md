# Avvisi operatore: appuntamenti, task, preventivi (T-14)

**Data**: 26/10/2026
**Stato**: sviluppo pronto, test automatici verdi; **prova E2E nella UI non ancora eseguita**
**Ambiente**: worktree `feature/T-14-avvisi-operatore`, nessun deploy

## Cosa è stato provato

| Prova | Comando | Esito |
|---|---|---|
| Analisi statica | `flutter analyze` | 0 problemi |
| Test Flutter completi | `flutter test` | 913 verdi, 0 falliti |
| Test Worker | `node --test worker/test/` | 18 verdi, 0 falliti |
| Sintassi Worker | `node --check src/index.js` | OK |

## Casi coperti dai test automatici

- task: avviso con anticipo e alla scadenza, ora mancante → 09:00, completato/senza scadenza esclusi,
  anticipo 0 → un solo avviso;
- preventivo: anticipo + avviso di scaduto il giorno dopo, accettato/senza validità esclusi,
  `preventivoScaduto` sul giorno di validità;
- appuntamento: anticipo per ogni destinatario, annullato e senza `notifica_min` esclusi, privato senza
  titolo;
- finestre in-app (7 giorni) e futuro (90 giorni), chiave deterministica, limiti degli anticipi;
- modello preventivo: `valido_fino` letto, normalizzato, salvato; documenti vecchi leggibili;
- preferenze: nuovi anticipi letti/scritti e presenti nella UI;
- Worker: chiavi per progetto/azienda, validazione di chiave, uid, data, testo, tipo e limite 120 giorni.

## Cosa NON è stato provato (motivo per non dichiarare SUPERATO)

1. Flusso E2E nella UI pubblicata: creare un appuntamento, un task e un preventivo e vedere l'avviso
   in-app al momento giusto.
2. Invio WhatsApp reale dal cron al numero di un operatore con consenso, con prova di ricezione.
3. Assenza di duplicati dopo più aperture dell'app e più salvataggi dello stesso elemento.
4. Cancellazione degli avvisi dopo completamento/eliminazione e verifica della coda KV.

**Conclusione del tester**: area **BLOCCATA** in attesa delle prove UI/WhatsApp sopra. Non è un residuo
accettato: senza queste prove la funzione non entra in staging né in produzione.
