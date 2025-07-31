import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class LoggingService {
  static final _firestore = FirebaseFirestore.instance;

  /// Logs an action to both the workspace's and the user's personal log collections.
  /// This is a "fire-and-forget" operation; it won't block the UI.
  ///
  /// - [workspaceId]: The ID of the workspace where the action occurred.
  /// - [userId]: The UID of the user who performed the action.
  /// - [actionMessage]: The human-readable description of the action (e.g., "created task 'Deploy to Prod'").
  static void logAction({
    required String workspaceId,
    required String userId,
    required String actionMessage,
  }) {
    // We use `unawaited` to prevent lint warnings for not awaiting the future.
    // Logging is important, but we don't want it to slow down the user's main action.
    unawaited(_log(workspaceId: workspaceId, userId: userId, actionMessage: actionMessage));
  }

  static Future<void> _log({
    required String workspaceId,
    required String userId,
    required String actionMessage,
  }) async {
    try {
      // 1. Fetch the user's name to make the log description more readable.
      final userProfileDoc = await _firestore
          .collection('UserData')
          .doc(userId)
          .collection('ProfileData')
          .doc('main')
          .get();
      
      // Use the user's name, or their UID as a fallback.
      final userName = userProfileDoc.exists ? userProfileDoc.data()!['name'] ?? userId : userId;

      // 2. Prepare the log data.
      final String fullDescription = "$actionMessage by $userName";
      final Map<String, dynamic> logData = {
        'description': fullDescription,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 3. Write the log to the workspace's log collection.
      await _firestore
          .collection('Workspaces')
          .doc(workspaceId)
          .collection('Logs')
          .add(logData);

      // 4. Write the same log to the user's personal log collection.
      await _firestore
          .collection('UserData')
          .doc(userId)
          .collection('Logs')
          .add(logData);
          
    } catch (e) {
      // Log the error to the console, but don't bother the user.
      print("Error writing to log: $e");
    }
  }
}