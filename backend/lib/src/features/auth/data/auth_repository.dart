import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for authentication.
class AuthRepository {
  /// Finds a user by username, ignoring letter case.
  Future<Map<String, dynamic>?> findByUsername(String username) async {
    final result = await database.execute(
      Sql.named('''
        SELECT
          id,
          username,
          display_name,
          email,
          password_hash,
          status
        FROM public.users
        WHERE lower(username) = lower(@username)
          AND deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'username': username},
    );

    if (result.isEmpty) return null;

    return result.first.toColumnMap();
  }

  /// Checks whether a username is already registered.
  Future<bool> usernameExists(String username) async {
    final result = await database.execute(
      Sql.named('''
        SELECT EXISTS (
          SELECT 1
          FROM public.users
          WHERE lower(username) = lower(@username)
            AND deleted_at IS NULL
        )
      '''),
      parameters: {'username': username},
    );

    return result.first[0] == true;
  }

  /// Checks whether an email is already registered.
  Future<bool> emailExists(String email) async {
    final result = await database.execute(
      Sql.named('''
        SELECT EXISTS (
          SELECT 1
          FROM public.users
          WHERE lower(email) = lower(@email)
            AND deleted_at IS NULL
        )
      '''),
      parameters: {'email': email},
    );

    return result.first[0] == true;
  }

  /// Inserts a new user and returns their public information.
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String displayName,
    required String passwordHash,
    String? email,
  }) async {
    final result = await database.execute(
      Sql.named('''
        INSERT INTO public.users (
          username,
          display_name,
          email,
          password_hash
        )
        VALUES (
          @username,
          @displayName,
          @email,
          @passwordHash
        )
        RETURNING id, username, display_name, email, created_at
      '''),
      parameters: {
        'username': username,
        'displayName': displayName,
        'email': email,
        'passwordHash': passwordHash,
      },
    );

    return result.first.toColumnMap();
  }

  /// Updates the last login timestamp.
  Future<void> updateLastLogin(int userId) async {
    await database.execute(
      Sql.named('''
        UPDATE public.users
        SET last_login_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = @id
      '''),
      parameters: {'id': userId},
    );
  }
  /// Finds an active user by ID without exposing sensitive fields.
Future<Map<String, dynamic>?> findById(int userId) async {
  final result = await database.execute(
    Sql.named('''
      SELECT
        id,
        username,
        display_name,
        email,
        created_at,
        status
      FROM public.users
      WHERE id = @id
        AND deleted_at IS NULL
      LIMIT 1
    '''),
    parameters: {'id': userId},
  );

  if (result.isEmpty) return null;

  return result.first.toColumnMap();
}
}
