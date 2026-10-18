# دفترچه مشتریان (customer_callbook)

نسخه: **1.5.1**

## ساخت APK با GitHub Actions

1. کل محتویات این پروژه را در ریپو آپلود کنید (حتماً پوشه `tooling` و `.github/workflows`)
2. بروید به: Actions → **Build APK** → Run workflow
3. در لاگ باید این خط باشد:
   `SUCCESS: phone/call/contacts permissions are inside the APK`
4. از Artifacts فایل APK را دانلود کنید
5. برنامه قبلی را از گوشی حذف کنید و APK جدید را نصب کنید
6. نسخه باید **1.5.1** باشد
7. تنظیمات → برنامه‌ها → مجوزها → مشاهده همه مجوزها
   باید تلفن، مخاطبین، پیامک و... دیده شود

## ساختار مهم

- `tooling/AndroidManifest.xml` → مجوزهای اندروید
- `tooling/MainActivity.kt` → خواندن تاریخچه تماس
- `.github/workflows/build-apk.yml` → بیلد (حتماً نسخه کامل با Install Manifest)

## اگر مجوز خالی بود

یعنی workflow قدیمی روی گیت‌هاب است. فایل
`.github/workflows/build-apk.yml`
را از این پروژه دوباره آپلود کنید.
