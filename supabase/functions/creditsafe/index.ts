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
    const body = await req.json() as { piva: string; action?: string };
    const { piva, action } = body;

    // ── Modalità VIES-only (autocompila form cliente) ────────
    if (action === "vies") {
      if (!piva) return json({ ok: false, error: "Parametro 'piva' mancante" }, 400);
      const pivaClean = piva.trim().replace(/^IT/i, "");
      const viesRes = await fetch(
        `https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat/${pivaClean}`,
        { headers: { "Accept": "application/json" } }
      );
      if (!viesRes.ok) return json({ ok: false, error: `VIES HTTP ${viesRes.status}` }, 502);
      const d = await viesRes.json() as { valid: boolean; name?: string; address?: string };
      if (!d.valid) return json({ ok: false, error: "Partita IVA non valida o non attiva nel VIES" });
      return json({ ok: true, valid: true, name: d.name ?? "", address: d.address ?? "" });
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

    // 2. Ricerca azienda per P.IVA (regNo)
    const searchUrl = `${CREDITSAFE_BASE}/companies?countries=IT&language=EN&page=1&pageSize=5&regNo=IT${pivaClean}`;
    const searchRes = await fetch(searchUrl, { headers: authHeader });
    if (!searchRes.ok) {
      const txt = await searchRes.text();
      return json({ ok: false, error: `Ricerca fallita: ${searchRes.status} — ${txt.substring(0, 200)}` }, 502);
    }
    const searchData = await searchRes.json() as { companies?: any[], totalSize?: number };
    const aziende = searchData.companies ?? [];

    if (aziende.length === 0) {
      return json({ ok: false, error: "Nessuna azienda trovata con questa Partita IVA" });
    }

    const azienda = aziende[0];
    const connectId = azienda.id;

    // 3. Report completo (score creditizio, dati finanziari, ecc.)
    const reportRes = await fetch(`${CREDITSAFE_BASE}/companies/${connectId}?language=EN`, {
      headers: authHeader,
    });

    let report: any = null;
    if (reportRes.ok) {
      const reportData = await reportRes.json() as { report?: any };
      report = reportData.report ?? null;
    }

    // 4. Costruisci risposta strutturata
    const creditScore  = report?.creditScore?.currentCreditRating ?? null;
    const financials   = report?.financialStatements?.[0]?.profitAndLoss ?? null;
    const directors    = (report?.directors?.currentDirectors ?? []).slice(0, 5);
    const negativeSig  = report?.negativeInformation?.count ?? 0;

    const risultato = {
      ok:              true,
      connectId,
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
      dipendenti:      report?.companyIdentification?.basicInformation?.numberOfEmployees?.value ?? null,
      // Score creditizio
      score:           creditScore?.commonValue ?? null,           // AAA / AA / A / BB / B / C / D
      scoreDescrizione: creditScore?.commonDescription ?? null,
      limiteCreditizio: creditScore?.creditLimit?.value ?? null,
      valutaCreditizio: creditScore?.creditLimit?.currency ?? "EUR",
      // Finanziari (ultimo bilancio disponibile)
      fatturato:       financials?.totalRevenue ?? null,
      utile:           financials?.netProfit ?? null,
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
