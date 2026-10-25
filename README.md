# Stok Meta untuk Windows

Versi desktop dari aplikasi Stok Meta. Logika inti (`lib/processor.dart`) berasal dari repo asli;
bedanya: frame video diambil dengan ffmpeg (video_thumbnail tidak ada di Windows), key diganti
tiap N file, key yang kena limit dibatalkan, dan hasil AI yang tidak layak ditolak.

## Cara membangun (tanpa install apa pun di PC)
1. Taruh folder `stokmeta_windows` ini di dalam repo GitHub-mu (di root repo).
2. Salin `.github/workflows/build-windows.yml` ke `.github/workflows/` di root repo.
3. Buka tab **Actions → Build Windows → Run workflow**.
4. Setelah selesai, unduh `StokMeta-Windows.zip` dari **Releases**, ekstrak, jalankan `stokmeta_windows.exe`.

ffmpeg.exe otomatis ikut di dalam ZIP (diunduh saat build dari gyan.dev).

## Cara membangun di PC sendiri
```
cd stokmeta_windows
flutter create --platforms=windows .
flutter pub get
flutter build windows --release
```
Lalu salin `ffmpeg.exe` ke `build\windows\x64\runner\Release\`.
