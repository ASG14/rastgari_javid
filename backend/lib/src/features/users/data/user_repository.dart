import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for user profiles.
class UserRepository {
  /// Checks whether another user already uses the given username.
  Future<bool> usernameExists({
    required String username,
    required int excludingUserId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        SELECT EXISTS (
          SELECT 1
          FROM public.users
          WHERE lower(username) = lower(@username)
            AND id <> @excludingUserId
            AND deleted_at IS NULL
        )
      '''),
      parameters: {
        'username': username,
        'excludingUserId': excludingUserId,
      },
    );

    return result.first[0] == true;
  }

  /// Retrieves the current profile for an active user.
  Future<Map<String, dynamic>?> getProfile(int userId) async {
    final result = await database.execute(
      Sql.named('''
        SELECT
          id,
          username,
          display_name,
          email,
          bio,
          avatar_storage_key,
          created_at
        FROM public.users
        WHERE id = @userId
          AND deleted_at IS NULL
          AND status = 'active'
        LIMIT 1
      '''),
      parameters: {'userId': userId},
    );

    if (result.isEmpty) return null;

    return result.first.toColumnMap();
  }

  /// Updates editable profile fields and returns the updated public profile.
  Future<Map<String, dynamic>?> updateProfile({
    required int userId,
    required String username,
    required String displayName,
    required bool updateBio,
    String? bio,
  }) async {
    final result = await database.execute(
      Sql.named('''
        UPDATE public.users
        SET
          username = @username,
          display_name = @displayName,
          bio = CASE
            WHEN @updateBio THEN CAST(@bio AS VARCHAR(500))
            ELSE bio
          END,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = @userId
          AND deleted_at IS NULL
          AND status = 'active'
        RETURNING
          id,
          username,
          display_name,
          email,
          bio,
          avatar_storage_key,
          created_at
      '''),
      parameters: {
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'updateBio': updateBio,
        'bio': bio,
      },
    );

    if (result.isEmpty) return null;

    return result.first.toColumnMap();
  }
}
