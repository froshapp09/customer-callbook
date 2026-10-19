/// تبدیل ساده میلادی → شمسی
class Jalali {
  static String format(DateTime dt, {bool withTime = false}) {
    final j = _toJalali(dt.year, dt.month, dt.day);
    final date = '${j[0]}/${j[1].toString().padLeft(2, '0')}/${j[2].toString().padLeft(2, '0')}';
    if (!withTime) return date;
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date  $t';
  }

  static String timeAgoOrJalali(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'همین الان';
    if (d.inMinutes < 60) return '${d.inMinutes} دقیقه پیش';
    if (d.inHours < 24) return '${d.inHours} ساعت پیش';
    if (d.inDays < 7) return '${d.inDays} روز پیش';
    return format(dt, withTime: true);
  }

  static List<int> _toJalali(int gy, int gm, int gd) {
    final g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    var jy = (gy <= 1600) ? 0 : 979;
    gy -= (gy <= 1600) ? 621 : 1600;
    var gy2 = (gm > 2) ? (gy + 1) : gy;
    var days = (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) + ((gy2 + 399) ~/ 400) - 80 + gd + g_d_m[gm - 1];
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final jm = (days < 186) ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
    final jd = 1 + ((days < 186) ? (days % 31) : ((days - 186) % 30));
    return [jy, jm, jd];
  }
}
