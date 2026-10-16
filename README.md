# دفترچه مشتریان هوشمند (Customer Callbook)

اپلیکیشن مدیریت مشتریان و ثبت تماس‌ها با تم تیره مینیمال.

## روش ساخت APK با GitHub (ساده و قطعی)

### مرحله ۱: ساخت پروژه کامل روی کامپیوتر

```bash
# ۱. یک پوشه جدید بساز
mkdir customer_callbook
cd customer_callbook

# ۲. پروژه فلاتر بساز
flutter create .

# ۳. فایل‌های این پروژه را جایگزین کن:
#    - پوشه lib را کامل جایگزین کن
#    - فایل pubspec.yaml را جایگزین کن
#    - فایل analysis_options.yaml را جایگزین کن
#    - پوشه .github را کپی کن

# ۴. وابستگی‌ها را بگیر
flutter pub get
```

### مرحله ۲: آپلود روی GitHub

```bash
git init
git add .
git commit -m "نسخه اول دفترچه مشتریان"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/customer-callbook.git
git push -u origin main
```

YOUR_USERNAME را با نام کاربری گیت‌هاب خودت عوض کن.

### مرحله ۳: گرفتن APK

1. برو به صفحه ریپو در GitHub
2. تب **Actions** را باز کن
3. روی **Build APK** کلیک کن
4. دکمه **Run workflow** را بزن
5. بعد از سبز شدن، پایین صفحه بخش **Artifacts** را پیدا کن
6. فایل customer-callbook-apk را دانلود کن
7. داخلش app-release.apk است → روی گوشی نصب کن

---

## اگر Actions کار نکرد (روش جایگزین)

روی کامپیوتر خودت این دستور را بزن:

```bash
flutter build apk --release
```

فایل APK اینجا ساخته می‌شود:
build/app/outputs/flutter-apk/app-release.apk

---

## نکته خیلی مهم

برای اینکه GitHub Actions بتواند APK بسازد، حتماً باید اول دستور زیر را زده باشی تا پوشه‌های android و ios ساخته شوند:

```bash
flutter create .
```
