/// Provincia italiana con la regione di appartenenza.
///
/// Serve al filtro territoriale dei bandi: i dati open data indicano spesso
/// solo la regione, quindi la provincia viene usata anche per risalire alla
/// regione quando il bando non espone un elenco di province.
class ProvinciaItalia {
  const ProvinciaItalia({
    required this.id,
    required this.nome,
    required this.sigla,
    required this.regione,
  });

  final String id;
  final String nome;
  final String sigla;
  final String regione;
}

/// Elenco delle province italiane, in ordine alfabetico.
const List<ProvinciaItalia> provinceItalia = [
  ProvinciaItalia(id: "ag", nome: "Agrigento", sigla: "AG", regione: "Sicilia"),
  ProvinciaItalia(
    id: "al",
    nome: "Alessandria",
    sigla: "AL",
    regione: "Piemonte",
  ),
  ProvinciaItalia(id: "an", nome: "Ancona", sigla: "AN", regione: "Marche"),
  ProvinciaItalia(
    id: "ao",
    nome: "Aosta",
    sigla: "AO",
    regione: "Valle d'Aosta/Vallée d'Aoste",
  ),
  ProvinciaItalia(id: "ar", nome: "Arezzo", sigla: "AR", regione: "Toscana"),
  ProvinciaItalia(
    id: "ap",
    nome: "Ascoli Piceno",
    sigla: "AP",
    regione: "Marche",
  ),
  ProvinciaItalia(id: "at", nome: "Asti", sigla: "AT", regione: "Piemonte"),
  ProvinciaItalia(id: "av", nome: "Avellino", sigla: "AV", regione: "Campania"),
  ProvinciaItalia(id: "ba", nome: "Bari", sigla: "BA", regione: "Puglia"),
  ProvinciaItalia(
    id: "bt",
    nome: "Barletta-Andria-Trani",
    sigla: "BT",
    regione: "Puglia",
  ),
  ProvinciaItalia(id: "bl", nome: "Belluno", sigla: "BL", regione: "Veneto"),
  ProvinciaItalia(
    id: "bn",
    nome: "Benevento",
    sigla: "BN",
    regione: "Campania",
  ),
  ProvinciaItalia(id: "bg", nome: "Bergamo", sigla: "BG", regione: "Lombardia"),
  ProvinciaItalia(id: "bi", nome: "Biella", sigla: "BI", regione: "Piemonte"),
  ProvinciaItalia(
    id: "bo",
    nome: "Bologna",
    sigla: "BO",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(
    id: "bz",
    nome: "Bolzano",
    sigla: "BZ",
    regione: "Trentino-Alto Adige/Südtirol",
  ),
  ProvinciaItalia(id: "bs", nome: "Brescia", sigla: "BS", regione: "Lombardia"),
  ProvinciaItalia(id: "br", nome: "Brindisi", sigla: "BR", regione: "Puglia"),
  ProvinciaItalia(id: "ca", nome: "Cagliari", sigla: "CA", regione: "Sardegna"),
  ProvinciaItalia(
    id: "cl",
    nome: "Caltanissetta",
    sigla: "CL",
    regione: "Sicilia",
  ),
  ProvinciaItalia(id: "cb", nome: "Campobasso", sigla: "CB", regione: "Molise"),
  ProvinciaItalia(id: "ce", nome: "Caserta", sigla: "CE", regione: "Campania"),
  ProvinciaItalia(id: "ct", nome: "Catania", sigla: "CT", regione: "Sicilia"),
  ProvinciaItalia(
    id: "cz",
    nome: "Catanzaro",
    sigla: "CZ",
    regione: "Calabria",
  ),
  ProvinciaItalia(id: "ch", nome: "Chieti", sigla: "CH", regione: "Abruzzo"),
  ProvinciaItalia(id: "co", nome: "Como", sigla: "CO", regione: "Lombardia"),
  ProvinciaItalia(id: "cs", nome: "Cosenza", sigla: "CS", regione: "Calabria"),
  ProvinciaItalia(id: "cr", nome: "Cremona", sigla: "CR", regione: "Lombardia"),
  ProvinciaItalia(id: "kr", nome: "Crotone", sigla: "KR", regione: "Calabria"),
  ProvinciaItalia(id: "cn", nome: "Cuneo", sigla: "CN", regione: "Piemonte"),
  ProvinciaItalia(id: "en", nome: "Enna", sigla: "EN", regione: "Sicilia"),
  ProvinciaItalia(id: "fm", nome: "Fermo", sigla: "FM", regione: "Marche"),
  ProvinciaItalia(
    id: "fe",
    nome: "Ferrara",
    sigla: "FE",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(id: "fi", nome: "Firenze", sigla: "FI", regione: "Toscana"),
  ProvinciaItalia(id: "fg", nome: "Foggia", sigla: "FG", regione: "Puglia"),
  ProvinciaItalia(
    id: "fc",
    nome: "Forlì-Cesena",
    sigla: "FC",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(id: "fr", nome: "Frosinone", sigla: "FR", regione: "Lazio"),
  ProvinciaItalia(id: "ge", nome: "Genova", sigla: "GE", regione: "Liguria"),
  ProvinciaItalia(
    id: "go",
    nome: "Gorizia",
    sigla: "GO",
    regione: "Friuli-Venezia Giulia",
  ),
  ProvinciaItalia(id: "gr", nome: "Grosseto", sigla: "GR", regione: "Toscana"),
  ProvinciaItalia(id: "im", nome: "Imperia", sigla: "IM", regione: "Liguria"),
  ProvinciaItalia(id: "is", nome: "Isernia", sigla: "IS", regione: "Molise"),
  ProvinciaItalia(id: "aq", nome: "L'Aquila", sigla: "AQ", regione: "Abruzzo"),
  ProvinciaItalia(id: "sp", nome: "La Spezia", sigla: "SP", regione: "Liguria"),
  ProvinciaItalia(id: "lt", nome: "Latina", sigla: "LT", regione: "Lazio"),
  ProvinciaItalia(id: "le", nome: "Lecce", sigla: "LE", regione: "Puglia"),
  ProvinciaItalia(id: "lc", nome: "Lecco", sigla: "LC", regione: "Lombardia"),
  ProvinciaItalia(id: "li", nome: "Livorno", sigla: "LI", regione: "Toscana"),
  ProvinciaItalia(id: "lo", nome: "Lodi", sigla: "LO", regione: "Lombardia"),
  ProvinciaItalia(id: "lu", nome: "Lucca", sigla: "LU", regione: "Toscana"),
  ProvinciaItalia(id: "mc", nome: "Macerata", sigla: "MC", regione: "Marche"),
  ProvinciaItalia(id: "mn", nome: "Mantova", sigla: "MN", regione: "Lombardia"),
  ProvinciaItalia(
    id: "ms",
    nome: "Massa-Carrara",
    sigla: "MS",
    regione: "Toscana",
  ),
  ProvinciaItalia(id: "mt", nome: "Matera", sigla: "MT", regione: "Basilicata"),
  ProvinciaItalia(id: "me", nome: "Messina", sigla: "ME", regione: "Sicilia"),
  ProvinciaItalia(id: "mi", nome: "Milano", sigla: "MI", regione: "Lombardia"),
  ProvinciaItalia(
    id: "mo",
    nome: "Modena",
    sigla: "MO",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(
    id: "mb",
    nome: "Monza e Brianza",
    sigla: "MB",
    regione: "Lombardia",
  ),
  ProvinciaItalia(id: "na", nome: "Napoli", sigla: "NA", regione: "Campania"),
  ProvinciaItalia(id: "no", nome: "Novara", sigla: "NO", regione: "Piemonte"),
  ProvinciaItalia(id: "nu", nome: "Nuoro", sigla: "NU", regione: "Sardegna"),
  ProvinciaItalia(id: "or", nome: "Oristano", sigla: "OR", regione: "Sardegna"),
  ProvinciaItalia(id: "pd", nome: "Padova", sigla: "PD", regione: "Veneto"),
  ProvinciaItalia(id: "pa", nome: "Palermo", sigla: "PA", regione: "Sicilia"),
  ProvinciaItalia(
    id: "pr",
    nome: "Parma",
    sigla: "PR",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(id: "pv", nome: "Pavia", sigla: "PV", regione: "Lombardia"),
  ProvinciaItalia(id: "pg", nome: "Perugia", sigla: "PG", regione: "Umbria"),
  ProvinciaItalia(
    id: "pu",
    nome: "Pesaro e Urbino",
    sigla: "PU",
    regione: "Marche",
  ),
  ProvinciaItalia(id: "pe", nome: "Pescara", sigla: "PE", regione: "Abruzzo"),
  ProvinciaItalia(
    id: "pc",
    nome: "Piacenza",
    sigla: "PC",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(id: "pi", nome: "Pisa", sigla: "PI", regione: "Toscana"),
  ProvinciaItalia(id: "pt", nome: "Pistoia", sigla: "PT", regione: "Toscana"),
  ProvinciaItalia(
    id: "pn",
    nome: "Pordenone",
    sigla: "PN",
    regione: "Friuli-Venezia Giulia",
  ),
  ProvinciaItalia(
    id: "pz",
    nome: "Potenza",
    sigla: "PZ",
    regione: "Basilicata",
  ),
  ProvinciaItalia(id: "po", nome: "Prato", sigla: "PO", regione: "Toscana"),
  ProvinciaItalia(id: "rg", nome: "Ragusa", sigla: "RG", regione: "Sicilia"),
  ProvinciaItalia(
    id: "ra",
    nome: "Ravenna",
    sigla: "RA",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(
    id: "rc",
    nome: "Reggio Calabria",
    sigla: "RC",
    regione: "Calabria",
  ),
  ProvinciaItalia(
    id: "re",
    nome: "Reggio Emilia",
    sigla: "RE",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(id: "ri", nome: "Rieti", sigla: "RI", regione: "Lazio"),
  ProvinciaItalia(
    id: "rn",
    nome: "Rimini",
    sigla: "RN",
    regione: "Emilia-Romagna",
  ),
  ProvinciaItalia(id: "rm", nome: "Roma", sigla: "RM", regione: "Lazio"),
  ProvinciaItalia(id: "ro", nome: "Rovigo", sigla: "RO", regione: "Veneto"),
  ProvinciaItalia(id: "sa", nome: "Salerno", sigla: "SA", regione: "Campania"),
  ProvinciaItalia(id: "ss", nome: "Sassari", sigla: "SS", regione: "Sardegna"),
  ProvinciaItalia(id: "sv", nome: "Savona", sigla: "SV", regione: "Liguria"),
  ProvinciaItalia(id: "si", nome: "Siena", sigla: "SI", regione: "Toscana"),
  ProvinciaItalia(id: "sr", nome: "Siracusa", sigla: "SR", regione: "Sicilia"),
  ProvinciaItalia(id: "so", nome: "Sondrio", sigla: "SO", regione: "Lombardia"),
  ProvinciaItalia(
    id: "su",
    nome: "Sud Sardegna",
    sigla: "SU",
    regione: "Sardegna",
  ),
  ProvinciaItalia(id: "ta", nome: "Taranto", sigla: "TA", regione: "Puglia"),
  ProvinciaItalia(id: "te", nome: "Teramo", sigla: "TE", regione: "Abruzzo"),
  ProvinciaItalia(id: "tr", nome: "Terni", sigla: "TR", regione: "Umbria"),
  ProvinciaItalia(id: "to", nome: "Torino", sigla: "TO", regione: "Piemonte"),
  ProvinciaItalia(id: "tp", nome: "Trapani", sigla: "TP", regione: "Sicilia"),
  ProvinciaItalia(
    id: "tn",
    nome: "Trento",
    sigla: "TN",
    regione: "Trentino-Alto Adige/Südtirol",
  ),
  ProvinciaItalia(id: "tv", nome: "Treviso", sigla: "TV", regione: "Veneto"),
  ProvinciaItalia(
    id: "ts",
    nome: "Trieste",
    sigla: "TS",
    regione: "Friuli-Venezia Giulia",
  ),
  ProvinciaItalia(
    id: "ud",
    nome: "Udine",
    sigla: "UD",
    regione: "Friuli-Venezia Giulia",
  ),
  ProvinciaItalia(id: "va", nome: "Varese", sigla: "VA", regione: "Lombardia"),
  ProvinciaItalia(id: "ve", nome: "Venezia", sigla: "VE", regione: "Veneto"),
  ProvinciaItalia(
    id: "vb",
    nome: "Verbano-Cusio-Ossola",
    sigla: "VB",
    regione: "Piemonte",
  ),
  ProvinciaItalia(id: "vc", nome: "Vercelli", sigla: "VC", regione: "Piemonte"),
  ProvinciaItalia(id: "vr", nome: "Verona", sigla: "VR", regione: "Veneto"),
  ProvinciaItalia(
    id: "vv",
    nome: "Vibo Valentia",
    sigla: "VV",
    regione: "Calabria",
  ),
  ProvinciaItalia(id: "vi", nome: "Vicenza", sigla: "VI", regione: "Veneto"),
  ProvinciaItalia(id: "vt", nome: "Viterbo", sigla: "VT", regione: "Lazio"),
];

/// Cerca una provincia per sigla o nome; `null` se non esiste.
ProvinciaItalia? provinciaPerCodice(String? codice) {
  final valore = (codice ?? '').trim().toLowerCase();
  if (valore.isEmpty) return null;
  for (final provincia in provinceItalia) {
    if (provincia.sigla.toLowerCase() == valore ||
        provincia.nome.toLowerCase() == valore) {
      return provincia;
    }
  }
  return null;
}
