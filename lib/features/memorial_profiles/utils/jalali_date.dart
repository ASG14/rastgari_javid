import 'package:shamsi_date/shamsi_date.dart';

class JalaliDate {
  JalaliDate._();

  static const List<String> monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static Jalali now() => Jalali.now();

  static int currentYear() => Jalali.now().year;

  static int daysInMonth(int year, int month) {
    try {
      return Jalali(year, month, 1).monthLength;
    } on DateException {
      return 0;
    }
  }

  static String format(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}/'
        '${month.toString().padLeft(2, '0')}/'
        '${day.toString().padLeft(2, '0')}';
  }

  static String normalizeDigits(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const english = '0123456789';

    return value.split('').map((character) {
      final persianIndex = persian.indexOf(character);

      if (persianIndex >= 0) {
        return english[persianIndex];
      }

      final arabicIndex = arabic.indexOf(character);

      if (arabicIndex >= 0) {
        return english[arabicIndex];
      }

      return character;
    }).join();
  }

  static bool isValid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    final normalized = normalizeDigits(value.trim());

    final match = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$').firstMatch(normalized);

    if (match == null) {
      return false;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    try {
      final date = Jalali(year, month, day);
      final today = Jalali.now();

      return date <= today;
    } on DateException {
      return false;
    }
  }

  static Jalali? parse(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final normalized = normalizeDigits(value.trim());

    final match = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$').firstMatch(normalized);

    if (match == null) {
      return null;
    }

    try {
      return Jalali(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on DateException {
      return null;
    }
  }

  /// تاریخ‌های قدیمی میلادی دیتابیس را به تاریخ شمسی تبدیل می‌کند.
  ///
  /// مقادیر جدید با قالب YYYY/MM/DD بدون تغییر برگردانده می‌شوند.
  static String? normalizeStoredDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final normalized = normalizeDigits(value.trim());

    if (isValid(normalized)) {
      return normalized;
    }

    final legacyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch(normalized);

    if (legacyMatch == null) {
      return null;
    }

    final year = int.parse(legacyMatch.group(1)!);
    final month = int.parse(legacyMatch.group(2)!);
    final day = int.parse(legacyMatch.group(3)!);

    final gregorianDate = DateTime.tryParse(
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );

    if (gregorianDate == null) {
      return null;
    }

    final jalali = Jalali.fromDateTime(gregorianDate);

    return format(jalali.year, jalali.month, jalali.day);
  }

  static String display(String? value) {
    final normalized = normalizeStoredDate(value);

    if (normalized == null) {
      return 'ثبت نشده';
    }

    final date = parse(normalized);

    if (date == null) {
      return 'ثبت نشده';
    }

    final monthName = monthNames[date.month - 1];

    return '${toPersianDigits(date.day.toString())} '
        '$monthName '
        '${toPersianDigits(date.year.toString())}';
  }

  static bool isAfter(String first, String second) {
    final firstDate = parse(first);
    final secondDate = parse(second);

    if (firstDate == null || secondDate == null) {
      return false;
    }

    return firstDate > secondDate;
  }

  static String toPersianDigits(String value) {
    const english = '0123456789';
    const persian = '۰۱۲۳۴۵۶۷۸۹';

    return value.split('').map((character) {
      final index = english.indexOf(character);

      return index == -1 ? character : persian[index];
    }).join();
  }
}
