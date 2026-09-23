/// Local-first RAG (§34-35): session vs event vs long-term vs clinical.
/// Prototype uses keyword scoring over in-memory docs; interface allows
/// vector-store swap later.
class MemoryDocument {
  final String id;
  final String collection;
  final String text;
  final Map<String, dynamic> meta;
  final DateTime updated;
  MemoryDocument(this.id, this.collection, this.text, {Map<String, dynamic>? meta, DateTime? updated})
      : meta = meta ?? {}, updated = updated ?? DateTime.now();

  Map<String, dynamic> toJson() => {'id': id, 'collection': collection, 'text': text, 'meta': meta};
}

class MemoryStore {
  final List<MemoryDocument> _docs = [];

  void upsert(MemoryDocument doc) {
    _docs.removeWhere((d) => d.id == doc.id);
    _docs.add(doc);
  }

  void remove(String id) => _docs.removeWhere((d) => d.id == id);

  List<MemoryDocument> retrieve(String query, {int topK = 4, List<String>? collections}) {
    final q = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    final scored = <MapEntry<MemoryDocument, int>>[];
    for (final d in _docs) {
      if (collections != null && !collections.contains(d.collection)) continue;
      final t = d.text.toLowerCase();
      int score = 0;
      for (final w in q) {
        if (t.contains(w)) score += 2;
      }
      // Recency + long-term preference boost
      if (d.collection == 'CommunicationPreferences') score += 1;
      if (score > 0) scored.add(MapEntry(d, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topK).map((e) => e.key).toList();
  }

  List<MemoryDocument> all() => List.unmodifiable(_docs);

  static MemoryStore withDefaults() {
    final store = MemoryStore();
    store.upsert(MemoryDocument('pref-yesno', 'CommunicationPreferences',
        'Smile = yes. Triple blink = call caregiver. Patient cannot reliably nod.'));
    store.upsert(MemoryDocument('pref-comfort', 'FrequentlyRequestedNeeds',
        'Patient usually requests repositioning when uncomfortable.'));
    store.upsert(MemoryDocument('pref-care', 'CaregiverContacts',
        'Preferred primary caregiver: Daughter.'));
    store.upsert(MemoryDocument('pref-style', 'CompanionPreferences',
        'Prefers very short questions. Likes cricket, short Bengali jokes, Rabindra Sangeet.'));
    return store;
  }
}
