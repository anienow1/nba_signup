import 'package:boom_signup/models/event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDatabase {
  static final FirestoreDatabase instance =
      FirestoreDatabase._privateConstructor();
  FirestoreDatabase._privateConstructor();

  final CollectionReference _eventCollection = FirebaseFirestore.instance
      .collection('nba');

  Future<String> insertEvent(Event event) async {
    final docRef = await _eventCollection.add(event.toMap());
    return docRef.id;
  }

  Future<void> deleteEvent(String id) async {
    await _eventCollection.doc(id).delete();
  }

  Future<void> updateEvent(Event event) async {
    if (event.id == null) {
      throw ArgumentError('Null Event id when updating.');
    }
    await _eventCollection.doc(event.id).update(event.toMap());
  }

  Future<void> addEntry(Event event, Entry entry) async {
    if (event.id == null) {
      throw ArgumentError('Null Event id when adding.');
    }
    if (entry.id == null) {
      throw ArgumentError('Null Entry id when adding.');
    }
    await _eventCollection.doc(event.id).update(
      {
        'entries': FieldValue.arrayUnion([entry.toMap()]),
      },
    );
  }

  Future<void> deleteEntry(Event event, Entry entry) async {
    if (event.id == null) {
      throw ArgumentError('Null Event id when deleting.');
    }
    if (entry.id == null) {
      throw ArgumentError('Null Entry id when deleting.');
    }
    await _eventCollection.doc(event.id).update(
      {
        'entries': FieldValue.arrayRemove([entry.toMap()]),
      },
    );
  }

  Future<List<Event>> getEvents() async {
    QuerySnapshot<Object?> snapshots = await _eventCollection.get();
    List<Event> events = [];
    for (QueryDocumentSnapshot<Object?> item in snapshots.docs) {
      final itemData = item.data();
      if (itemData is Map<String, dynamic>) {
        events.add(Event.fromMap(itemData, item.id));
      } 
    }
    return events;
  }
}
