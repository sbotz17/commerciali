import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/categoria.dart';
import '../data/models/prodotto.dart';
import 'azienda_providers.dart';

/// Prodotti e categorie dell'azienda attiva in un unico caricamento.
///
/// Le due collezioni si mostrano insieme nella schermata Catalogo: caricate
/// insieme evitano due stati di caricamento separati.
class DatiCatalogo {
  const DatiCatalogo({required this.prodotti, required this.categorie});

  final List<Prodotto> prodotti;
  final List<Categoria> categorie;
}

/// Carica prodotti e categorie dell'azienda attiva.
///
/// Osserva [aziendaAttivaProvider]: al cambio di azienda ricarica da solo.
/// `ref.invalidate(catalogoProvider)` aggiorna la schermata dopo un
/// salvataggio o un'eliminazione.
final catalogoProvider = FutureProvider<DatiCatalogo>((ref) async {
  final servizio = ref.watch(spServiceProvider);
  servizio.setAziendaAttiva(ref.watch(aziendaAttivaProvider));
  final prodotti = await servizio.getProdotti();
  final categorie = await servizio.getCategorie();
  return DatiCatalogo(prodotti: prodotti, categorie: categorie);
});
