import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Raised by repositories when a uniqueness constraint is violated.
class DuplicateValueException implements Exception {
  DuplicateValueException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Raised when a write is rejected for a business rule on the client.
class ValidationException implements Exception {
  ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Converts an error into a message that is safe and useful to show users.
String friendlyError(Object error) {
  if (error is DuplicateValueException) return error.message;
  if (error is ValidationException) return error.message;
  if (error is FirebaseFunctionsException) {
    if (error.code == 'not-found' || error.code == 'unavailable') {
      return 'The administrative backend is unavailable. Make sure Cloud '
          'Functions are deployed (${error.code}).';
    }
    return error.message ?? 'Backend error (${error.code}).';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'The server is unreachable. Check your connection.';
      case 'failed-precondition':
        return 'A required database index or precondition is missing. '
            '${error.message ?? ''}';
      default:
        return error.message ?? 'Firebase error (${error.code}).';
    }
  }
  return error.toString();
}
