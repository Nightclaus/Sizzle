import 'package:cloud_firestore/cloud_firestore.dart';

class Workspace {
  final String id;
  final String name;
  final String joinCode;

  Workspace({ required this.id, required this.name, required this.joinCode });

  // Creates a Workspace object from a Firestore document
  factory Workspace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Workspace(
      id: doc.id,
      name: data['name'] ?? 'Untitled Workspace',
      joinCode: data['join_code'] ?? '',
    );
  }
}