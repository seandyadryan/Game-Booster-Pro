# Game Booster Pro

Game Booster Pro adalah aplikasi Flutter untuk membantu menyiapkan sesi bermain game di Android.

## Fitur

- Membersihkan cache aplikasi.
- Meringankan proses background.
- Menampilkan penggunaan RAM.
- Mengaktifkan mode Do Not Disturb jika izin sistem diberikan.
- Menampilkan FPS aplikasi atau refresh rate layar jika FPS belum tersedia.
- Animasi boost orang terbang dengan jubah saat tombol boost ditekan.

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
