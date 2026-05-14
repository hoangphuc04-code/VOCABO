// character_service.dart — Lưu/đọc nhân vật user từ Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/character_model.dart';

class CharacterService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static Stream<CharacterModel?> characterStream() {
    if (_uid.isEmpty) return Stream.value(null);
    return _db
        .collection('characters')
        .doc(_uid)
        .snapshots()
        .map((doc) => doc.exists
            ? CharacterModel.fromMap(doc.data()!)
            : null);
  }

  static Future<CharacterModel?> getCharacter() async {
    if (_uid.isEmpty) return null;
    final doc = await _db.collection('characters').doc(_uid).get();
    if (!doc.exists) return null;
    return CharacterModel.fromMap(doc.data()!);
  }

  static Future<void> saveCharacter(CharacterModel character) async {
    if (_uid.isEmpty) return;
    await _db.collection('characters').doc(_uid).set(character.toMap());
  }

  static Future<bool> hasCharacter() async {
    if (_uid.isEmpty) return false;
    final doc = await _db.collection('characters').doc(_uid).get();
    return doc.exists;
  }
}
