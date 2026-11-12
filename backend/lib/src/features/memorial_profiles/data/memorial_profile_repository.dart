import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for memorial profiles and memberships.
class MemorialProfileRepository {
  /// Creates a memorial profile and its creator's membership atomically.
  ///
  /// The creator is the sole owner of the profile through
  /// memorial_profiles.created_by_user_id.
  /// Their membership only stores their relationship with the deceased.
  Future<Map<String, dynamic>> createProfile({
    required int userId,
    required String fullName,
    required String relationship,
    DateTime? birthDate,
    DateTime? deathDate,
    String? memorialText,
    String? graveAddress,
    int? photoMediaAssetId,
  }) {
    return database.runTx((session) async {
      // Verify that the supplied photo belongs to this user
      // and has been successfully processed.
      if (photoMediaAssetId != null) {
        final mediaResult = await session.execute(
          Sql.named('''
            SELECT id
            FROM public.media_assets
            WHERE id = @mediaAssetId
              AND uploaded_by_user_id = @userId
              AND media_type = 'image'
              AND processing_status = 'ready'
            LIMIT 1
          '''),
          parameters: {
            'mediaAssetId': photoMediaAssetId,
            'userId': userId,
          },
        );

        if (mediaResult.isEmpty) {
          throw const MemorialProfileRepositoryException(
            'تصویر انتخاب‌شده معتبر یا قابل استفاده نیست.',
          );
        }
      }

      final profileResult = await session.execute(
        Sql.named('''
          INSERT INTO public.memorial_profiles (
            created_by_user_id,
            full_name,
            photo_media_asset_id,
            birth_date,
            death_date,
            memorial_text,
            grave_address
          )
          VALUES (
            @userId,
            @fullName,
            @photoMediaAssetId,
            @birthDate,
            @deathDate,
            @memorialText,
            @graveAddress
          )
          RETURNING
            id,
            created_by_user_id,
            full_name,
            photo_media_asset_id,
            birth_date,
            death_date,
            memorial_text,
            grave_address,
            created_at
        '''),
        parameters: {
          'userId': userId,
          'fullName': fullName,
          'photoMediaAssetId': photoMediaAssetId,
          'birthDate': birthDate,
          'deathDate': deathDate,
          'memorialText': memorialText,
          'graveAddress': graveAddress,
        },
      );

      if (profileResult.isEmpty) {
        throw StateError('The memorial profile was not created.');
      }

      final profile = profileResult.first.toColumnMap();
      final profileId = profile['id'] as int;

      // Store the creator's relationship with the deceased.
      // Ownership is determined exclusively by created_by_user_id.
      final membershipResult = await session.execute(
        Sql.named('''
          INSERT INTO public.memorial_members (
            memorial_profile_id,
            user_id,
            relationship
          )
          VALUES (
            @profileId,
            @userId,
            CAST(@relationship AS public.memorial_relationship)
          )
          RETURNING
            id,
            relationship::text AS relationship,
            notifications_enabled
        '''),
        parameters: {
          'profileId': profileId,
          'userId': userId,
          'relationship': relationship,
        },
      );

      if (membershipResult.isEmpty) {
        throw StateError('The memorial membership was not created.');
      }

      final membership = membershipResult.first.toColumnMap();

      final mappedProfile = _mapProfile(profile);
      mappedProfile['membership'] = _mapMembership(membership);

      return mappedProfile;
    });
  }

  /// Searches active memorial profiles by name.
  ///
  /// Duplicate names are allowed and returned as separate profiles.
  Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    int limit = 20,
  }) async {
    final result = await database.execute(
      Sql.named('''
        SELECT
          mp.id,
          mp.full_name,
          mp.photo_media_asset_id,
          mp.birth_date,
          mp.death_date,
          mp.memorial_text,
          mp.grave_address,
          mp.created_at,
          u.display_name AS creator_display_name,
          (
            SELECT COUNT(*)::BIGINT
            FROM public.memorial_members AS mm
            WHERE mm.memorial_profile_id = mp.id
          ) AS members_count
        FROM public.memorial_profiles AS mp
        JOIN public.users AS u
          ON u.id = mp.created_by_user_id
        WHERE mp.deleted_at IS NULL
          AND u.deleted_at IS NULL
          AND u.status = 'active'
          AND lower(mp.full_name) LIKE lower(@query)
        ORDER BY
          CASE
            WHEN lower(mp.full_name) = lower(@exactQuery) THEN 0
            WHEN lower(mp.full_name) LIKE lower(@prefixQuery) THEN 1
            ELSE 2
          END,
          mp.created_at DESC,
          mp.id DESC
        LIMIT @limit
      '''),
      parameters: {
        'query': '%$query%',
        'exactQuery': query,
        'prefixQuery': '$query%',
        'limit': limit,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();

      return {
        'id': data['id'],
        'full_name': data['full_name'],
        'photo_media_asset_id': data['photo_media_asset_id'],
        'birth_date': _formatDate(data['birth_date']),
        'death_date': _formatDate(data['death_date']),
        'memorial_text': data['memorial_text'],
        'grave_address': data['grave_address'],
        'created_at': data['created_at']?.toString(),
        'creator_display_name': data['creator_display_name'],
        'members_count': data['members_count'],
      };
    }).toList();
  }

  /// Follows an existing memorial profile.
  ///
  /// If the user already follows the profile, their relationship is updated.
  Future<Map<String, dynamic>?> followProfile({
    required int profileId,
    required int userId,
    required String relationship,
  }) {
    return database.runTx((session) async {
      final profileResult = await session.execute(
        Sql.named('''
          SELECT id
          FROM public.memorial_profiles
          WHERE id = @profileId
            AND deleted_at IS NULL
          LIMIT 1
        '''),
        parameters: {'profileId': profileId},
      );

      if (profileResult.isEmpty) {
        return null;
      }

      final result = await session.execute(
        Sql.named('''
          INSERT INTO public.memorial_members (
            memorial_profile_id,
            user_id,
            relationship
          )
          VALUES (
            @profileId,
            @userId,
            CAST(@relationship AS public.memorial_relationship)
          )
          ON CONFLICT (memorial_profile_id, user_id)
          DO UPDATE SET
            relationship = EXCLUDED.relationship,
            updated_at = CURRENT_TIMESTAMP
          RETURNING
            id,
            memorial_profile_id,
            user_id,
            relationship::text AS relationship,
            notifications_enabled,
            created_at,
            updated_at
        '''),
        parameters: {
          'profileId': profileId,
          'userId': userId,
          'relationship': relationship,
        },
      );

      if (result.isEmpty) {
        throw StateError('The memorial membership was not created.');
      }

      final membership = result.first.toColumnMap();

      return {
        'id': membership['id'],
        'memorial_profile_id': membership['memorial_profile_id'],
        'user_id': membership['user_id'],
        'relationship': _databaseText(membership['relationship']),
        'notifications_enabled': membership['notifications_enabled'],
        'created_at': membership['created_at']?.toString(),
        'updated_at': membership['updated_at']?.toString(),
      };
    });
  }

  /// Retrieves a memorial profile and the current user's membership.
  ///
  /// Ownership is determined by created_by_user_id.
  /// Membership only represents following and the declared relationship.
  Future<Map<String, dynamic>?> getProfileById({
    required int profileId,
    required int userId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        SELECT
          mp.id,
          mp.created_by_user_id,
          mp.full_name,
          mp.photo_media_asset_id,
          mp.birth_date,
          mp.death_date,
          mp.memorial_text,
          mp.grave_address,
          mp.created_at,
          mp.updated_at,

          creator.display_name AS creator_display_name,

          (
            SELECT COUNT(*)::BIGINT
            FROM public.memorial_members AS members
            WHERE members.memorial_profile_id = mp.id
          ) AS members_count,

          membership.id AS membership_id,
          membership.relationship::text AS membership_relationship,
          membership.notifications_enabled

        FROM public.memorial_profiles AS mp

        INNER JOIN public.users AS creator
          ON creator.id = mp.created_by_user_id

        LEFT JOIN public.memorial_members AS membership
          ON membership.memorial_profile_id = mp.id
          AND membership.user_id = @userId

        WHERE mp.id = @profileId
          AND mp.deleted_at IS NULL
          AND creator.deleted_at IS NULL
          AND creator.status = 'active'

        LIMIT 1
      '''),
      parameters: {
        'profileId': profileId,
        'userId': userId,
      },
    );

    if (result.isEmpty) {
      return null;
    }

    final data = result.first.toColumnMap();

    Map<String, dynamic>? membership;

    if (data['membership_id'] != null) {
      membership = {
        'id': data['membership_id'],
        'relationship': _databaseText(data['membership_relationship']),
        'notifications_enabled': data['notifications_enabled'],
      };
    }

    return {
      'id': data['id'],
      'created_by_user_id': data['created_by_user_id'],
      'full_name': data['full_name'],
      'photo_media_asset_id': data['photo_media_asset_id'],
      'birth_date': _formatDate(data['birth_date']),
      'death_date': _formatDate(data['death_date']),
      'memorial_text': data['memorial_text'],
      'grave_address': data['grave_address'],
      'created_at': data['created_at']?.toString(),
      'updated_at': data['updated_at']?.toString(),
      'creator_display_name': data['creator_display_name'],
      'members_count': data['members_count'],
      'membership': membership,
    };
  }

  /// Converts PostgreSQL text values to Dart strings.
  ///
  /// Custom PostgreSQL types may be returned as UndecodedBytes by the driver.

  /// Updates a memorial profile. Only its creator can edit it.
  Future<Map<String, dynamic>?> updateProfile({
    required int profileId,
    required int userId,
    required String fullName,
    DateTime? birthDate,
    DateTime? deathDate,
    String? memorialText,
    String? graveAddress,
    int? photoMediaAssetId,
  }) async {
    return database.runTx((session) async {
      if (photoMediaAssetId != null) {
        final media = await session.execute(
          Sql.named('''
            SELECT id
            FROM public.media_assets
            WHERE id = @mediaId
              AND uploaded_by_user_id = @userId
              AND media_type = 'image'
              AND processing_status = 'ready'
            LIMIT 1
          '''),
          parameters: {
            'mediaId': photoMediaAssetId,
            'userId': userId,
          },
        );

        if (media.isEmpty) {
          throw const MemorialProfileRepositoryException(
            'تصویر انتخاب‌شده معتبر یا قابل استفاده نیست.',
          );
        }
      }

      final result = await session.execute(
        Sql.named('''
          UPDATE public.memorial_profiles
          SET
            full_name = @fullName,
            birth_date = @birthDate,
            death_date = @deathDate,
            memorial_text = @memorialText,
            grave_address = @graveAddress,
            photo_media_asset_id = @photoMediaAssetId,
            updated_at = CURRENT_TIMESTAMP
          WHERE id = @profileId
            AND created_by_user_id = @userId
            AND deleted_at IS NULL
          RETURNING
            id,
            created_by_user_id,
            full_name,
            photo_media_asset_id,
            birth_date,
            death_date,
            memorial_text,
            grave_address,
            created_at,
            updated_at
        '''),
        parameters: {
          'profileId': profileId,
          'userId': userId,
          'fullName': fullName,
          'birthDate': birthDate,
          'deathDate': deathDate,
          'memorialText': memorialText,
          'graveAddress': graveAddress,
          'photoMediaAssetId': photoMediaAssetId,
        },
      );

      if (result.isEmpty) return null;

      return _mapProfile(result.first.toColumnMap())
        ..['updated_at'] = result.first.toColumnMap()['updated_at']?.toString();
    });
  }

  /// Soft-deletes a memorial profile. Only its creator can delete it.
  Future<bool> deleteProfile({
    required int profileId,
    required int userId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        UPDATE public.memorial_profiles
        SET
          deleted_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = @profileId
          AND created_by_user_id = @userId
          AND deleted_at IS NULL
        RETURNING id
      '''),
      parameters: {
        'profileId': profileId,
        'userId': userId,
      },
    );

    return result.isNotEmpty;
  }

  /// Returns profiles created or followed by a user.
  Future<List<Map<String, dynamic>>> getUserProfiles({
    required int userId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        SELECT
          mp.id,
          mp.created_by_user_id,
          mp.full_name,
          mp.photo_media_asset_id,
          mp.birth_date,
          mp.death_date,
          mp.memorial_text,
          mp.grave_address,
          mp.created_at,
          mp.updated_at,
          (mp.created_by_user_id = @userId) AS is_creator,
          mm.relationship::text AS relationship,
          (
            SELECT COUNT(*)::BIGINT
            FROM public.memorial_members AS members
            WHERE members.memorial_profile_id = mp.id
          ) AS members_count
        FROM public.memorial_profiles AS mp
        LEFT JOIN public.memorial_members AS mm
          ON mm.memorial_profile_id = mp.id
          AND mm.user_id = @userId
        WHERE mp.deleted_at IS NULL
          AND (
            mp.created_by_user_id = @userId
            OR mm.user_id IS NOT NULL
          )
        ORDER BY mp.created_at DESC, mp.id DESC
      '''),
      parameters: {'userId': userId},
    );

    return result.map((row) {
      final data = row.toColumnMap();

      return {
        'id': data['id'],
        'created_by_user_id': data['created_by_user_id'],
        'full_name': data['full_name'],
        'photo_media_asset_id': data['photo_media_asset_id'],
        'birth_date': _formatDate(data['birth_date']),
        'death_date': _formatDate(data['death_date']),
        'memorial_text': data['memorial_text'],
        'grave_address': data['grave_address'],
        'created_at': data['created_at']?.toString(),
        'updated_at': data['updated_at']?.toString(),
        'is_creator': data['is_creator'],
        'relationship': _databaseText(data['relationship']),
        'members_count': data['members_count'],
      };
    }).toList();
  }

  /// Removes a user's follow relationship.
  ///
  /// The creator cannot unfollow their own memorial profile.
  Future<bool> unfollowProfile({
    required int profileId,
    required int userId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        DELETE FROM public.memorial_members AS mm
        USING public.memorial_profiles AS mp
        WHERE mm.memorial_profile_id = mp.id
          AND mm.memorial_profile_id = @profileId
          AND mm.user_id = @userId
          AND mp.created_by_user_id <> @userId
          AND mp.deleted_at IS NULL
        RETURNING mm.id
      '''),
      parameters: {
        'profileId': profileId,
        'userId': userId,
      },
    );

    return result.isNotEmpty;
  }

  String? _databaseText(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    if (value is UndecodedBytes) {
      return value.asString;
    }

    throw StateError(
      'Unsupported database text value: ${value.runtimeType}',
    );
  }

  /// Converts PostgreSQL DATE values to YYYY-MM-DD.
  ///
  /// PostgreSQL DATE values may be decoded as DateTime or text,
  /// depending on the query execution mode and driver codec.
  String? _formatDate(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return _dateOnly(value);
    }

    final text = _databaseText(value);

    if (text == null || text.isEmpty) {
      return null;
    }

    if (text.length >= 10) {
      return text.substring(0, 10);
    }

    throw FormatException('Invalid database date value: $text');
  }

  /// Returns only the calendar date without a time component.
  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  /// Maps a profile database row to the API response structure.
  Map<String, dynamic> _mapProfile(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'created_by_user_id': data['created_by_user_id'],
      'full_name': data['full_name'],
      'photo_media_asset_id': data['photo_media_asset_id'],
      'birth_date': _formatDate(data['birth_date']),
      'death_date': _formatDate(data['death_date']),
      'memorial_text': data['memorial_text'],
      'grave_address': data['grave_address'],
      'created_at': data['created_at']?.toString(),
    };
  }

  /// Maps a membership database row to the API response structure.
  Map<String, dynamic> _mapMembership(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'relationship': _databaseText(data['relationship']),
      'notifications_enabled': data['notifications_enabled'],
    };
  }
}

/// Represents a database validation error for memorial profiles.
class MemorialProfileRepositoryException implements Exception {
  /// Creates a repository exception.
  const MemorialProfileRepositoryException(this.message);

  /// User-facing error message.
  final String message;

  @override
  String toString() => message;
}
