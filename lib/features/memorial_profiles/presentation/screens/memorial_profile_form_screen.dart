import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/memorial_profiles_repository.dart';
import '../../models/memorial_profile.dart';
import '../../utils/jalali_date.dart';

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
    'mother': 'مادرم',
    'father': 'پدرم',
    'sister': 'خواهرم',
    'brother': 'برادرم',
    'child': 'فرزندم',
    'spouse': 'همسرم',
    'friend': 'دوستم',
    'other': 'از نزدیکانم',
  };

  String? _relationship;
  String? _birthDate;
  String? _deathDate;

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

    _birthDate = JalaliDate.normalizeStoredDate(profile?.birthDate);

    _deathDate = JalaliDate.normalizeStoredDate(profile?.deathDate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memorialTextController.dispose();
    _graveAddressController.dispose();
    super.dispose();
  }

  Future<String?> _selectJalaliDate({
    required String title,
    String? initialValue,
  }) async {
    final now = Jalali.now();

    final initial = JalaliDate.parse(initialValue) ?? now;

    int selectedYear = initial.year;
    int selectedMonth = initial.month;
    int selectedDay = initial.day;

    final firstYear = 1200;
    final lastYear = now.year;

    if (selectedYear < firstYear || selectedYear > lastYear) {
      selectedYear = now.year;
      selectedMonth = now.month;
      selectedDay = now.day;
    }

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final monthLength = JalaliDate.daysInMonth(
              selectedYear,
              selectedMonth,
            );

            if (selectedDay > monthLength) {
              selectedDay = monthLength;
            }

            final isCurrentYear = selectedYear == now.year;
            final maximumMonth = isCurrentYear ? now.month : 12;

            if (selectedMonth > maximumMonth) {
              selectedMonth = maximumMonth;
            }

            final maximumDay =
                selectedYear == now.year && selectedMonth == now.month
                ? now.day
                : monthLength;

            if (selectedDay > maximumDay) {
              selectedDay = maximumDay;
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تاریخ موردنظر را بر اساس تقویم شمسی انتخاب کنید.',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedYear,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'سال',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (
                                  int year = lastYear;
                                  year >= firstYear;
                                  year--
                                )
                                  DropdownMenuItem(
                                    value: year,
                                    child: Text(
                                      JalaliDate.toPersianDigits(
                                        year.toString(),
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedYear = value;

                                  final newMonthLength = JalaliDate.daysInMonth(
                                    selectedYear,
                                    selectedMonth,
                                  );

                                  if (selectedDay > newMonthLength) {
                                    selectedDay = newMonthLength;
                                  }

                                  if (selectedYear == now.year &&
                                      selectedMonth > now.month) {
                                    selectedMonth = now.month;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedMonth,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'ماه',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (
                                  int month = 1;
                                  month <= maximumMonth;
                                  month++
                                )
                                  DropdownMenuItem(
                                    value: month,
                                    child: Text(
                                      JalaliDate.monthNames[month - 1],
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedMonth = value;

                                  final newLength = JalaliDate.daysInMonth(
                                    selectedYear,
                                    selectedMonth,
                                  );

                                  if (selectedDay > newLength) {
                                    selectedDay = newLength;
                                  }

                                  final newMaximumDay =
                                      selectedYear == now.year &&
                                          selectedMonth == now.month
                                      ? now.day
                                      : newLength;

                                  if (selectedDay > newMaximumDay) {
                                    selectedDay = newMaximumDay;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedDay,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'روز',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (int day = 1; day <= maximumDay; day++)
                                  DropdownMenuItem(
                                    value: day,
                                    child: Text(
                                      JalaliDate.toPersianDigits(
                                        day.toString(),
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedDay = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${JalaliDate.toPersianDigits(selectedDay.toString())} '
                          '${JalaliDate.monthNames[selectedMonth - 1]} '
                          '${JalaliDate.toPersianDigits(selectedYear.toString())}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('انصراف'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final result = JalaliDate.format(
                        selectedYear,
                        selectedMonth,
                        selectedDay,
                      );

                      Navigator.of(dialogContext).pop(result);
                    },
                    child: const Text('تأیید تاریخ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate({required bool isBirthDate}) async {
    final currentValue = isBirthDate ? _birthDate : _deathDate;

    final selected = await _selectJalaliDate(
      title: isBirthDate ? 'انتخاب تاریخ تولد' : 'انتخاب تاریخ وفات',
      initialValue: currentValue,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isBirthDate) {
        _birthDate = selected;
      } else {
        _deathDate = selected;
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

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isEditing && _relationship == null) {
      _showMessage('نسبت خود با مرحوم را مشخص کنید.');
      return;
    }

    if (_birthDate != null && !JalaliDate.isValid(_birthDate)) {
      _showMessage('تاریخ تولد معتبر نیست.');
      return;
    }

    if (_deathDate != null && !JalaliDate.isValid(_deathDate)) {
      _showMessage('تاریخ وفات معتبر نیست.');
      return;
    }

    if (_birthDate != null &&
        _deathDate != null &&
        JalaliDate.isAfter(_birthDate!, _deathDate!)) {
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
          birthDate: _birthDate,
          deathDate: _deathDate,
          memorialText: memorialText,
          graveAddress: graveAddress,
        );
      } else {
        await _repository.createProfile(
          fullName: fullName,
          relationship: _relationship!,
          token: token,
          birthDate: _birthDate,
          deathDate: _deathDate,
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
    required String? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final colors = Theme.of(context).colorScheme;

    final hasValue = value != null && value.isNotEmpty;

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
                    hasValue ? JalaliDate.display(value) : 'انتخاب تاریخ شمسی',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: hasValue
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasValue)
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
                  description: 'تاریخ‌ها را بر اساس تقویم شمسی وارد کنید. ثبت آن‌ها اختیاری است.',
                ),
                const SizedBox(height: 14),
                _buildDateField(
                  title: 'تاریخ تولد',
                  description: 'تاریخ تولد عزیز آسمانی',
                  value: _birthDate,
                  onTap: () => _selectDate(isBirthDate: true),
                  onClear: () => _clearDate(isBirthDate: true),
                ),
                const SizedBox(height: 18),
                _buildDateField(
                  title: 'تاریخ وفات',
                  description: 'تاریخ درگذشت عزیز آسمانی',
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
