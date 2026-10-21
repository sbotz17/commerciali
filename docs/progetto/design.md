# Design — Commerciali

- UI in italiano, tono semplice.
- Tailwind CSS; componenti e classi riusati da `index.html`.
- Modali per azioni secondarie; per i flussi principali usare pagine intere quando possibile.
- Stati obbligatori: caricamento, vuoto, errore, senza permessi.
- Formati data e valuta italiani.
- Mobile first: la maggior parte degli utenti usa il telefono.

## 2026-10-22 — Design Flutter

Vale per `flutter_app/` (web, Android, iOS). Nessun restyling: stessa informazione, stessa gerarchia,
stessi testi. Fonte dei flussi: nodi `memoria/ui/*` e `architettura.md` §Architettura Flutter.

### 1. Mappa schermate → rotte e widget

| Oggi (`pagina`) | Rotta go_router | Screen Flutter |
|---|---|---|
| login / recupero | `/login`, `/reset-password` | `LoginScreen`, `ResetPasswordScreen` |
| onboarding | `/onboarding` | `OnboardingScreen` |
| dashboard | `/` | `DashboardScreen` |
| clienti (+ modale VIES) | `/clienti` | `ClientiScreen` + `ClienteFormSheet` |
| catalogo | `/catalogo` | `CatalogoScreen` |
| categorie | `/catalogo/categorie` | `CategorieScreen` |
| preventivi | `/preventivi` | `PreventiviScreen` |
| nuova richiesta | `/preventivi/nuovo` | `PreventivoEditScreen` |
| giro visite | `/visite` | `VisiteScreen` |
| bandi (pubblica) | `/bandi` | `BandiScreen` |
| import bandi | `/bandi/import` | `ImportBandiScreen` |
| impostazioni | `/impostazioni` | `ImpostazioniScreen` |
| utenti / ruoli | `/impostazioni/utenti`, `/impostazioni/ruoli` | `UtentiScreen`, `RuoliScreen` |
| superadmin | `/superadmin` | `SuperAdminScreen` |

### 2. Shell responsive (un solo albero, `LayoutBuilder`)
- **<600 telefono**: `Scaffold` + `NavigationBar` (Operativo: Dashboard, Clienti, Preventivi, Visite, Altro);
  "Altro" apre `Drawer` con Catalogo, Bandi, Amministrazione, utente/logout. Top bar corta, FAB per
  "Nuova richiesta" se il permesso `preventivi_propri` è presente.
- **600–1024 tablet**: `NavigationRail` compatta a icone + `Drawer` per le voci secondarie; contenuti in
  1–2 colonne.
- **>1024 desktop**: `Row` con `NavigationRail` estesa (o drawer permanente) — sezioni Operativo,
  Amministrazione, Super Admin come oggi; area principale con griglie multi-colonna.
- **Dashboard**: telefono = 4 card in 2×2, poi "Ultimi preventivi" a tutta larghezza, azioni rapide in
  lista; tablet = card 2×2 + due colonne; desktop = 4 card in riga, ultimi preventivi 2/3 + azioni 1/3.
- `AppBar` mostra il titolo pagina come oggi; "Nuova richiesta" solo nelle pagine operative e con permesso.

### 3. Componenti condivisi (`core/ui`)
Riuso prima, creazione solo se assente: `AppScaffold` (AppBar + azioni), `SezioneCard`, `StatCard`,
`CampoTesto`/`CampoSelect`/`CampoData` (validazione inline), `ModaleConferma`, `SheetForm`,
`TabellaResponsive` (DataTable ≥600, card in lista <600), `StatoVuoto`, `Caricamento`, `BannerErrore`,
`SenzaPermesso`, `BadgeStato` (bozza/inviato/accettato/rifiutato, visite `da_fare`/`fatto`),
`SelettoreAzienda`, `AvatarUtente`, `ImportoEuro`, `DataItaliana`. I modali restano per azioni
secondarie (VIES, conferme); i flussi principali (nuovo preventivo) sono pagine intere.
Ogni nuovo widget va registrato in `catalogo.md`.

### 4. Token Material 3 (`ColorScheme.fromSeed`)
- Primario blu `#1D4ED8`, superficie bianca, sfondo `#F8FAFC`, bordi `#E2E8F0`.
- Semantici: attesa ambra `#D97706`, accettato verde `#16A34A`, errore rosso `#DC2626`, super admin viola `#7E22CE`.
- Tipografia `TextTheme` M3: titolo schermata `titleLarge` bold, titoli card `titleSmall` semibold,
  corpo `bodyMedium`, etichette maiuscole `labelSmall` con tracking.
- Spazi su scala 4/8: padding pagina 16 (telefono) / 24–32 (desktop), gap card 16, interno card 20.
- Raggi: card 16, campi e pulsanti 12, chip 8, avatar circolare.
- Tema unico, `useMaterial3: true`; nessun colore fuori tema.

### 5. Stati obbligatori per ogni schermata
1. **Caricamento**: skeleton o `CircularProgressIndicator` centrato, senza layout che salta.
2. **Vuoto**: messaggio semplice + azione primaria ("Nessun cliente trovato — Aggiungi cliente").
3. **Errore**: `BannerErrore` in italiano con "Riprova" (errori rete/Firestore/VIES distinti e comprensibili).
4. **Senza permesso**: `SenzaPermesso` con spiegazione breve, raggiungibile solo se la rotta è bloccata dal
   `redirect`; nessun dato caricato. Vale per utenti, ruoli, import bandi, superadmin, valori economici.
   Bandi: il "senza login" è uno stato normale, non un errore.

### 6. Adattamenti necessari (e solo questi)
- Tabelle clienti/preventivi/categorie/utenti → card su telefono, `DataTable` ≥600.
- Sidebar → `NavigationBar` + `Drawer` su telefono, `NavigationRail` da tablet.
- Griglie dashboard e catalogo → 1 colonna su telefono.
- Form lunghi → sezioni espandibili su telefono, colonne su desktop.
- Modali VIES e conferme → `Dialog` su desktop, `showModalBottomSheet` su telefono.
- Tabelle orizzontali in preventivo (righe) → card riga modificabile su telefono.

### 7. Cosa non cambia
Testi e tono in italiano; nomi voci di menu; formati data `dd/MM/yyyy` e valuta `1.234,56 €` (`intl`, locale
`it_IT`); numerazione `PRV-0001` e revisioni `-R1`; permessi, ruoli e visibilità per `azienda_id`; flussi
login/onboarding/reset, CRUD e PDF. Nessuna nuova funzione, campo o schermata.
