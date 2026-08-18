import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../helpers/logging_service.dart';

/// Shared base for GetX controllers that talk to Firebase.
///
/// Centralizes what every controller in this app was repeating:
/// - direct access to Firestore/FirebaseAuth singletons
/// - a single `isLoading` observable
/// - the "try { ... } catch { snackbar } finally { isLoading = false }"
///   pattern that showed up in nearly every async method
/// - small Firestore read/write helpers (get collection -> List<Model>,
///   set/update/delete a doc, batch-delete a where-query)
abstract class BaseFirebaseController extends GetxController {
  @protected
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @protected
  final FirebaseAuth auth = FirebaseAuth.instance;

  /// Generic loading flag. Controllers that need more than one
  /// independent loading state can add extra RxBools on top of this.
  final isLoading = false.obs;

  String? get userId => auth.currentUser?.uid;

  /// Runs [action], toggling [isLoading] around it (unless
  /// [manageLoading] is false), logging and snackbar-ing on failure.
  /// Returns the action's result, or null if it threw.
  @protected
  Future<T?> runSafely<T>(
    Future<T> Function() action, {
    String errorTitle = "Error",
    String errorMessage = "Something went wrong.",
    bool manageLoading = true,
    void Function(Object error)? onError,
  }) async {
    if (manageLoading) isLoading.value = true;
    try {
      return await action();
    } catch (e, st) {
      debugPrint("[$runtimeType] $errorTitle: $e\n$st");
      Get.snackbar(errorTitle, errorMessage, snackPosition: SnackPosition.BOTTOM);
      onError?.call(e);
      return null;
    } finally {
      if (manageLoading) isLoading.value = false;
    }
  }

  /// Fetches a query/collection and maps each doc through [fromDoc].
  @protected
  Future<List<M>> fetchCollection<M>(
    Query<Map<String, dynamic>> query,
    M Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDoc,
  ) async {
    final snapshot = await query.get();
    return snapshot.docs.map(fromDoc).toList();
  }

  /// Fetches documents matching a single where-clause and maps them.
  @protected
  Future<List<M>> fetchWhere<M>(
    CollectionReference<Map<String, dynamic>> ref,
    String field,
    dynamic isEqualTo,
    M Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDoc,
  ) {
    return fetchCollection(ref.where(field, isEqualTo: isEqualTo), fromDoc);
  }

  /// Creates/overwrites a document.
  @protected
  Future<void> setDoc(
    CollectionReference<Map<String, dynamic>> ref,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    return ref.doc(docId).set(data, SetOptions(merge: merge));
  }

  /// Updates fields on an existing document.
  @protected
  Future<void> updateDoc(
    CollectionReference<Map<String, dynamic>> ref,
    String docId,
    Map<String, dynamic> data,
  ) {
    return ref.doc(docId).update(data);
  }

  /// Deletes a document.
  @protected
  Future<void> deleteDoc(
    CollectionReference<Map<String, dynamic>> ref,
    String docId,
  ) {
    return ref.doc(docId).delete();
  }

  /// Queues deletion of every doc in [ref] matching [field] == [isEqualTo]
  /// onto [batch]. Caller still owns and commits the batch.
  @protected
  Future<void> batchDeleteWhere(
    WriteBatch batch,
    CollectionReference<Map<String, dynamic>> ref,
    String field,
    dynamic isEqualTo,
  ) async {
    final snapshot = await ref.where(field, isEqualTo: isEqualTo).get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
  }
}

/// Adds a guarded call to [LoggingService.logAction] for controllers that
/// log workspace activity — a no-op until both ids are resolved.
mixin WorkspaceLoggingMixin on GetxController {
  void logWorkspaceAction({
    required String? workspaceId,
    required String? userId,
    required String message,
  }) {
    if (workspaceId != null && userId != null) {
      LoggingService.logAction(
        workspaceId: workspaceId,
        userId: userId,
        actionMessage: message,
      );
    }
  }
}