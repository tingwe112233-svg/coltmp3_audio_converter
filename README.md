# ColtMP3 Audio Converter

Aplikasi Android Native (Flutter + FFmpeg `libmp3lame`) untuk memutar dan mengonversi file audio lokal menjadi format **MP3 CBR 44100 Hz Stereo** agar 100% terbaca tanpa error di head unit / tape mobil lama (seperti tape bawaan truk box Colt Diesel).

## Spesifikasi Output Audio
- **Encoder**: `libmp3lame` (FFmpeg Native)
- **Bitrate Mode**: Strict Constant Bitrate (CBR 192 kbps default, pilihan 128–320 kbps)
- **Sample Rate**: `44100 Hz`
- **Channels**: `2 (Stereo)`
- **Header**: Tanpa Xing/VBR header, ID3v2.3 murni, tanpa embedded gambar sampul berukuran besar yang membuat tape mobil macet, dan sanitasi nama file ASCII.

## Cara Build APK Langsung dari HP Lewat GitHub Actions
1. Buat akun atau login ke **github.com** melalui browser Chrome di HP Android Anda.
2. Buat repository baru (klik tanda **+** -> **New repository**), beri nama `coltmp3_audio_converter`, pilih **Public** (agar kuota GitHub Actions gratis tanpa batas), lalu klik **Create repository**.
3. Unggah seluruh file di paket ini (termasuk folder tersembunyi `.github/workflows/build.yml`), atau ekstrak ZIP terlebih dahulu.
4. Buka tab **Actions** di repository GitHub Anda. Workflow **Build Android Release APK** akan langsung berjalan otomatis.
5. Tunggu sekitar 4–6 menit hingga ikon berubah menjadi centang hijau.
6. Klik hasil workflow tersebut, gulir ke bagian **Artifacts** (atau buka menu **Releases** di halaman utama repo), lalu unduh file **`coltmp3_audio_converter-release-apk`** ke HP Anda.
7. 
