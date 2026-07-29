# Setup Login sicuro + Recupero password via email

Questa guida attiva il nuovo sistema di accesso:
- 🔒 **login con email + password** gestito da **Supabase Auth** (password cifrate con bcrypt+salt, mai esposte);
- 📧 **recupero password** tramite link inviato via email ("Password dimenticata?");
- 🛡️ la tabella `utenti` non è più leggibile pubblicamente.

Tempo stimato: ~10 minuti (una tantum).

> ⚠️ **Ordine importante.** Esegui prima TUTTI i passi su Supabase (1→4), *poi* manda online il codice (Passo 5). Così il login attuale continua a funzionare finché il nuovo non è pronto, senza rischio di restare chiuso fuori.

---

## PASSO 1 — Migrazione del database
1. Supabase → **SQL Editor** → **New query**
2. Incolla il contenuto di `supabase-schema-auth.sql`
3. **Run**

Aggiunge la colonna `email`, imposta l'email dell'admin (`bottiandrea83@gmail.com`) e mette in sicurezza la tabella.

---

## PASSO 2 — Crea l'account di login dell'admin
1. Supabase → **Authentication** → **Users** → **Add user** → **Create new user**
2. **Email**: `bottiandrea83@gmail.com` (la stessa del Passo 1)
3. **Password**: scegline una robusta
4. Spunta **Auto Confirm User** (così puoi accedere subito)
5. **Create user**

> L'email dell'account qui DEVE essere identica a quella salvata nella tabella `utenti`, altrimenti l'app non trova il profilo (ruolo/permessi).

---

## PASSO 3 — Abilita l'email provider e il recupero password
1. Supabase → **Authentication** → **Providers** → **Email**: assicurati che sia **abilitato**.
2. (Consigliato per iniziare) puoi lasciare attiva "Confirm email"; per l'admin abbiamo già usato *Auto Confirm*.
3. L'email di recupero usa il **servizio email integrato di Supabase**: pronto subito, ma con un **limite di poche email l'ora** e può finire in **spam**. Per un uso intenso, in seguito, configura un SMTP tuo in **Authentication → Emails → SMTP Settings** (es. Gmail/Resend).

---

## PASSO 4 — Configura gli URL di reindirizzamento
Il link di recupero deve riportare gli utenti al sito pubblicato.

1. Supabase → **Authentication** → **URL Configuration**
2. **Site URL**: `https://sbotz17.github.io/commerciali/`
3. **Redirect URLs** → aggiungi: `https://sbotz17.github.io/commerciali/**`
4. Salva

---

## PASSO 5 — Manda online il nuovo login
Le modifiche al codice sono sul branch `claude/project-status-access-1p1sfe`.
Per pubblicarle, uniscile in `main` (GitHub Pages aggiorna il sito in ~1 minuto).

---

## Come si usa

**Accesso** → email + password.

**Password dimenticata** → nella pagina di login clicca **"Password dimenticata?"**, inserisci l'email, ricevi il link, imposta la nuova password.

**Aggiungere un nuovo utente (da Gestione utenti)**
- Compila **Email** (obbligatoria, serve per il login), Username, Nome, Ruolo e una Password.
- L'app crea sia il profilo sia l'account di login.
- Se "Confirm email" è attivo, il nuovo utente deve confermare l'email (o usare "Password dimenticata?") prima del primo accesso. In alternativa l'admin può creare l'account da **Authentication → Users** con *Auto Confirm*.

**Cambiare la propria password** → da Gestione utenti, modifica il tuo utente e imposta la nuova password (vale solo per il proprio account; per gli altri si usa "Password dimenticata?").

---

## Risoluzione problemi

**"Email o password non validi" con le credenziali giuste**
→ Verifica che in **Authentication → Users** l'account esista e sia **confermato**, e che l'email in `utenti` sia identica.

**Non arriva l'email di recupero**
→ Controlla lo spam. Il servizio integrato ha limiti stretti: se non arriva, attendi qualche minuto o configura un SMTP tuo (Passo 3).

**Il link di recupero dà errore "scaduto"**
→ I link durano poco: richiedine uno nuovo. Assicurati che gli URL del Passo 4 siano corretti.
