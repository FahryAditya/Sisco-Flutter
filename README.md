# SISCO — Skarlakes Sistem Absensi Organisasi

<div align="center">

**Versi:** 20.5.0  
**Platform:** Android • iOS • Web • Windows • macOS • Linux  

[![Flutter](https://img.shields.io/badge/Flutter-3.12-02569B)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2)](https://dart.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-database--7069a-FFCA28)](https://firebase.google.com/)
[![Provider](https://img.shields.io/badge/State-Provider-764ABC)](https://pub.dev/packages/provider)

</div>

---

## 📋 Deskripsi

**SISCO** adalah aplikasi **multi-platform** untuk manajemen ekstrakurikuler dan organisasi siswa yang dibangun dengan **Flutter** dan **Firebase**. Aplikasi ini mendukung pengelolaan absensi, keuangan (kas), wawancara, gamifikasi (XP/level/achievement), jadwal, materi, dokumentasi, chat, dan masih banyak lagi — dalam satu ekosistem terpadu.

---

## 🚀 Tech Stack

| Lapisan | Teknologi |
|---------|-----------|
| **Framework** | Flutter 3.12+ (Dart 3.12+) |
| **State Management** | Provider |
| **Backend & DB** | Firebase Auth, Cloud Firestore, Firebase Storage |
| **Offline-First** | SQLite (sqflite) + connectivity_plus |
| **UI & Animasi** | google_fonts, lottie, shimmer, flutter_animate |
| **Chart & Kalender** | fl_chart, table_calendar |
| **QR Code** | qr_flutter, mobile_scanner |
| **Export** | excel, pdf, printing, share_plus |
| **Notifikasi** | flutter_local_notifications |

---

## 🎯 Fitur Utama

### 🔐 Autentikasi & RBAC
- Login email/password via Firebase Auth
- 5 tingkatan peran: **Super Admin > Administrator > Admin Organisasi > Admin Ekstrakurikuler > Pembina**
- Hak akses granular diterapkan di Firestore Security Rules

### 🏢 Multi-Organisasi Dinamis
- Buat dan kelola banyak organisasi/ekstrakurikuler (OSIS, MPK, Programming Club, dll.)
- Data terisolasi per organisasi

### ✅ Sistem Absensi
- Input absensi harian: Hadir, Izin, Sakit, Tidak Hadir
- Rekap absensi per anggota dengan statistik dan grafik
- QR code scanning untuk check-in
- Auto-grant XP (+10 per kehadiran)

### 💰 Manajemen Keuangan (Kas)
- **Pemasukan**: Catat pembayaran kas per anggota
- **Pengeluaran**: Tracking pengeluaran organisasi dengan bukti upload
- Saldo berjalan, grafik tren, dan ekspor laporan

### 🎤 Sistem Wawancara
- Buat sesi wawancara untuk rekrutmen OSIS/MPK
- QR token untuk validasi peserta
- Antrian dengan validasi GPS
- Penilaian hasil dan approval workflow

### 🎮 Gamifikasi
- **XP System**: Dapat XP dari absensi, tugas, partisipasi, achievement
- **Level System**: 5 level (Beginner → Master)
- **Achievement**: Pencapaian kustom dengan reward XP
- **Leaderboard**: Peringkat anggota dengan podium

### 💬 Staff Chat
- Chat 1-on-1 real-time antar semua staf
- Notifikasi in-app
- Indikator presence / typing

### 📚 Konten & Jadwal
- **Materi Harian**: Post materi pembelajaran dan notulen
- **Jadwal**: Kalender kegiatan dengan flag wajib
- **Dokumentasi**: Galeri foto dengan upload ke Cloudinary

### 📊 Laporan & Ekspor
- Ekspor ke Excel (.xlsx) dan PDF
- Import anggota dari Excel/CSV
- Cetak laporan absensi, keuangan, anggota

### 📡 Offline-First
- Cache lokal SQLite untuk akses offline
- Outbox queue untuk sinkronisasi write saat online kembali
- Auto-sync saat koneksi tersedia

---

## 📁 Struktur Proyek

```
lib/
├── main.dart                    # Entry point aplikasi
├── app.dart                     # MaterialApp, routing, AuthGate
├── firebase_options.dart        # Konfigurasi Firebase
├── models/                      # Model data (User, Member, Attendance, dll.)
├── providers/                   # State management (Provider)
├── services/                    # Business logic (Firestore, Sync, Auth, dll.)
├── screens/                     # Halaman UI
│   ├── splash/                  # Splash screen
│   ├── login/                   # Halaman login
│   ├── home/                    # Halaman utama
│   ├── dashboard/               # Dashboard dengan grafik
│   ├── absensi/                 # Absensi harian
│   ├── rekap_absensi/           # Rekap absensi per anggota
│   ├── kas/                     # Manajemen kas (pemasukan)
│   ├── pengeluaran/             # Pengeluaran kas
│   ├── organisasi/              # Manajemen organisasi
│   ├── wawancara/               # Sistem wawancara
│   ├── registration/            # Pendaftaran anggota baru
│   ├── chat/                    # Staff chat
│   ├── materi/                  # Materi / notulen
│   ├── jadwal/                  # Jadwal kegiatan
│   ├── dokumentasi/             # Dokumentasi foto
│   ├── leaderboard/             # Papan peringkat
│   ├── pencapaian/              # Achievement system
│   ├── quest/                   # QR Quest
│   ├── laporan/                 # Laporan
│   ├── export/                  # Ekspor Excel/PDF
│   ├── import/                  # Import Excel
│   ├── backup/                  # Backup data
│   ├── log_aktivitas/           # Log aktivitas
│   └── profile/                 # Profil pengguna
├── widgets/                     # Komponen UI reusable
├── theme/                       # Tema aplikasi
└── utils/                       # Fungsi bantuan
```

---

## 🚀 Cara Menjalankan

### Prasyarat
- Flutter SDK (stable, `^3.12.2`)
- Firebase project (`database-7069a`) dengan Firestore, Auth, dan Storage
- Perangkat/emulator (Android/iOS/Web/Windows/macOS/Linux)

### Instalasi
```bash
# Clone repositori
cd sisko

# Install dependencies
flutter pub get

# Edit file .env dengan kredensial Cloudinary (jika perlu)
# CLOUDINARY_CLOUD_NAME=pebviapm
# CLOUDINARY_UPLOAD_PRESET=sisko_unsigned

# Jalankan aplikasi
flutter run
flutter run -d chrome       # Web
flutter run -d windows      # Windows
```

### Build Produksi
```bash
flutter build apk            # Android
flutter build ios            # iOS
flutter build web            # Web
flutter build windows        # Windows
flutter build macos          # macOS
```

---

## 🌐 Airlangga QR Quest

Terdapat **aplikasi web terpisah** di direktori `web_quest/` — sebuah halaman vanilla HTML/CSS/JS yang dideploy ke **Vercel** untuk sesi QR Quest. Siswa memindai QR code untuk mendapatkan soal essay dari Firestore.

```bash
cd web_quest
vercel --prod
```

---

## 🔐 Firestore Security

Firestore Security Rules menerapkan RBAC ketat berbasis peran pengguna, memastikan:

- Hanya admin yang bisa membaca/menulis data organisasi
- Data terisolasi antar organisasi
- Siswa (peserta) tidak bisa login ke aplikasi

---

## 👥 Pengembang

Dikembangkan oleh **Mimin Adresteia** — SKARLAKES Ecosystem.

Instagram { @sisco_skarla

Mimin Adresteia : @miminadresteia

}

