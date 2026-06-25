// ============================================================
// Edge Function: creditsafe
// Proxy sicuro verso Creditsafe API — le credenziali restano
// sul server (Supabase Secrets), mai esposte al browser.
//
// Deploy:
//   npx supabase functions deploy creditsafe \
//     --project-ref segbfdfoqxrnitboeyof --no-verify-jwt
//
// Secrets da impostare nel Dashboard Supabase → Settings → Edge Function Secrets:
//   CREDITSAFE_USERNAME = ilaria.prati@gabtamagnini.it
//   CREDITSAFE_PASSWORD = Gabtamagnini-01
// ============================================================

const CREDITSAFE_BASE = "https://connect.creditsafe.com/v1";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const body = await req.json() as { piva: string; action?: string; debug?: boolean };
    const { piva, action, debug } = body;

    // ── Modalità VIES-only (autocompila form cliente) ────────
    if (action === "vies") {
      if (!piva) return json({ ok: false, error: "Parametro 'piva' mancante" }, 400);
      const pivaClean = piva.trim().replace(/^IT/i, "");
      const viesRes = await fetch(
        `https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat/${pivaClean}`,
        { headers: { "Accept": "application/json" } }
      );
      if (!viesRes.ok) return json({ ok: false, error: `VIES HTTP ${viesRes.status}` }, 502);
      const d = await viesRes.json() as { isValid?: boolean; valid?: boolean; name?: string; address?: string; userError?: string };
      const isValid = d.isValid ?? d.valid ?? false;
      if (!isValid) return json({ ok: false, error: "Partita IVA non valida o non attiva nel VIES" });
      // VIES può restituire "---" quando l'azienda non espone i dati
      const name    = (d.name    && d.name    !== "---") ? d.name    : "";
      const address = (d.address && d.address !== "---") ? d.address : "";
      return json({ ok: true, valid: true, name, address });
    }
    if (!piva) {
      return json({ ok: false, error: "Parametro 'piva' mancante" }, 400);
    }

    const username = Deno.env.get("CREDITSAFE_USERNAME");
    const password = Deno.env.get("CREDITSAFE_PASSWORD");
    if (!username || !password) {
      return json({ ok: false, error: "Credenziali Creditsafe non configurate nei Secrets" }, 500);
    }

    // 1. Autenticazione → token JWT (valido 1h)
    const authRes = await fetch(`${CREDITSAFE_BASE}/authenticate`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ username, password }),
    });
    if (!authRes.ok) {
      const txt = await authRes.text();
      return json({ ok: false, error: `Auth fallita: ${authRes.status} — ${txt.substring(0, 200)}` }, 502);
    }
    const { token } = await authRes.json() as { token: string };
    const authHeader = { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" };

    // Normalizza P.IVA: rimuovi spazi e prefisso IT se presente
    const pivaClean = piva.trim().toUpperCase().replace(/^IT/, "");

    // 2. Ricerca azienda — prova più strategie in sequenza
    let aziende: any[] = [];

    const searchStrategies = [
      // vatNo senza prefisso (più comune per IT)
      `${CREDITSAFE_BASE}/companies?countries=IT&language=EN&page=1&pageSize=5&vatNo=${pivaClean}`,
      // vatNo con prefisso IT
      `${CREDITSAFE_BASE}/companies?countries=IT&language=EN&page=1&pageSize=5&vatNo=IT${pivaClean}`,
      // regNo senza prefisso
      `${CREDITSAFE_BASE}/companies?countries=IT&language=EN&page=1&pageSize=5&regNo=${pivaClean}`,
      // regNo con prefisso IT
      `${CREDITSAFE_BASE}/companies?countries=IT&language=EN&page=1&pageSize=5&regNo=IT${pivaClean}`,
    ];

    for (const searchUrl of searchStrategies) {
      const searchRes = await fetch(searchUrl, { headers: authHeader });
      if (!searchRes.ok) continue;
      const searchData = await searchRes.json() as { companies?: any[], totalSize?: number };
      aziende = searchData.companies ?? [];
      if (aziende.length > 0) break;
    }

    if (aziende.length === 0) {
      return json({ ok: false, error: `Nessuna azienda trovata con P.IVA ${pivaClean} — verifica che sia attiva nel registro imprese` });
    }

    const azienda = aziende[0];
    const connectId = azienda.id;

    // 3. Report completo — prova più template fino a trovarne uno con dati
    let report: any = null;
    let rawReportData: any = null;
    const reportTemplates = ["", "full", "standard", "companyProfile"];
    for (const tpl of reportTemplates) {
      const tplParam = tpl ? `&template=${tpl}` : "";
      const url = `${CREDITSAFE_BASE}/companies/${connectId}?language=EN${tplParam}`;
      const res = await fetch(url, { headers: authHeader });
      if (!res.ok) continue;
      const body = await res.json() as { report?: any };
      if (!rawReportData) rawReportData = body;
      if (body.report && Object.keys(body.report).length > 0) {
        rawReportData = body;
        report = body.report;
        break;
      }
    }

    // Modalità debug: restituisce tutto il grezzo per diagnostica
    if (debug) {
      return json({ ok: true, _rawReportData: rawReportData, _azienda: azienda });
    }

    if (!report || Object.keys(report).length === 0) {
      // Report vuoto: restituiamo solo i dati dalla ricerca (senza bilanci/score)
      return json({
        ok: true,
        connectId,
        ragioneSociale:  azienda.name ?? "",
        piva:            pivaClean,
        stato:           azienda.status ?? "",
        formaGiuridica:  azienda.type ?? "",
        indirizzo:       azienda.address?.simpleValue ?? `${azienda.address?.street ?? ""} ${azienda.address?.city ?? ""}`.trim(),
        provincia:       azienda.address?.province ?? "",
        cap:             azienda.address?.postCode ?? "",
        citta:           azienda.address?.city ?? "",
        ateco:           azienda.activityCode ?? "",
        settore:         azienda.activity?.description ?? "",
        dipendenti: null, score: null, scoreDescrizione: null,
        limiteCreditizio: null, valutaCreditizio: "EUR",
        fatturato: null, utile: null, patrimonio: null,
        segnaliNegativi: 0, telefono: "", email: "", sito: "",
        amministratori: [],
        _avviso: "Report completo non disponibile per questa azienda nel piano corrente",
      });
    }

    // 4. Costruisci risposta strutturata
    const creditScore  = report?.creditScore?.currentCreditRating ?? null;

    // Bilanci: prendi il primo disponibile, prova più path
    const stmts = report?.financialStatements ?? [];
    const stmt0 = stmts[0] ?? null;
    const pnl   = stmt0?.profitAndLoss ?? stmt0?.localFinancials?.profitAndLoss ?? null;
    const bal   = stmt0?.balanceSheet   ?? stmt0?.localFinancials?.balanceSheet   ?? null;

    const directors   = (report?.directors?.currentDirectors ?? []).slice(0, 5);
    const negativeSig = report?.negativeInformation?.count ?? report?.negativeInformation?.totalCount ?? 0;

    // Dipendenti: può essere numero diretto o oggetto {value, date}
    const empRaw = report?.companyIdentification?.basicInformation?.numberOfEmployees;
    const dipendenti = typeof empRaw === "number" ? empRaw : (empRaw?.value ?? null);

    // Limite credito: può essere oggetto o valore diretto
    const creditLimitRaw = creditScore?.creditLimit;
    const limiteCreditizio = typeof creditLimitRaw === "number"
      ? creditLimitRaw
      : (creditLimitRaw?.value ?? null);

    const risultato = {
      ok:              true,
      connectId,
      // Debug: struttura raw per diagnostica (rimovibile in prod)
      _rawKeys: report ? Object.keys(report) : [],
      _stmtKeys: stmt0 ? Object.keys(stmt0) : [],
      _pnlKeys:  pnl   ? Object.keys(pnl)   : [],
      // Dati base
      ragioneSociale:  azienda.name ?? report?.companyIdentification?.basicInformation?.registeredCompanyName ?? "",
      piva:            pivaClean,
      stato:           azienda.status ?? report?.companyIdentification?.basicInformation?.companyStatus?.status ?? "",
      formaGiuridica:  azienda.type ?? report?.companyIdentification?.basicInformation?.legalForm ?? "",
      dataCostituzione: report?.companyIdentification?.basicInformation?.companyIncorporationDate ?? null,
      // Sede
      indirizzo:       azienda.address?.simpleValue
                         ?? `${azienda.address?.street ?? ""} ${azienda.address?.city ?? ""}`.trim(),
      provincia:       azienda.address?.province ?? "",
      cap:             azienda.address?.postCode ?? "",
      citta:           azienda.address?.city ?? "",
      // Attività
      ateco:           azienda.activityCode ?? "",
      settore:         azienda.activity?.description ?? "",
      dipendenti,
      // Score creditizio
      score:            creditScore?.commonValue ?? creditScore?.providerValue?.value ?? null,
      scoreDescrizione: creditScore?.commonDescription ?? creditScore?.providerValue?.maxValue ?? null,
      limiteCreditizio,
      valutaCreditizio: creditLimitRaw?.currency ?? "EUR",
      // Finanziari — prova più nomi campo
      fatturato: pnl?.totalRevenue ?? pnl?.revenue ?? pnl?.turnover ?? pnl?.netSales ?? null,
      utile:     pnl?.netProfit ?? pnl?.profitAfterTax ?? pnl?.profitBeforeTax ?? null,
      patrimonio: bal?.totalShareholdersEquity ?? bal?.equity ?? null,
      // Segnali negativi
      segnaliNegativi: negativeSig,
      // Contatti
      telefono:        report?.contactInformation?.mainAddress?.telephone ?? "",
      email:           report?.contactInformation?.emailAddresses?.[0] ?? "",
      sito:            report?.contactInformation?.websites?.[0] ?? "",
      // Amministratori
      amministratori:  directors.map((d: any) => ({
        nome:    `${d.firstName ?? ""} ${d.lastName ?? ""}`.trim(),
        ruolo:   d.position?.positionName ?? "",
        dataNomina: d.directorships?.[0]?.dateOfAppointment ?? null,
      })),
    };

    return json(risultato);

  } catch (e: any) {
    return json({ ok: false, error: e.message ?? "Errore interno" }, 500);
  }
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
