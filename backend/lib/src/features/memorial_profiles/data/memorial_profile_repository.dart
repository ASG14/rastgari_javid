import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for memorial profiles and memberships.
class MemorialProfileRepository {
  /// Creates a memorial profile and its owner membership atomically.
  ///
  /// If either insert fails, the transaction is rolled back.
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
      // If a photo is supplied, make sure it belongs to this user
      // and is a successfully processed image.
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

      // The creator becomes the first active owner.
      // Their actual relationship is supplied by the user.
      await session.execute(
        Sql.named('''
          INSERT INTO public.memorial_members (
            memorial_profile_id,
            user_id,
            relationship,
            role,
            status
          )
          VALUES (
            @profileId,
            @userId,
            CAST(@relationship AS public.memorial_relationship),
            'owner',
            'active'
          )
        '''),
        parameters: {
          'profileId': profileId,
          'userId': userId,
          'relationship': relationship,
        },
      );

      final mappedProfile = _mapProfile(profile);
      mappedProfile['membership']['relationship'] = relationship;
      return mappedProfile;
    });
  }

  /// Searches active memorial profiles by name.
  ///
  /// Duplicate names are allowed and are returned as separate profiles.
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
              AND mm.status = 'active'
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
        'birth_date': data['birth_date']?.toString(),
        'death_date': data['death_date']?.toString(),
        'memorial_text': data['memorial_text'],
        'grave_address': data['grave_address'],
        'created_at': data['created_at']?.toString(),
        'creator_display_name': data['creator_display_name'],
        'members_count': data['members_count'],
      };
    }).toList();
  }

  Map<String, dynamic> _mapProfile(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'created_by_user_id': data['created_by_user_id'],
      'full_name': data['full_name'],
      'photo_media_asset_id': data['photo_media_asset_id'],
      'birth_date': data['birth_date']?.toString(),
      'death_date': data['death_date']?.toString(),
      'memorial_text': data['memorial_text'],
      'grave_address': data['grave_address'],
      'created_at': data['created_at']?.toString(),
      'membership': {
        'relationship': null,
        'role': 'owner',
        'status': 'active',
      },
    };
  }

  /// Follows an existing memorial profile or reactivates a previous membership.
  ///
  /// Existing roles are preserved. Following a profile never grants
  /// editing permissions.
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
            relationship,
            role,
            status
          )
          VALUES (
            @profileId,
            @userId,
            CAST(@relationship AS public.memorial_relationship),
            'follower',
            'active'
          )
          ON CONFLICT (memorial_profile_id, user_id)
          DO UPDATE SET
            relationship = EXCLUDED.relationship,
            status = 'active',
            notifications_enabled = CASE
              WHEN public.memorial_members.status = 'revoked'
                THEN TRUE
              ELSE public.memorial_members.notifications_enabled
            END,
            updated_at = CURRENT_TIMESTAMP
          RETURNING
            id,
            memorial_profile_id,
            user_id,
            relationship,
            role,
            status,
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
        'relationship': membership['relationship'].toString(),
        'role': membership['role'].toString(),
        'status': membership['status'].toString(),
        'notifications_enabled': membership['notifications_enabled'],
        'created_at': membership['created_at']?.toString(),
        'updated_at': membership['updated_at']?.toString(),
      };
    });
  }

  /// Retrieves a memorial profile and the current user's membership.
  ///
  /// A revoked membership is also returned so the user can follow again.
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
              AND members.status = 'active'
          ) AS members_count,

          membership.id AS membership_id,
          membership.relationship AS membership_relationship,
          membership.role AS membership_role,
          membership.status AS membership_status,
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
        'relationship': data['membership_relationship']?.toString(),
        'role': data['membership_role']?.toString(),
        'status': data['membership_status']?.toString(),
        'notifications_enabled': data['notifications_enabled'],
      };
    }

    return {
      'id': data['id'],
      'created_by_user_id': data['created_by_user_id'],
      'full_name': data['full_name'],
      'photo_media_asset_id': data['photo_media_asset_id'],
      'birth_date': data['birth_date']?.toString(),
      'death_date': data['death_date']?.toString(),
      'memorial_text': data['memorial_text'],
      'grave_address': data['grave_address'],
      'created_at': data['created_at']?.toString(),
      'updated_at': data['updated_at']?.toString(),
      'creator_display_name': data['creator_display_name'],
      'members_count': data['members_count'],
      'membership': membership,
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
