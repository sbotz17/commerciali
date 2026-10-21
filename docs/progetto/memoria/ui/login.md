# Login e onboarding

**Quando leggerlo**: accesso, Google, recupero password, sessione, creazione azienda.
**File**: `js/auth.js`, `js/firebase.js`, `index.html` (login/onboarding), `js/app.js` (`loginPage`, `onboardingPage`, `resetPasswordPage`, store `sessione`).

## Flusso

1. `login()` → Firebase Auth email/password; `loginConGoogle()` → popup Google.
2. `caricaProfilo(email)` legge `utenti` per email.
3. Se il profilo manca → onboarding: `assicuraProfilo`, `creaAzienda`, `aggiungiMembro`, `seedAzienda`.
4. `ripristinaSessione()` usa `onAuthStateChanged` e ricarica il profilo.
5. Recupero password: `sendPasswordResetEmail`; il link arriva con `mode=resetPassword&oobCode`.

## Punti fermi

- Le password sono gestite da Firebase Auth: mai salvarle o hashare nel database.
- Un profilo disabilitato (`attivo=false`) viene sloggato.
- Il super admin è `utenti/{uid}.super_admin`.
- La sessione locale è in `sessionStorage` (`configuratore_utente`).

## Test

- Login email/password, login Google, logout, recupero password, utente disabilitato.
- Registrazione + onboarding con azienda nuova.

**Ultima revisione**: 2026-10-22
