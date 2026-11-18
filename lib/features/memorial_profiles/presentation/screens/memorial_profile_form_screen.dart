import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/memorial_profiles_repository.dart';
import '../../models/memorial_profile.dart';

class MemorialProfileFormScreen extends StatefulWidget {
  const MemorialProfileFormScreen({
    super.key,
    required this.authRepository,
    this.profile,
  });

  final AuthRepository authRepository;
  final MemorialProfile? profile;

  @override
  State<MemorialProfileFormScreen> createState() =>
      _MemorialProfileFormScreenState();
}

class _MemorialProfileFormScreenState extends State<MemorialProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MemorialProfilesRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _memorialTextController;
  late final TextEditingController _graveAddressController;

  static const Map<String, String> _relationships = {
    'mother': 'مادر',
    'father': 'پدر',
    'sister': 'خواهر',
    'brother': 'برادر',
    'child': 'فرزند',
    'spouse': 'همسر',
    'friend': 'دوست',
    'other': 'سایر نسبت‌ها',
  };

  String? _relationship;
  DateTime? _birthDate;
  DateTime? _deathDate;

  bool _isSaving = false;

  bool get _isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();

    final profile = widget.profile;

    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _memorialTextController = TextEditingController(
      text: profile?.memorialText ?? '',
    );
    _graveAddressController = TextEditingController(
      text: profile?.graveAddress ?? '',
    );

    _relationship = profile?.relationship;
    _birthDate = profile?.birthDate;
    _deathDate = profile?.deathDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memorialTextController.dispose();
    _graveAddressController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _displayDate(DateTime? date) {
    if (date == null) return 'انتخاب تاریخ';

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  Future<void> _selectDate({required bool isBirthDate}) async {
    final currentDate = isBirthDate ? _birthDate : _deathDate;
    final initialDate = currentDate ?? DateTime(2000);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: isBirthDate ? 'انتخاب تاریخ تولد' : 'انتخاب تاریخ وفات',
      cancelText: 'انصراف',
      confirmText: 'تأیید',
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      if (isBirthDate) {
        _birthDate = selectedDate;
      } else {
        _deathDate = selectedDate;
      }
    });
  }

  void _clearDate({required bool isBirthDate}) {
    setState(() {
      if (isBirthDate) {
        _birthDate = null;
      } else {
        _deathDate = null;
      }
    });
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'نام و نام خانوادگی را وارد کنید.';
    }

    if (name.length > 150) {
      return 'نام نمی‌تواند بیشتر از ۱۵۰ کاراکتر باشد.';
    }

    return null;
  }

  String? _validateMemorialText(String? value) {
    if ((value?.length ?? 0) > 10000) {
      return 'دل‌نوشته نمی‌تواند بیشتر از ۱۰۰۰۰ کاراکتر باشد.';
    }

    return null;
  }

  String? _validateGraveAddress(String? value) {
    if ((value?.length ?? 0) > 500) {
      return 'نشانی مزار نمی‌تواند بیشتر از ۵۰۰ کاراکتر باشد.';
    }

    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_isEditing && _relationship == null) {
      _showMessage('نسبت خود با مرحوم را مشخص کنید.');
      return;
    }

    if (_birthDate != null &&
        _deathDate != null &&
        _deathDate!.isBefore(_birthDate!)) {
      _showMessage('تاریخ وفات نمی‌تواند قبل از تاریخ تولد باشد.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final token = await widget.authRepository.readAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception('نشست کاربری معتبر نیست. دوباره وارد شوید.');
      }

      final fullName = _nameController.text.trim();
      final memorialText = _memorialTextController.text.trim();
      final graveAddress = _graveAddressController.text.trim();

      if (_isEditing) {
        await _repository.updateProfile(
          profileId: widget.profile!.id,
          fullName: fullName,
          token: token,
          birthDate: _birthDate == null ? null : _formatDate(_birthDate!),
          deathDate: _deathDate == null ? null : _formatDate(_deathDate!),
          memorialText: memorialText,
          graveAddress: graveAddress,
        );
      } else {
        await _repository.createProfile(
          fullName: fullName,
          relationship: _relationship!,
          token: token,
          birthDate: _birthDate == null ? null : _formatDate(_birthDate!),
          deathDate: _deathDate == null ? null : _formatDate(_deathDate!),
          memorialText: memorialText,
          graveAddress: graveAddress,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      _showMessage('ذخیره اطلاعات انجام نشد: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    String? description,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 5),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField({
    required String title,
    required String description,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: _isSaving ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: colors.primary,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _displayDate(value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: value == null
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
                  ),
                ),
                if (value != null)
                  IconButton(
                    tooltip: 'پاک کردن تاریخ',
                    onPressed: _isSaving ? null : onClear,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'ویرایش پروفایل یادبود' : 'ثبت عزیز آسمانی'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: colors.primary,
                        size: 27,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'این صفحه برای ثبت یاد و خاطره عزیزانی است که از میان ما رفته‌اند. اطلاعات را با دقت و احترام وارد کنید.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _buildSectionTitle(
                  context,
                  'اطلاعات اصلی',
                  description: 'نام و مشخصات اولیه پروفایل یادبود',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  maxLength: 150,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'نام و نام خانوادگی',
                    hintText: 'نام عزیز آسمانی',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateName,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _relationship,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نسبت شما با مرحوم',
                      prefixIcon: Icon(Icons.people_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: _relationships.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() => _relationship = value);
                          },
                  ),
                ],
                const SizedBox(height: 26),
                _buildSectionTitle(
                  context,
                  'تاریخ‌های مهم',
                  description: 'وارد کردن تاریخ‌ها اختیاری است.',
                ),
                const SizedBox(height: 14),
                _buildDateField(
                  title: 'تاریخ تولد',
                  description:
                      'تاریخ‌ها در حال حاضر با تقویم میلادی انتخاب می‌شوند.',
                  value: _birthDate,
                  onTap: () => _selectDate(isBirthDate: true),
                  onClear: () => _clearDate(isBirthDate: true),
                ),
                const SizedBox(height: 18),
                _buildDateField(
                  title: 'تاریخ وفات',
                  description: 'در صورت تمایل می‌توانید این تاریخ را ثبت کنید.',
                  value: _deathDate,
                  onTap: () => _selectDate(isBirthDate: false),
                  onClear: () => _clearDate(isBirthDate: false),
                ),
                const SizedBox(height: 26),
                _buildSectionTitle(
                  context,
                  'یاد و خاطره',
                  description: 'اطلاعات تکمیلی برای آشنایی و گرامی‌داشت یاد او',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _memorialTextController,
                  enabled: !_isSaving,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 10000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'دل‌نوشته و متن یادبود',
                    hintText: 'از خاطرات، ویژگی‌ها و یادگارهای او بنویسید...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateMemorialText,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _graveAddressController,
                  enabled: !_isSaving,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'نشانی مزار',
                    hintText: 'نشانی آرامستان و محل دفن',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateGraveAddress,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'امکان افزودن تصویر پس از اتصال زیرساخت بارگذاری رسانه فراهم می‌شود.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isSaving
                          ? 'در حال ذخیره اطلاعات...'
                          : _isEditing
                          ? 'ذخیره تغییرات'
                          : 'ثبت پروفایل یادبود',
                    ),
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
