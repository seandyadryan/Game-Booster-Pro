# Game Booster Pro

Game Booster Pro adalah aplikasi Flutter untuk membantu menyiapkan sesi bermain game di Android.

## Fitur

- Membersihkan cache milik Game Booster Pro.
- Membuka pengelolaan aplikasi Android untuk mengatur background secara manual.
- DND ketat dengan izin sistem, pembacaan status aktual, dan pemulihan pengaturan sebelum sesi Boost.
- Refresh rate layar dalam Hz, persentase baterai, dan suhu baterai.
- GFX Tools membuka pengaturan layar Android dan daftar game terpasang.
- Pembuka game yang ditandai sebagai game oleh metadata Android.
- Animasi peluncuran roket saat Boost.

## Batas Fitur dan Pengujian Perangkat

DND membisukan suara; panggilan WhatsApp masih dapat diterima atau tampil.
Mode ketat juga membisukan alarm dan media. Perilaku tampilan panggilan bergantung pada Android/OEM dan WhatsApp.
Android 15+ mengelola permintaan DND aplikasi sebagai aturan tersendiri; aturan lain dapat tetap mengaktifkan DND setelah sesi selesai.

Android tidak menyediakan akses aplikasi biasa untuk menghapus semua Recent Apps,
menutup semua proses aplikasi lain, atau mengubah resolusi, anti-aliasing, dan FPS game lain.
Kontrol profil GFX lama yang hanya mengubah variabel UI sudah dihapus.
Pengaturan grafis dilakukan di dalam game; opsi refresh rate sistem bergantung pada perangkat.

Uji di ponsel: berikan/tolak/cabut izin DND, aktifkan mode ketat, lakukan panggilan WhatsApp,
periksa suara dan tampilan panggilan secara terpisah, lalu akhiri Boost dan periksa pemulihan DND.
Ulangi saat DND sudah aktif sebelum Boost dan ketika aplikasi kembali dari pengaturan.
Uji pembuka game, pengaturan layar, dan pengelolaan aplikasi pada perangkat target.

## Flutter

Proyek ini memakai FVM dengan Flutter `3.41.2`.

```powershell
fvm install 3.41.2
fvm flutter pub get
fvm flutter run
```

## Git Hook

Folder `.githooks` berisi hook `pre-commit` yang otomatis menaikkan build number di `pubspec.yaml`, misalnya dari `1.0.0+1` menjadi `1.0.0+2`.

Aktifkan hook dengan:

```powershell
git config core.hooksPath .githooks
```

## Release Signing

Keystore lokal dibuat di:

```text
D:\KEYSTORE\game_booster.jks
```

Konfigurasi password lokal berada di:

```text
D:\KEYSTORE\game_booster_key.properties
```

File rahasia tersebut tidak disimpan ke repository.
