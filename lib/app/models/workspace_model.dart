import 'package:cloud_firestore/cloud_firestore.dart';

class Workspace {
  final String id;
  String name;
  final String joinCode;
  final String ownerId;

  Workspace({ required this.id, required this.name, required this.joinCode, required this.ownerId});

  // Creates a Workspace object from a Firestore document
  factory Workspace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Workspace(
      id: doc.id,
      name: data['name'] ?? 'Untitled Workspace',
      joinCode: data['join_code'] ?? '',
      ownerId: data['ownerId'],
    );
  }
}