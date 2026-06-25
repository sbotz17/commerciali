// ============================================================
// bandi-data.js — Dataset bandi e agevolazioni
// Aggiornato a: Giugno 2026
// NOTA: Le informazioni sono indicative. Verificare sempre
//       le fonti ufficiali prima di presentare domanda.
// ============================================================

const BANDI_AGGIORNAMENTO = "Giugno 2026";

// Filtra automaticamente i bandi scaduti rispetto alla data corrente
function _isAttivo(b) {
  if (b.scadenza === "Permanente" || b.scadenza === "Variabile") return true;
  try {
    return new Date(b.scadenza) >= new Date();
  } catch (_) { return true; }
}

const BANDI_DATABASE = [
  // =====================================================================
  // NAZIONALI
  // =====================================================================
  {
    id: 1,
    nome: "Transizione 5.0 — Credito d'Imposta",
    ente: "MIMIT",
    tipo: "credito_imposta",
    descrizione: "Credito d'imposta per investimenti in software gestionali, ERP e soluzioni digitali certificate. Prorogato con rifinanziamento per il 2026. Include software per ristorazione, retail e GDO.",
    importoMin: 2500,
    importoMax: 50000000,
    aliquota: "25%–45%",
    scadenza: "2026-12-31",
    stato: "attivo",
    settori: ["ristorazione", "retail", "grande_distribuzione", "tutti"],
    atecoCodici: ["56", "47", "45", "46"],
    regioni: ["tutte"],
    requisiti: [
      "Impresa residente in Italia",
      "Investimento in software certificato Transizione 5.0",
      "Risparmio energetico documentato (minimo 3%)",
      "Comunicazione preventiva al GSE prima dell'ordine"
    ],
    link: "https://www.mimit.gov.it/it/incentivi/transizione-5-0",
    fonte: "MIMIT — mimit.gov.it",
    note: "Richiede perizia tecnica asseverata. Le aliquote 2026 sono state rideterminate — verificare sul sito MIMIT."
  },
  {
    id: 2,
    nome: "Nuova Sabatini — Beni Strumentali",
    ente: "Mediocredito Centrale / MIMIT",
    tipo: "contributo_interessi",
    descrizione: "Contributo in conto interessi su finanziamenti bancari per acquisto di software gestionali, sistemi informatici e hardware. Maggiorazione per investimenti 4.0/5.0.",
    importoMin: 20000,
    importoMax: 4000000,
    aliquota: "Tasso agevolato (2.75%–5.5% per digitale 4.0)",
    scadenza: "2026-12-31",
    stato: "attivo",
    settori: ["tutti"],
    atecoCodici: ["tutti"],
    regioni: ["tutte"],
    requisiti: [
      "PMI con sede legale in Italia",
      "Finanziamento bancario abbinato (min. 5 anni)",
      "Beni nuovi di fabbrica — anche software",
      "Domanda presentata tramite banca convenzionata"
    ],
    link: "https://www.mimit.gov.it/it/incentivi/nuova-sabatini",
    fonte: "MIMIT — mimit.gov.it",
    note: "Verificare disponibilità fondi residui sul sito MIMIT."
  },
  {
    id: 3,
    nome: "Fondo di Garanzia per le PMI",
    ente: "Mediocredito Centrale",
    tipo: "garanzia",
    descrizione: "Garanzia pubblica gratuita fino all'80% su finanziamenti per investimenti in tecnologie digitali, software e hardware.",
    importoMin: 0,
    importoMax: 5000000,
    aliquota: "Garanzia fino all'80%",
    scadenza: "Permanente",
    stato: "attivo",
    settori: ["tutti"],
    atecoCodici: ["tutti"],
    regioni: ["tutte"],
    requisiti: [
      "PMI o Midcap con sede in Italia",
      "Non in difficoltà finanziaria",
      "Finanziamento per investimento produttivo"
    ],
    link: "https://www.fondidigaranzia.it",
    fonte: "Mediocredito Centrale — fondidigaranzia.it",
    note: "Gratuito per l'impresa. Accesso tramite banca o intermediario convenzionato."
  },
  {
    id: 4,
    nome: "Credito R&S e Innovazione Tecnologica",
    ente: "Agenzia delle Entrate",
    tipo: "credito_imposta",
    descrizione: "Credito d'imposta per sviluppo software personalizzato, innovazione tecnologica e acquisto soluzioni digitali avanzate. Regime prorogato fino al 2026.",
    importoMin: 0,
    importoMax: 2000000,
    aliquota: "10%–15% (20% per Mezzogiorno)",
    scadenza: "2026-12-31",
    stato: "attivo",
    settori: ["tutti"],
    atecoCodici: ["tutti"],
    regioni: ["tutte"],
    requisiti: [
      "Tutte le tipologie di impresa",
      "Software sviluppato internamente o commissionato",
      "Documentazione tecnica e contabile",
      "Perizia asseverata obbligatoria"
    ],
    link: "https://www.agenziaentrate.gov.it",
    fonte: "Agenzia delle Entrate",
    note: "Aliquote ridimensionate rispetto agli anni precedenti. Obbligatoria comunicazione preventiva all'AdE."
  },
  {
    id: 5,
    nome: "ZES Unica Sud — Credito d'Imposta 2026",
    ente: "Agenzia delle Entrate / MIMIT",
    tipo: "credito_imposta",
    descrizione: "Credito d'imposta per investimenti in beni strumentali e software nelle regioni della Zona Economica Speciale Unica del Mezzogiorno. Proroga 2026 in corso di approvazione.",
    importoMin: 0,
    importoMax: 100000000,
    aliquota: "15%–40% (in base alla dimensione d'impresa)",
    scadenza: "2026-11-15",
    stato: "attivo",
    settori: ["tutti"],
    atecoCodici: ["tutti"],
    regioni: ["campania", "puglia", "sicilia", "calabria", "basilicata", "molise", "sardegna"],
    requisiti: [
      "Impresa con sede o attività nel Mezzogiorno",
      "Investimento in beni strumentali nuovi",
      "Piano di investimento documentato",
      "Comunicazione preventiva telematica"
    ],
    link: "https://www.agenziaentrate.gov.it/portale/web/guest/zes-unica",
    fonte: "Agenzia delle Entrate",
    note: "Verificare lo stato della proroga 2026 prima di procedere. Cumulabile con altri incentivi nazionali."
  },
  {
    id: 6,
    nome: "Resto al Sud 2.0 — Imprenditoria Digitale",
    ente: "Invitalia",
    tipo: "finanziamento_agevolato",
    descrizione: "Finanziamento agevolato per under 60 nel Mezzogiorno per avviare o ampliare imprese nei settori digitali. Include acquisto software gestionale e attrezzature.",
    importoMin: 50000,
    importoMax: 75000,
    aliquota: "50% fondo perduto + 50% finanziamento agevolato a tasso zero",
    scadenza: "Permanente",
    stato: "attivo",
    settori: ["tutti"],
    atecoCodici: ["tutti"],
    regioni: ["campania", "puglia", "sicilia", "calabria", "basilicata", "molise", "sardegna", "abruzzo"],
    requisiti: [
      "Età 18–60 anni (limite innalzato nel 2025)",
      "Residente o con sede nel Sud Italia",
      "Impresa da avviare o avviata da max 5 anni"
    ],
    link: "https://www.invitalia.it/cosa-facciamo/rafforziamo-le-imprese/resto-al-sud",
    fonte: "Invitalia — invitalia.it",
    note: "Include spese per software e attrezzature digitali. Presentazione domanda su piattaforma Invitalia."
  },

  // =====================================================================
  // REGIONALI
  // =====================================================================
  {
    id: 7,
    nome: "Voucher Digitalizzazione PMI — FESR 2021-2027",
    ente: "Regioni — Fondi FESR",
    tipo: "voucher",
    descrizione: "Voucher a fondo perduto per PMI che adottano software gestionale, POS evoluti, sistemi di prenotazione, casse digitali e soluzioni cloud.",
    importoMin: 5000,
    importoMax: 50000,
    aliquota: "50%–80% a fondo perduto",
    scadenza: "Variabile",
    stato: "attivo",
    settori: ["ristorazione", "retail"],
    atecoCodici: ["56", "47"],
    regioni: ["lombardia", "veneto", "emilia_romagna", "toscana", "piemonte", "lazio", "liguria", "marche"],
    requisiti: [
      "PMI con sede operativa nella regione",
      "Micro o piccola impresa (< 50 dipendenti)",
      "Software per gestione attività principale"
    ],
    link: "https://fondieuropei.it",
    fonte: "Fondi Europei — fondieuropei.it",
    note: "La scadenza varia per regione. Verificare l'apertura dello sportello nella propria regione prima di procedere."
  },
  {
    id: 8,
    nome: "Digital Hub Lombardia 2026",
    ente: "Regione Lombardia / Finlombarda",
    tipo: "contributo",
    descrizione: "Contributi a fondo perduto per PMI lombarde che investono in soluzioni software per la gestione d'impresa, intelligenza artificiale applicata e digitalizzazione dei processi.",
    importoMin: 10000,
    importoMax: 100000,
    aliquota: "40%–60% a fondo perduto",
    scadenza: "2026-10-31",
    stato: "attivo",
    settori: ["tutti"],
    atecoCodici: ["tutti"],
    regioni: ["lombardia"],
    requisiti: [
      "Sede operativa in Lombardia",
      "PMI con meno di 250 dipendenti",
      "Piano di investimento digitale approvato",
      "Investimento minimo €10.000"
    ],
    link: "https://www.finlombarda.it/incentivi",
    fonte: "Finlombarda — finlombarda.it",
    note: "Bando a sportello, a esaurimento risorse. Verificare disponibilità fondi."
  },
  {
    id: 9,
    nome: "Digitalizzazione Retail — Veneto 2026",
    ente: "Regione Veneto",
    tipo: "contributo",
    descrizione: "Finanziamenti per negozi e ristoranti veneti che adottano software gestionale, sistemi di e-commerce, prenotazione online o fidelizzazione clienti.",
    importoMin: 5000,
    importoMax: 60000,
    aliquota: "50% a fondo perduto",
    scadenza: "2026-09-30",
    stato: "attivo",
    settori: ["retail", "ristorazione"],
    atecoCodici: ["47", "56"],
    regioni: ["veneto"],
    requisiti: [
      "Sede legale o operativa in Veneto",
      "Attività commerciale o di ristorazione attiva",
      "Software gestionale certificato o cloud"
    ],
    link: "https://www.regione.veneto.it/incentivi",
    fonte: "Regione Veneto — regione.veneto.it",
    note: "Domanda tramite Confcommercio Veneto o sportello regionale."
  },
  {
    id: 10,
    nome: "FESR Digitale GDO — Emilia-Romagna",
    ente: "Regione Emilia-Romagna / ERVET",
    tipo: "contributo",
    descrizione: "Contributi per imprese della grande distribuzione e retail emiliane che adottano piattaforme digitali per gestione magazzino, ordini e vendita omnicanale.",
    importoMin: 15000,
    importoMax: 150000,
    aliquota: "40% a fondo perduto",
    scadenza: "2026-11-30",
    stato: "attivo",
    settori: ["retail", "grande_distribuzione"],
    atecoCodici: ["47", "46"],
    regioni: ["emilia_romagna"],
    requisiti: [
      "Sede in Emilia-Romagna",
      "Impresa del commercio o distribuzione",
      "Piano di investimento digitale",
      "Fatturato inferiore a €50 milioni"
    ],
    link: "https://www.regione.emilia-romagna.it/economia/incentivi",
    fonte: "Regione Emilia-Romagna — regione.emilia-romagna.it",
    note: "Verificare apertura sportello sul portale regionale prima di procedere."
  },
  {
    id: 11,
    nome: "Patto per lo Sviluppo — Digitalizzazione Sud",
    ente: "Invitalia / Regioni del Sud",
    tipo: "contributo",
    descrizione: "Contributi per le PMI delle regioni meridionali che investono in software gestionale ERP, POS avanzati e sistemi cloud per la digitalizzazione dei processi aziendali.",
    importoMin: 5000,
    importoMax: 50000,
    aliquota: "60%–80% a fondo perduto",
    scadenza: "2026-12-31",
    stato: "attivo",
    settori: ["ristorazione", "retail", "grande_distribuzione"],
    atecoCodici: ["56", "47", "46"],
    regioni: ["campania", "puglia", "sicilia", "calabria", "basilicata", "molise", "sardegna"],
    requisiti: [
      "PMI con sede nel Mezzogiorno",
      "Settore commercio, ristorazione o distribuzione",
      "Investimento minimo €5.000 in software"
    ],
    link: "https://www.invitalia.it",
    fonte: "Invitalia — invitalia.it",
    note: "Misure finanziate con fondi PNRR e FSC. Verificare disponibilità per singola regione."
  },
];

// ============================================================
// Mappatura prefissi ATECO → settore
// ============================================================
const ATECO_SETTORI = {
  "56": { nome: "Ristorazione e Bar",          icona: "🍽️", settore: "ristorazione" },
  "55": { nome: "Alloggio e Hotel",            icona: "🏨", settore: "ristorazione" },
  "47": { nome: "Commercio al dettaglio",      icona: "🛒", settore: "retail"       },
  "46": { nome: "Commercio all'ingrosso",      icona: "📦", settore: "grande_distribuzione" },
  "45": { nome: "Auto e Moto — Vendita",       icona: "🚗", settore: "retail"       },
  "10": { nome: "Industria alimentare",        icona: "🏭", settore: "grande_distribuzione" },
  "49": { nome: "Trasporti terrestri",         icona: "🚛", settore: "tutti"        },
};

// ============================================================
// Lista regioni italiane (usata internamente per il matching DB)
// ============================================================
const REGIONI_ITALIA = [
  { id: "tutte",          nome: "Tutte le regioni"                    },
  { id: "lombardia",      nome: "Lombardia"                           },
  { id: "veneto",         nome: "Veneto"                              },
  { id: "piemonte",       nome: "Piemonte"                            },
  { id: "emilia_romagna", nome: "Emilia-Romagna"                      },
  { id: "toscana",        nome: "Toscana"                             },
  { id: "lazio",          nome: "Lazio"                               },
  { id: "campania",       nome: "Campania"                            },
  { id: "sicilia",        nome: "Sicilia"                             },
  { id: "puglia",         nome: "Puglia"                              },
  { id: "calabria",       nome: "Calabria"                            },
  { id: "sardegna",       nome: "Sardegna"                            },
  { id: "liguria",        nome: "Liguria"                             },
  { id: "marche",         nome: "Marche"                              },
  { id: "abruzzo",        nome: "Abruzzo"                             },
  { id: "umbria",         nome: "Umbria"                              },
  { id: "friuli",         nome: "Friuli-Venezia Giulia"               },
  { id: "trentino",       nome: "Trentino-Alto Adige/Südtirol"        },
  { id: "valle_aosta",    nome: "Valle d'Aosta/Vallée d'Aoste"        },
  { id: "basilicata",     nome: "Basilicata"                          },
  { id: "molise",         nome: "Molise"                              },
];

// ============================================================
// Lista province italiane con mappatura regione
// La regione corrisponde ai valori presenti nel DB (da incentivi.gov.it)
// ============================================================
const PROVINCE_ITALIA = [
  { id: "tutte", nome: "Tutta Italia", sigla: "", regione: "" },
  // Abruzzo
  { id: "ch", nome: "Chieti",    sigla: "CH", regione: "Abruzzo" },
  { id: "aq", nome: "L'Aquila",  sigla: "AQ", regione: "Abruzzo" },
  { id: "pe", nome: "Pescara",   sigla: "PE", regione: "Abruzzo" },
  { id: "te", nome: "Teramo",    sigla: "TE", regione: "Abruzzo" },
  // Basilicata
  { id: "mt", nome: "Matera",    sigla: "MT", regione: "Basilicata" },
  { id: "pz", nome: "Potenza",   sigla: "PZ", regione: "Basilicata" },
  // Calabria
  { id: "cz", nome: "Catanzaro",       sigla: "CZ", regione: "Calabria" },
  { id: "cs", nome: "Cosenza",         sigla: "CS", regione: "Calabria" },
  { id: "kr", nome: "Crotone",         sigla: "KR", regione: "Calabria" },
  { id: "rc", nome: "Reggio Calabria", sigla: "RC", regione: "Calabria" },
  { id: "vv", nome: "Vibo Valentia",   sigla: "VV", regione: "Calabria" },
  // Campania
  { id: "av", nome: "Avellino",  sigla: "AV", regione: "Campania" },
  { id: "bn", nome: "Benevento", sigla: "BN", regione: "Campania" },
  { id: "ce", nome: "Caserta",   sigla: "CE", regione: "Campania" },
  { id: "na", nome: "Napoli",    sigla: "NA", regione: "Campania" },
  { id: "sa", nome: "Salerno",   sigla: "SA", regione: "Campania" },
  // Emilia-Romagna
  { id: "bo", nome: "Bologna",      sigla: "BO", regione: "Emilia-Romagna" },
  { id: "fe", nome: "Ferrara",      sigla: "FE", regione: "Emilia-Romagna" },
  { id: "fc", nome: "Forlì-Cesena", sigla: "FC", regione: "Emilia-Romagna" },
  { id: "mo", nome: "Modena",       sigla: "MO", regione: "Emilia-Romagna" },
  { id: "pr", nome: "Parma",        sigla: "PR", regione: "Emilia-Romagna" },
  { id: "pc", nome: "Piacenza",     sigla: "PC", regione: "Emilia-Romagna" },
  { id: "ra", nome: "Ravenna",      sigla: "RA", regione: "Emilia-Romagna" },
  { id: "re", nome: "Reggio Emilia",sigla: "RE", regione: "Emilia-Romagna" },
  { id: "rn", nome: "Rimini",       sigla: "RN", regione: "Emilia-Romagna" },
  // Friuli-Venezia Giulia
  { id: "go", nome: "Gorizia",   sigla: "GO", regione: "Friuli-Venezia Giulia" },
  { id: "pn", nome: "Pordenone", sigla: "PN", regione: "Friuli-Venezia Giulia" },
  { id: "ts", nome: "Trieste",   sigla: "TS", regione: "Friuli-Venezia Giulia" },
  { id: "ud", nome: "Udine",     sigla: "UD", regione: "Friuli-Venezia Giulia" },
  // Lazio
  { id: "fr", nome: "Frosinone", sigla: "FR", regione: "Lazio" },
  { id: "lt", nome: "Latina",    sigla: "LT", regione: "Lazio" },
  { id: "ri", nome: "Rieti",     sigla: "RI", regione: "Lazio" },
  { id: "rm", nome: "Roma",      sigla: "RM", regione: "Lazio" },
  { id: "vt", nome: "Viterbo",   sigla: "VT", regione: "Lazio" },
  // Liguria
  { id: "ge", nome: "Genova",   sigla: "GE", regione: "Liguria" },
  { id: "im", nome: "Imperia",  sigla: "IM", regione: "Liguria" },
  { id: "sp", nome: "La Spezia",sigla: "SP", regione: "Liguria" },
  { id: "sv", nome: "Savona",   sigla: "SV", regione: "Liguria" },
  // Lombardia
  { id: "bg", nome: "Bergamo",           sigla: "BG", regione: "Lombardia" },
  { id: "bs", nome: "Brescia",           sigla: "BS", regione: "Lombardia" },
  { id: "co", nome: "Como",              sigla: "CO", regione: "Lombardia" },
  { id: "cr", nome: "Cremona",           sigla: "CR", regione: "Lombardia" },
  { id: "lc", nome: "Lecco",             sigla: "LC", regione: "Lombardia" },
  { id: "lo", nome: "Lodi",              sigla: "LO", regione: "Lombardia" },
  { id: "mn", nome: "Mantova",           sigla: "MN", regione: "Lombardia" },
  { id: "mi", nome: "Milano",            sigla: "MI", regione: "Lombardia" },
  { id: "mb", nome: "Monza e Brianza",   sigla: "MB", regione: "Lombardia" },
  { id: "pv", nome: "Pavia",             sigla: "PV", regione: "Lombardia" },
  { id: "so", nome: "Sondrio",           sigla: "SO", regione: "Lombardia" },
  { id: "va", nome: "Varese",            sigla: "VA", regione: "Lombardia" },
  // Marche
  { id: "an", nome: "Ancona",          sigla: "AN", regione: "Marche" },
  { id: "ap", nome: "Ascoli Piceno",   sigla: "AP", regione: "Marche" },
  { id: "fm", nome: "Fermo",           sigla: "FM", regione: "Marche" },
  { id: "mc", nome: "Macerata",        sigla: "MC", regione: "Marche" },
  { id: "pu", nome: "Pesaro e Urbino", sigla: "PU", regione: "Marche" },
  // Molise
  { id: "cb", nome: "Campobasso", sigla: "CB", regione: "Molise" },
  { id: "is", nome: "Isernia",    sigla: "IS", regione: "Molise" },
  // Piemonte
  { id: "al", nome: "Alessandria",          sigla: "AL", regione: "Piemonte" },
  { id: "at", nome: "Asti",                 sigla: "AT", regione: "Piemonte" },
  { id: "bi", nome: "Biella",               sigla: "BI", regione: "Piemonte" },
  { id: "cn", nome: "Cuneo",                sigla: "CN", regione: "Piemonte" },
  { id: "no", nome: "Novara",               sigla: "NO", regione: "Piemonte" },
  { id: "to", nome: "Torino",               sigla: "TO", regione: "Piemonte" },
  { id: "vco",nome: "Verbano-Cusio-Ossola", sigla: "VB", regione: "Piemonte" },
  { id: "vc", nome: "Vercelli",             sigla: "VC", regione: "Piemonte" },
  // Puglia
  { id: "ba",  nome: "Bari",                  sigla: "BA",  regione: "Puglia" },
  { id: "bat", nome: "Barletta-Andria-Trani", sigla: "BT",  regione: "Puglia" },
  { id: "br",  nome: "Brindisi",              sigla: "BR",  regione: "Puglia" },
  { id: "fg",  nome: "Foggia",                sigla: "FG",  regione: "Puglia" },
  { id: "le",  nome: "Lecce",                 sigla: "LE",  regione: "Puglia" },
  { id: "ta",  nome: "Taranto",               sigla: "TA",  regione: "Puglia" },
  // Sardegna
  { id: "ca",  nome: "Cagliari",     sigla: "CA",  regione: "Sardegna" },
  { id: "nu",  nome: "Nuoro",        sigla: "NU",  regione: "Sardegna" },
  { id: "or",  nome: "Oristano",     sigla: "OR",  regione: "Sardegna" },
  { id: "ss",  nome: "Sassari",      sigla: "SS",  regione: "Sardegna" },
  { id: "su",  nome: "Sud Sardegna", sigla: "SU",  regione: "Sardegna" },
  // Sicilia
  { id: "ag", nome: "Agrigento",   sigla: "AG", regione: "Sicilia" },
  { id: "cl", nome: "Caltanissetta",sigla: "CL", regione: "Sicilia" },
  { id: "ct", nome: "Catania",     sigla: "CT", regione: "Sicilia" },
  { id: "en", nome: "Enna",        sigla: "EN", regione: "Sicilia" },
  { id: "me", nome: "Messina",     sigla: "ME", regione: "Sicilia" },
  { id: "pa", nome: "Palermo",     sigla: "PA", regione: "Sicilia" },
  { id: "rg", nome: "Ragusa",      sigla: "RG", regione: "Sicilia" },
  { id: "sr", nome: "Siracusa",    sigla: "SR", regione: "Sicilia" },
  { id: "tp", nome: "Trapani",     sigla: "TP", regione: "Sicilia" },
  // Toscana
  { id: "ar", nome: "Arezzo",       sigla: "AR", regione: "Toscana" },
  { id: "fi", nome: "Firenze",      sigla: "FI", regione: "Toscana" },
  { id: "gr", nome: "Grosseto",     sigla: "GR", regione: "Toscana" },
  { id: "li", nome: "Livorno",      sigla: "LI", regione: "Toscana" },
  { id: "lu", nome: "Lucca",        sigla: "LU", regione: "Toscana" },
  { id: "ms", nome: "Massa-Carrara",sigla: "MS", regione: "Toscana" },
  { id: "pi", nome: "Pisa",         sigla: "PI", regione: "Toscana" },
  { id: "pt", nome: "Pistoia",      sigla: "PT", regione: "Toscana" },
  { id: "po", nome: "Prato",        sigla: "PO", regione: "Toscana" },
  { id: "si", nome: "Siena",        sigla: "SI", regione: "Toscana" },
  // Trentino-Alto Adige
  { id: "bz", nome: "Bolzano",sigla: "BZ", regione: "Trentino-Alto Adige/Südtirol" },
  { id: "tn", nome: "Trento", sigla: "TN", regione: "Trentino-Alto Adige/Südtirol" },
  // Umbria
  { id: "pg", nome: "Perugia", sigla: "PG", regione: "Umbria" },
  { id: "tr", nome: "Terni",   sigla: "TR", regione: "Umbria" },
  // Valle d'Aosta
  { id: "ao", nome: "Aosta", sigla: "AO", regione: "Valle d'Aosta/Vallée d'Aoste" },
  // Veneto
  { id: "bl", nome: "Belluno", sigla: "BL", regione: "Veneto" },
  { id: "pd", nome: "Padova",  sigla: "PD", regione: "Veneto" },
  { id: "ro", nome: "Rovigo",  sigla: "RO", regione: "Veneto" },
  { id: "tv", nome: "Treviso", sigla: "TV", regione: "Veneto" },
  { id: "ve", nome: "Venezia", sigla: "VE", regione: "Veneto" },
  { id: "vr", nome: "Verona",  sigla: "VR", regione: "Veneto" },
  { id: "vi", nome: "Vicenza", sigla: "VI", regione: "Veneto" },
];

// ============================================================
// Helpers
// ============================================================

// Quanti giorni mancano alla scadenza
function _giorniScadenza(scadenza) {
  if (scadenza === "Permanente" || scadenza === "Variabile") return 9999;
  try {
    const diff = new Date(scadenza) - new Date();
    return Math.ceil(diff / 86400000);
  } catch (_) { return 9999; }
}

// Stato visivo del bando
function statoScadenza(bando) {
  const gg = _giorniScadenza(bando.scadenza);
  if (bando.scadenza === "Permanente") return { label: "Sempre attivo", classe: "bg-green-100 text-green-700", icon: "♾️" };
  if (bando.scadenza === "Variabile")  return { label: "Sportello variabile", classe: "bg-blue-100 text-blue-700", icon: "📅" };
  if (gg < 0)                          return { label: "Scaduto", classe: "bg-red-100 text-red-600", icon: "❌" };
  if (gg <= 30)                        return { label: `Scade tra ${gg} gg`, classe: "bg-orange-100 text-orange-700", icon: "⚠️" };
  if (gg <= 90)                        return { label: `Scade tra ${gg} gg`, classe: "bg-amber-100 text-amber-700", icon: "⏳" };
  return { label: "Attivo", classe: "bg-green-100 text-green-700", icon: "✅" };
}

function cercaBandi(ateco, regione) {
  if (!ateco) return [];
  const prefisso = ateco.substring(0, 2);
  const info     = ATECO_SETTORI[prefisso];
  const settore  = info?.settore || null;

  return BANDI_DATABASE.filter(b => {
    // Filtra bandi scaduti
    if (!_isAttivo(b)) return false;

    const matchAteco   = b.atecoCodici.includes("tutti") ||
                         b.atecoCodici.some(c => prefisso.startsWith(c) || c.startsWith(prefisso));
    const matchSettore = !settore || b.settori.includes("tutti") || b.settori.includes(settore);
    const matchRegione = !regione || regione === "tutte" ||
                         b.regioni.includes("tutte") || b.regioni.includes(regione);
    return matchAteco && matchSettore && matchRegione;
  }).map(b => ({ ...b, _statoScadenza: statoScadenza(b) }));
}
