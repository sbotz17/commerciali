// Stub per piattaforme non web: le notifiche push non sono disponibili.
bool get supportato => false;

Future<Map<String, dynamic>> iscrivi() async {
  return {
    'ok': false,
    'errore': 'Le notifiche push sono disponibili solo nella versione web.',
  };
}

Future<void> annulla() async {}
