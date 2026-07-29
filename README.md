# Reusable Flutter WebView

Template aplikasi Flutter WebView untuk Android, iOS, dan macOS. Konfigurasi
default membuka TukuGaming Indonesia, tetapi URL, nama aplikasi, package ID,
ikon, dan signing dapat diganti tanpa mengubah implementasi WebView.

## Fitur

- WebView native dengan JavaScript dan DOM storage.
- Safe area untuk status bar dan navigation bar perangkat.
- Loading awal, error state, dan tombol retry.
- Tombol kembali mengikuti history WebView.
- Link `http`/`https` tetap di WebView.
- Link aplikasi seperti telepon, email, dan WhatsApp dibuka oleh sistem.
- Texture Layer Hybrid Composition dan direct gesture handling pada Android.
- Performance mode opsional untuk mengurangi autoplay dan animasi halaman.
- Konfigurasi development/production menggunakan `--dart-define-from-file`.
- Android release signing melalui `key.properties` atau environment variable.
- Generator launcher icon untuk Android adaptive icon, iOS, Web, Windows, dan
  macOS.

## Persyaratan

- Flutter stable sesuai constraint di `pubspec.yaml`.
- Android SDK dan JDK 17 untuk build Android.
- Xcode dan CocoaPods untuk build iOS/macOS.
- `keytool`, yang tersedia bersama JDK, untuk membuat upload keystore.

Periksa environment:

```bash
flutter doctor -v
flutter pub get
```

## Struktur konfigurasi

| Lokasi | Fungsi |
| --- | --- |
| `lib/app_config.dart` | Default dan nama variabel compile-time Dart |
| `config/development.json` | Nilai untuk development |
| `config/production.json` | Nilai untuk production |
| `android/gradle.properties` | Application ID dan nama launcher Android |
| `android/key.properties.example` | Template signing lokal |
| `flutter_launcher_icons.yaml` | Konfigurasi generator ikon |
| `assets/branding/` | Source icon 1024×1024 |

## Konfigurasi aplikasi

Variabel yang tersedia:

| Variabel | Default | Keterangan |
| --- | --- | --- |
| `APP_NAME` | `TukuGaming` | Judul aplikasi di layer Flutter |
| `WEBSITE_URL` | `https://www.tukugaming.com/id` | URL awal WebView; wajib `http` atau `https` |
| `ENABLE_PERFORMANCE_MODE` | `true` | Mengurangi animasi dan autoplay pada domain website utama |

Nilai tersebut dapat diubah di `config/development.json` dan
`config/production.json`. File ini tidak boleh berisi password, API key, atau
rahasia signing.

Override satu per satu juga didukung:

```bash
flutter run \
  --dart-define=APP_NAME="Nama Aplikasi" \
  --dart-define=WEBSITE_URL="https://example.com" \
  --dart-define=ENABLE_PERFORMANCE_MODE=true
```

`APP_NAME` hanya mengubah judul pada layer Flutter. Nama yang terlihat di
launcher tetap mengikuti konfigurasi native pada bagian rebranding.

## Development

Jalankan dengan konfigurasi development:

```bash
flutter pub get
flutter run --dart-define-from-file=config/development.json
```

Quality checks:

```bash
dart format lib test tool
flutter analyze
flutter test
```

Build debug hanya untuk debugging. Performa debug tidak mewakili aplikasi
produksi, terutama pada perangkat lama.

```bash
flutter build apk \
  --debug \
  --dart-define-from-file=config/development.json
```

Untuk profiling pada perangkat fisik:

```bash
flutter run \
  --profile \
  --dart-define-from-file=config/production.json
```

## Production

Sebelum membuat release:

1. Pastikan `WEBSITE_URL` production benar dan menggunakan HTTPS.
2. Tentukan Application ID final sebelum upload pertama.
3. Ganti nama launcher dan ikon jika melakukan rebranding.
4. Naikkan `version` di `pubspec.yaml`, misalnya `1.1.0+2`.
5. Buat upload keystore dan simpan backup dengan aman.
6. Jalankan analyze dan test.
7. Build Android App Bundle yang sudah ditandatangani.

### Membuat upload keystore

Buat direktori dan upload key:

```bash
mkdir -p android/keystore
keytool -genkeypair -v \
  -keystore android/keystore/upload-keystore.p12 \
  -storetype PKCS12 \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Salin template konfigurasi:

```bash
cp android/key.properties.example android/key.properties
```

Isi `android/key.properties`:

```properties
storeFile=keystore/upload-keystore.p12
storePassword=PASSWORD_KEYSTORE
keyAlias=upload
keyPassword=PASSWORD_KEY
```

Path `storeFile` relatif terhadap direktori `android/`. File
`android/key.properties`, direktori `android/keystore/`, `.jks`, dan
`.keystore`, dan `.p12` sudah masuk `.gitignore`.

Jangan commit keystore atau password. Simpan backup terenkripsi. Untuk aplikasi
baru di Google Play, gunakan upload key lokal bersama
[Play App Signing](https://developer.android.com/studio/publish/app-signing).

### Signing melalui environment variable

CI/CD dapat menggunakan variabel berikut tanpa membuat `key.properties`:

```bash
export ANDROID_KEYSTORE_PATH="/secure/path/upload-keystore.p12"
export ANDROID_KEYSTORE_PASSWORD="..."
export ANDROID_KEY_ALIAS="upload"
export ANDROID_KEY_PASSWORD="..."
```

Release build sengaja gagal bila signing belum lengkap atau file keystore tidak
ditemukan. Tidak ada fallback ke debug key.

### Build untuk Play Store

Artifact utama Play Store adalah Android App Bundle:

```bash
flutter build appbundle \
  --release \
  --dart-define-from-file=config/production.json
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

APK release untuk QA langsung:

```bash
flutter build apk \
  --release \
  --dart-define-from-file=config/production.json

flutter build apk \
  --release \
  --split-per-abi \
  --dart-define-from-file=config/production.json
```

Jangan mengupload APK debug ke Play Console.

## Mengubah package name / Application ID

### Android

Ubah satu nilai berikut sebelum publikasi pertama:

```properties
# android/gradle.properties
WEBVIEW_APPLICATION_ID=com.perusahaan.namaaplikasi
```

Format harus reverse-domain, huruf kecil, dan unik di Play Store. Application ID
dapat dioverride pada CI:

```bash
export ANDROID_APPLICATION_ID=com.perusahaan.namaaplikasi
```

Namespace source Android sengaja dibuat generik sebagai
`com.webview.wrapper`, sehingga perubahan Application ID tidak membutuhkan
pemindahan `MainActivity.kt`.

Application ID adalah identitas permanen aplikasi di Google Play. Setelah
aplikasi dipublikasikan, jangan mengubahnya karena Google Play akan
menganggapnya sebagai aplikasi baru.

### iOS

Ubah `PRODUCT_BUNDLE_IDENTIFIER` pada target Runner di Xcode atau ganti seluruh
nilai `com.tukugaming.app` pada:

```text
ios/Runner.xcodeproj/project.pbxproj
```

Gunakan Bundle ID yang sudah terdaftar pada Apple Developer.

### macOS

Ubah nilai berikut:

```text
macos/Runner/Configs/AppInfo.xcconfig
```

Jika test target digunakan, sesuaikan juga Bundle ID `RunnerTests` pada project
Xcode.

## Mengubah nama aplikasi

Sesuaikan seluruh lokasi berikut agar nama konsisten:

| Platform | Lokasi |
| --- | --- |
| Flutter | `APP_NAME` pada file `config/*.json` |
| Android | `WEBVIEW_APP_NAME` pada `android/gradle.properties` |
| iOS | `CFBundleDisplayName` dan `CFBundleName` pada `ios/Runner/Info.plist` |
| macOS | `PRODUCT_NAME` pada `macos/Runner/Configs/AppInfo.xcconfig` |
| Web | `web/index.html` dan `web/manifest.json` |

Android CI juga dapat memakai:

```bash
export ANDROID_APP_NAME="Nama Aplikasi"
```

## Mengubah launcher icon

Source ikon:

```text
assets/branding/app_icon_foreground.png
```

Gunakan PNG transparan 1024×1024. Pastikan logo berada dalam safe area agar
tidak terpotong oleh bentuk adaptive icon Android.

Regenerasi ikon:

```bash
dart run tool/prepare_app_icon.dart
dart run flutter_launcher_icons -f flutter_launcher_icons.yaml
```

Script pertama membuat ikon RGB berlatar gelap untuk platform yang tidak
mengizinkan alpha. Generator kedua memperbarui seluruh ukuran platform. Jangan
mengedit file hasil di `mipmap-*` atau `AppIcon.appiconset` secara manual.

Warna background dan inset adaptive icon dapat diubah di
`flutter_launcher_icons.yaml`.

## Checklist upload Play Store

- Application ID final dan belum pernah dipakai aplikasi lain.
- `version` dan build number sudah dinaikkan.
- AAB release ditandatangani menggunakan upload key.
- Play App Signing diaktifkan.
- Ikon, nama aplikasi, deskripsi, screenshot, dan feature graphic tersedia.
- Privacy policy dapat diakses publik.
- Form Data safety sesuai data yang diproses website/WebView.
- Content rating, target audience, dan kategori aplikasi sudah diisi.
- Login, pembayaran, external link, back navigation, serta offline state diuji
  pada perangkat fisik.
- `flutter analyze` dan `flutter test` lulus.

## Troubleshooting

### Konfigurasi signing release belum lengkap

Pastikan `android/key.properties` memiliki empat nilai yang diperlukan atau
semua environment variable signing tersedia.

### File keystore tidak ditemukan

Periksa `storeFile`. Path relatif dimulai dari direktori `android/`, bukan root
proyek.

### Aplikasi terasa lambat

Uji APK release atau profile, bukan debug. Pastikan Android System WebView
perangkat sudah diperbarui. Jika performance mode mengganggu komponen website,
set `ENABLE_PERFORMANCE_MODE` menjadi `false`.

### Website tidak terbuka

Pastikan `WEBSITE_URL` valid, menggunakan `http`/`https`, dan perangkat memiliki
koneksi internet. Website HTTPS tidak memerlukan pengecualian cleartext Android.
