import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
final String id;
final String description;
final String userId;
final DateTime timestamp;
LogEntry({
required this.id,
required this.description,
required this.userId,
required this.timestamp,
});
factory LogEntry.fromFirestore(DocumentSnapshot doc) {
final data = doc.data() as Map<String, dynamic>;
return LogEntry(
id: doc.id,
description: data['description'] as String? ?? 'No description',
userId: data['userId'] as String? ?? 'Unknown User',
timestamp: (data['timestamp'] as Timestamp? ?? Timestamp.now()).toDate(),
);
}
/// A helper getter to extract the operation type from the description.
/// E.g., "created task 'New Feature'" -> "created task"
String get operationType {
final parts = description.split(' ');
if (parts.length >= 2) {
// Handles simple cases like "created task", "deleted column", "joined workspace"
return '${parts[0]} ${parts[1]}';
}
return 'general'; // Fallback
}
/// A helper getter to extract the user name from the end of the description.
/// E.g., "... by Test User" -> "Test User"
String get userName {
final parts = description.split(' by ');
if (parts.length > 1) {
return parts.last;
}
return userId; // Fallback to the user ID
}
}