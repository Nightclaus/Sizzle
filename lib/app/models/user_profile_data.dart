import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileData {
  final String name;
  final String handle;
  final String description;
  final bool isAdmin; 
  final String? mostRecentWorkspaceId;

  UserProfileData({ 
    required this.name, 
    required this.handle, 
    required this.description,
    this.mostRecentWorkspaceId,
    this.isAdmin = false,
  });

  factory UserProfileData.fromMap(Map<String, dynamic> map) {
    return UserProfileData(
      name: map['name'] as String? ?? 'No Name',
      handle: map['handle'] as String? ?? 'No Handle',
      description: map['description'] as String? ?? '',
      isAdmin: map['isAdmin'] as bool? ?? false,
      mostRecentWorkspaceId: map['mostRecentWorkspaceId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name, 
      'handle': handle, 
      'description': description,
      'isAdmin': isAdmin,
      'mostRecentWorkspaceId': mostRecentWorkspaceId,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}