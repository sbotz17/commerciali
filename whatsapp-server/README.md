# Server WhatsApp — Configuratore Commerciali

Piccolo servizio che collega **un numero WhatsApp** e permette all'app di
inviare messaggi (preventivi, bandi, notifiche) ai clienti. Un solo server
per tutta la piattaforma: tutte le aziende con il modulo attivo inviano da
questo stesso numero.

Basato su [Baileys](https://github.com/WhiskeySockets/Baileys) (WhatsApp Web
multi-device). Non serve Chrome.

## API

Tutte le richieste richiedono l'header `x-api-key: <API_KEY>`.

| Metodo | Percorso      | Descrizione |
|--------|---------------|-------------|
| GET    | `/status`     | `{ connected, number }` |
| GET    | `/qr`         | `{ qr }` — data URL PNG del QR (se non connesso) |
| POST   | `/send`       | Body `{ to, message, mediaUrl?, filename?, mimetype? }` |
| POST   | `/disconnect` | Scollega il numero |

`to` = numero con prefisso internazionale, es. `393516722792`.
`mediaUrl` = URL pubblico di un'immagine o PDF (opzionale).

## Avvio in locale (per prova)

```bash
cd whatsapp-server
cp .env.example .env         # imposta API_KEY
npm install
npm start
```

Poi apri `http://localhost:3000/qr` (con l'header API key) o usa la console
Super Admin → WhatsApp per mostrare il QR e scansionarlo con
WhatsApp → Dispositivi collegati.

## Messa online con HTTPS (necessario per l'app)

L'app è servita in **https**, quindi il server WhatsApp **deve** essere
raggiungibile in https (un browser non può chiamare `http://` da una pagina
`https://`). Il modo più semplice è un dominio + [Caddy](https://caddyserver.com)
che gestisce il certificato automaticamente.

### Esempio con Caddy (Ubuntu)

1. Punta un sottodominio (es. `wa.iltuodominio.it`) all'IP del server.
2. Avvia il servizio Node (con pm2):
   ```bash
   npm install -g pm2
   cd whatsapp-server && npm install
   pm2 start server.js --name whatsapp
   pm2 save
   ```
3. `Caddyfile`:
   ```
   wa.iltuodominio.it {
     reverse_proxy localhost:3000
   }
   ```
4. `caddy run` (o come servizio). Caddy ottiene il certificato TLS da solo.
5. Nella console app → **Super Admin → WhatsApp** inserisci
   `https://wa.iltuodominio.it` e la stessa `API_KEY`, salva, poi
   **Collega numero (QR)** e scansiona.

### In alternativa: Docker

```bash
docker build -t commerciali-wa .
docker run -d --name whatsapp \
  -p 3000:3000 \
  -e API_KEY=... -e ALLOWED_ORIGIN=https://sbotz17.github.io \
  -v $(pwd)/auth:/app/auth \
  commerciali-wa
```
(mettere comunque un reverse proxy https davanti).

## Note importanti

- **auth/**: contiene la sessione. Non cancellarla, altrimenti dovrai
  riscansionare il QR. È montabile come volume.
- **CORS**: imposta `ALLOWED_ORIGIN` all'URL dell'app per sicurezza.
- **Ban WhatsApp**: l'automazione di un numero personale tramite librerie
  non ufficiali può portare a sospensioni. Per uso intensivo/produzione
  valuta la **WhatsApp Business Cloud API** ufficiale di Meta.
