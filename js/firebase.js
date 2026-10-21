// ============================================================
// firebase.js — inizializzazione Firebase (Auth + Firestore)
// ============================================================
// La configurazione web è pubblica per definizione: non contiene
// segreti. La sicurezza dei dati è nelle Firestore Security Rules.
// ============================================================

const FIREBASE_CONFIG = {
  apiKey:            "AIzaSyC1u1OVQxcgHXoKx_oWq_9Rv_YUqW43da4",
  authDomain:        "commerciali-app.firebaseapp.com",
  projectId:         "commerciali-app",
  storageBucket:     "commerciali-app.firebasestorage.app",
  messagingSenderId: "686757330506",
  appId:             "1:686757330506:web:a1a1e3429435be306330b3",
};

const CLOUD_FUNCTIONS_BASE = "https://europe-west8-commerciali-app.cloudfunctions.net";

firebase.initializeApp(FIREBASE_CONFIG);

const fbAuth = firebase.auth();
const fbDb   = firebase.firestore();

// Persistenza locale della sessione: "local" mantiene l'accesso tra le riaperture.
fbAuth.setPersistence(firebase.auth.Auth.Persistence.LOCAL).catch(() => {});
