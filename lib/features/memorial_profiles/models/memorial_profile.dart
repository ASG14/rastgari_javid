class MemorialProfile {
  const MemorialProfile({
    required this.id,
    required this.fullName,
    this.createdByUserId,
    this.photoMediaAssetId,
    this.birthDate,
    this.deathDate,
    this.memorialText,
    this.graveAddress,
    this.createdAt,
    this.updatedAt,
    this.creatorDisplayName,
    this.membersCount = 0,
    this.isCreator = false,
    this.relationship,
    this.membership,
  });

  final int id;
  final int? createdByUserId;
  final String fullName;
  final int? photoMediaAssetId;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final String? memorialText;
  final String? graveAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? creatorDisplayName;
  final int membersCount;
  final bool isCreator;
  final String? relationship;
  final MemorialMembership? membership;

  bool get hasPhoto => photoMediaAssetId != null;

  bool get isFollowing => membership != null;

  factory MemorialProfile.fromJson(Map<String, dynamic> json) {
    final membership = _readMembership(json['membership']);

    return MemorialProfile(
      id: _readInt(json['id']) ?? 0,
      createdByUserId: _readInt(json['created_by_user_id']),
      fullName: _readString(json['full_name']) ?? '',
      photoMediaAssetId: _readInt(json['photo_media_asset_id']),
      birthDate: _readDate(json['birth_date']),
      deathDate: _readDate(json['death_date']),
      memorialText: _readString(json['memorial_text']),
      graveAddress: _readString(json['grave_address']),
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
      creatorDisplayName: _readString(json['creator_display_name']),
      membersCount: _readInt(json['members_count']) ?? 0,
      isCreator: json['is_creator'] == true,
      relationship:
          _readString(json['relationship']) ?? membership?.relationship,
      membership: membership,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_by_user_id': createdByUserId,
      'full_name': fullName,
      'photo_media_asset_id': photoMediaAssetId,
      'birth_date': _formatDate(birthDate),
      'death_date': _formatDate(deathDate),
      'memorial_text': memorialText,
      'grave_address': graveAddress,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'creator_display_name': creatorDisplayName,
      'members_count': membersCount,
      'is_creator': isCreator,
      'relationship': relationship,
      'membership': membership?.toJson(),
    };
  }

  static MemorialMembership? _readMembership(dynamic value) {
    if (value is! Map) return null;

    return MemorialMembership.fromJson(Map<String, dynamic>.from(value));
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) return null;

    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

class MemorialMembership {
  const MemorialMembership({
    this.id,
    this.memorialProfileId,
    this.userId,
    this.relationship,
    this.notificationsEnabled,
  });

  final int? id;
  final int? memorialProfileId;
  final int? userId;
  final String? relationship;
  final bool? notificationsEnabled;

  factory MemorialMembership.fromJson(Map<String, dynamic> json) {
    return MemorialMembership(
      id: _readInt(json['id']),
      memorialProfileId: _readInt(json['memorial_profile_id']),
      userId: _readInt(json['user_id']),
      relationship: json['relationship']?.toString(),
      notificationsEnabled: json['notifications_enabled'] is bool
          ? json['notifications_enabled'] as bool
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memorial_profile_id': memorialProfileId,
      'user_id': userId,
      'relationship': relationship,
      'notifications_enabled': notificationsEnabled,
    };
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
