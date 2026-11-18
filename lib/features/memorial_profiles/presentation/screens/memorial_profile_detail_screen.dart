import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/memorial_profiles_repository.dart';
import '../../models/memorial_profile.dart';
import '../../utils/jalali_date.dart';

class MemorialProfileDetailScreen extends StatefulWidget {
  const MemorialProfileDetailScreen({
    super.key,
    required this.profileId,
    required this.currentUserId,
    required this.authRepository,
  });

  final int profileId;
  final int currentUserId;
  final AuthRepository authRepository;

  @override
  State<MemorialProfileDetailScreen> createState() =>
      _MemorialProfileDetailScreenState();
}

class _MemorialProfileDetailScreenState
    extends State<MemorialProfileDetailScreen> {
  final MemorialProfilesRepository _repository = MemorialProfilesRepository();

  MemorialProfile? _profile;

  bool _isLoading = true;
  bool _isUpdatingMembership = false;

  String? _error;

  bool get _isCreator => _profile?.createdByUserId == widget.currentUserId;

  bool get _isFollowing => _profile?.isFollowing == true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String> _readToken() async {
    final token = await widget.authRepository.readAccessToken();

    if (token == null || token.isEmpty) {
      throw const ApiException('نشست کاربری معتبر نیست. دوباره وارد شوید.');
    }

    return token;
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _readToken();

      final profile = await _repository.getProfile(
        profileId: widget.profileId,
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleMembershipAction() async {
    if (_isUpdatingMembership || _isCreator) return;

    if (_isFollowing) {
      await _unfollow();
    } else {
      await _follow();
    }
  }

  Future<void> _follow() async {
    final relationship = await _chooseRelationship();

    if (relationship == null || !mounted) return;

    setState(() => _isUpdatingMembership = true);

    try {
      final token = await _readToken();

      await _repository.followProfile(
        profileId: widget.profileId,
        relationship: relationship,
        token: token,
      );

      await _loadProfile();

      if (mounted) {
        _showMessage('این عزیز آسمانی به فهرست شما اضافه شد.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('دنبال‌کردن انجام نشد: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMembership = false);
      }
    }
  }

  Future<void> _unfollow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف از فهرست عزیزان من'),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید این پروفایل را از فهرست عزیزان خود حذف کنید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف از فهرست'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingMembership = true);

    try {
      final token = await _readToken();

      await _repository.unfollowProfile(
        profileId: widget.profileId,
        token: token,
      );

      await _loadProfile();

      if (mounted) {
        _showMessage('پروفایل از فهرست شما حذف شد.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('حذف از فهرست انجام نشد: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMembership = false);
      }
    }
  }

  Future<String?> _chooseRelationship() async {
    const relationships = <String, String>{
      'mother': 'مادرم',
      'father': 'پدرم',
      'sister': 'خواهرم',
      'brother': 'برادرم',
      'child': 'فرزندم',
      'spouse': 'همسرم',
      'friend': 'دوستم',
      'other': 'از نزدیکانم',
    };

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String selected = 'other';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('نسبت شما با این عزیز چیست؟'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: relationships.entries.map((entry) {
                  return RadioListTile<String>(
                    value: entry.key,
                    groupValue: selected,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selected = value;
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selected);
                  },
                  child: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _relationshipLabel(String? relationship) {
    return switch (relationship) {
      'mother' => 'مادر',
      'father' => 'پدر',
      'sister' => 'خواهر',
      'brother' => 'برادر',
      'child' => 'فرزند',
      'spouse' => 'همسر',
      'friend' => 'دوست',
      'other' => 'از نزدیکان',
      _ => 'مشخص نشده',
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _buildInformationRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MemorialProfile profile) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: 52,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            profile.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (profile.creatorDisplayName != null) ...[
            const SizedBox(height: 7),
            Text(
              'ایجادشده توسط ${profile.creatorDisplayName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 22),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInformationRow(
                    context,
                    icon: Icons.cake_outlined,
                    title: 'تاریخ تولد',
                    value: JalaliDate.display(profile.birthDate),
                  ),
                  Divider(color: colors.outlineVariant),
                  _buildInformationRow(
                    context,
                    icon: Icons.event_outlined,
                    title: 'تاریخ وفات',
                    value: JalaliDate.display(profile.deathDate),
                  ),
                  Divider(color: colors.outlineVariant),
                  _buildInformationRow(
                    context,
                    icon: Icons.people_outline_rounded,
                    title: 'همراهان',
                    value: '${profile.membersCount} نفر',
                  ),
                  if (profile.graveAddress != null) ...[
                    Divider(color: colors.outlineVariant),
                    _buildInformationRow(
                      context,
                      icon: Icons.location_on_outlined,
                      title: 'نشانی مزار',
                      value: profile.graveAddress!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (profile.memorialText != null &&
              profile.memorialText!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'یاد و خاطره',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                profile.memorialText!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 2),
              ),
            ),
          ],
          if (!_isCreator) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: _isFollowing
                  ? OutlinedButton.icon(
                      onPressed: _isUpdatingMembership
                          ? null
                          : _handleMembershipAction,
                      icon: _isUpdatingMembership
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.favorite_rounded),
                      label: const Text('حذف از عزیزان من'),
                    )
                  : FilledButton.icon(
                      onPressed: _isUpdatingMembership
                          ? null
                          : _handleMembershipAction,
                      icon: _isUpdatingMembership
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.favorite_border_rounded),
                      label: const Text('افزودن به عزیزان من'),
                    ),
            ),
            if (_isFollowing && profile.relationship != null) ...[
              const SizedBox(height: 8),
              Text(
                'نسبت شما: ${_relationshipLabel(profile.relationship)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('عزیز آسمانی')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 44),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                ),
              )
            : _profile == null
            ? const Center(child: Text('پروفایل پیدا نشد.'))
            : _buildContent(_profile!),
      ),
    );
  }
}
