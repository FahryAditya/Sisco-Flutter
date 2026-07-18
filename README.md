# 🎯 Artemis Series — Sistem Ekstrakurikuler & Organisasi

<div align="center">

**Versi:** 2.0.0  
**Sekolah:** SMK Airlangga Balikpapan (Yayasan Airlangga Balikpapan)  
**Deploy:** [artemis.smkairlangga.sch.id](https://artemis.smkairlangga.sch.id)

[![Next.js](https://img.shields.io/badge/Next.js-14.2.5-black)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0-blue)](https://www.typescriptlang.org/)
[![Prisma](https://img.shields.io/badge/Prisma-5.16-2D3748)](https://www.prisma.io/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791)](https://www.postgresql.org/)

</div>

---

## 📋 Deskripsi

**Artemis** adalah sistem informasi manajemen ekstrakurikuler dan organisasi siswa yang bersifat **multi-organisasi dinamis**. Sistem ini dirancang untuk mengelola berbagai kegiatan ekstrakurikuler seperti **Programming Club**, **English Club**, **OSIS**, dan **MPK** dalam satu platform terpadu.

### ✨ Keunggulan Utama

- 🏢 **Multi-Organisasi Dinamis** — Administrator dapat membuat ekstrakurikuler atau organisasi baru kapan saja tanpa perubahan kode
- 🎮 **Gamifikasi Lengkap** — Sistem XP, level, achievement untuk meningkatkan engagement anggota
- 🔐 **Keamanan Tinggi** — RBAC (Role-Based Access Control), JWT authentication, isolasi data per organisasi
- 📊 **Analytics & Reporting** — Dashboard real-time dengan chart dan statistik lengkap
- 🎨 **UI/UX Modern** — Interface responsif dengan animasi smooth menggunakan Framer Motion
- ⚡ **Real-time Updates** — Pusher untuk notifikasi dan chat langsung
- 📱 **QR Code System** — Validasi kehadiran dan pendaftaran dengan QR code

---

## 🚀 Tech Stack

| Lapisan | Teknologi | Keterangan |
|---------|-----------|------------|
| **Framework** | Next.js 14.2.5 | App Router, Server Components, Standalone output |
| **Bahasa** | TypeScript 5 | Strict mode untuk type safety maksimal |
| **Styling** | Tailwind CSS 3 + shadcn/ui | Utility-first CSS dengan komponen reusable |
| **Database** | PostgreSQL | Via Supabase / Neon dengan Prisma ORM 5 |
| **Authentication** | JWT (jose) | HttpOnly cookies dengan auto-refresh |
| **Realtime** | Pusher | WebSocket untuk chat dan notifikasi live |
| **File Storage** | Cloudinary | Upload dan hosting gambar/dokumen |
| **Email** | Nodemailer + Gmail API | SMTP Gmail untuk kirim email otomatis |
| **Chart** | Recharts | Visualisasi data interaktif |
| **PDF Export** | jsPDF + jspdf-autotable | Generate laporan PDF |
| **Excel** | SheetJS (xlsx) | Import/export data Excel/CSV |
| **Validasi** | Zod | Type-safe schema validation |
| **State Management** | TanStack React Query | Server state dan caching |
| **Animasi** | Framer Motion + GSAP | Animasi smooth dan profesional |
| **Icons** | Lucide React | Icon set modern dan konsisten |
| **Container** | Docker | Multi-stage build dengan Node 20 Alpine |

---

## 📁 Struktur Direktori

```
Sistem Ekstrakurikuler/
│
├── app/                          # Next.js App Router
│   ├── absensi/                  # Modul Absensi Harian
│   ├── admin/                    # Panel Admin (Manajemen User, Email, XP)
│   ├── ambil-siswa/              # Ambil Data Siswa dari Database
│   ├── api/                      # API Routes (~31 grup endpoint)
│   │   ├── auth/                 # Authentication endpoints
│   │   ├── members/              # CRUD anggota
│   │   ├── attendance/           # Absensi endpoints
│   │   ├── cash/                 # Keuangan endpoints
│   │   ├── wawancara/            # Wawancara endpoints
│   │   └── ...                   # Dan banyak lagi
│   ├── dashboard/                # Dashboard Utama dengan Statistik
│   ├── dokumentasi/              # Dokumentasi Foto Kegiatan
│   ├── export/                   # Export Data ke Excel/PDF
│   ├── hapus-peserta/            # Hapus Peserta Wawancara
│   ├── import/                   # Import Massal dari Excel/CSV
│   ├── jadwal/                   # Jadwal Kegiatan
│   ├── kas/                      # Buku Kas (Pemasukan)
│   ├── laporan/                  # Laporan & Statistik
│   ├── leaderboard/              # Papan Peringkat Gamifikasi
│   ├── log/                      # Log Aktivitas Admin
│   ├── login/                    # Halaman Login
│   ├── materi/                   # Materi Harian / Notulen
│   ├── organisasi/               # Manajemen Organisasi
│   ├── pencapaian/               # Achievement System
│   ├── pengeluaran/              # Pengeluaran Kas
│   ├── qr-code/                  # Generate QR Code
│   ├── registration/             # Pendaftaran Anggota Baru
│   ├── rekap-absensi/            # Rekap Absensi per Siswa
│   ├── siswa/                    # CRUD Anggota/Siswa
│   ├── update-sistem/            # Pengumuman Update Sistem
│   └── wawancara/                # Sistem Antrian Wawancara OSIS & MPK
│
├── components/                   # Komponen React Reusable
│   ├── admin/                    # Komponen khusus admin
│   ├── charts/                   # Komponen chart (Line, Bar, Pie)
│   ├── documentation/            # Tampilan dokumentasi
│   ├── layout/                   # Sidebar, Topbar, DashboardLayout
│   ├── providers/                # Context providers (React Query)
│   └── ui/                       # UI primitives (Button, Modal, Table, dll)
│
├── lib/                          # Utilities & Services
│   ├── services/                 # Business logic services
│   │   ├── email-template.ts    # Template email dinamis
│   │   ├── excel.ts             # Export/import Excel
│   │   ├── gmail.ts             # Gmail API integration
│   │   └── organization.ts      # Organization helpers
│   ├── auth.ts                   # JWT sign/verify/refresh
│   ├── auth-shared.ts            # Role definitions & helpers
│   ├── prisma.ts                 # Prisma client singleton
│   ├── cloudinary.ts             # Upload ke Cloudinary
│   ├── email.ts                  # Email sender
│   ├── exp.ts                    # Logika XP & level
│   ├── gamification.ts           # Gamification utilities
│   ├── hooks.ts                  # Custom React hooks
│   ├── log.ts                    # Activity logging
│   ├── org-context.ts            # Isolasi data per organisasi
│   ├── pusher-client.ts          # Pusher client (realtime)
│   ├── pusher-server.ts          # Pusher server
│   ├── rbac-middleware.ts        # RBAC untuk API routes
│   └── utils.ts                  # Utility functions
│
├── prisma/
│   ├── schema.prisma             # Database schema (~29 model)
│   └── migrations/               # Database migrations
│
├── scripts/                      # Utility scripts
│   ├── seed.ts                   # Database seeding
│   ├── migrate-neon.ts           # Neon migration script
│   └── sync-neon.ts              # Sync to Neon
│
├── docker/                       # Docker configuration
│   ├── Dockerfile                # Multi-stage Docker build
│   ├── docker-compose.yml        # Docker compose setup
│   └── entrypoint.sh             # Container entrypoint
│
├── public/                       # Static assets
│
├── .env                          # Environment variables
├── .env.example                  # Environment template
├── next.config.js                # Next.js configuration
├── tailwind.config.ts            # Tailwind CSS config
├── tsconfig.json                 # TypeScript config
└── package.json                  # Dependencies & scripts
```

---

## 🎯 Fitur Lengkap

### 1. 🔐 Autentikasi & Authorization (RBAC)

**Teknologi:** JWT (jose) dengan httpOnly cookies

#### Fitur:
- ✅ Login dengan email dan password (hashing bcrypt)
- ✅ Session management dengan JWT token (`ekskul_session`)
- ✅ Auto-refresh token untuk mencegah session drop
- ✅ Logout dengan clear cookies
- ✅ Protected routes dengan middleware

#### Role Hierarchy:
```
SUPER_ADMIN
  └─ Full akses ke semua fitur dan organisasi
     └─ Dapat membuat/edit/hapus organisasi
        └─ Manage semua admin

administrator
  └─ Akses penuh ke organisasi yang ditugaskan
     └─ CRUD anggota, absensi, kas, jadwal, materi
        └─ Tidak bisa manage organisasi atau admin lain

organization_admin (ORG_ADMIN)
  └─ Akses terbatas ke organisasi tertentu
     └─ View data, input absensi dasar
        └─ Tidak bisa manage XP atau delete data
```

#### Keamanan:
- 🛡️ Password hashing dengan bcrypt (10 salt rounds)
- 🔒 HttpOnly cookies (tidak bisa diakses JavaScript)
- ⏱️ Token expiry dan refresh mechanism
- 🚫 Rate limiting untuk prevent brute force
- 📝 Activity logging untuk audit trail

---

### 2. 🏢 Multi-Organisasi Dinamis

**Halaman:** `/organisasi`, `/admin/organisasi`

#### Fitur Utama:
- ✅ **Buat organisasi baru** tanpa perlu coding
- ✅ **Edit detail organisasi**: nama, slug, kategori, deskripsi
- ✅ **Atur jadwal pertemuan**: hari, waktu mulai/selesai, lokasi
- ✅ **Assign admin** ke organisasi tertentu (many-to-many)
- ✅ **Aktifkan/nonaktifkan** organisasi
- ✅ **Hapus organisasi** (cascade delete semua data terkait)

#### Kategori Organisasi:
- 📚 **Ekstrakurikuler**: Programming, English, Robotik, dll
- 🏛️ **Organisasi Siswa**: OSIS, MPK
- 🎨 **Klub**: Fotografi, Musik, Seni

#### Isolasi Data:
- Setiap organisasi memiliki data terpisah:
  - Anggota (Member)
  - Absensi (Attendance)
  - Kas (CashTransaction, CashExpense)
  - Jadwal (Schedule)
  - Materi (Material)
  - Dokumentasi (Documentation)
  - Achievement (Pencapaian)
  - Pendaftaran (Registration)

- Admin hanya bisa melihat data organisasi yang ditugaskan
- Sistem `org-context.ts` memastikan tidak ada data leak antar organisasi

---

### 3. 📊 Dashboard & Analytics

**Halaman:** `/dashboard`

#### Statistik Real-time:
- 👥 **Total Anggota** per organisasi (dengan filter)
- ✅ **Absensi Hari Ini**: Hadir / Izin / Sakit / Tidak Hadir
- 💰 **Saldo Kas** berjalan
- 📈 **Tren Keuangan** 6 bulan terakhir

#### Chart & Visualisasi:
- 📊 **Chart Absensi Mingguan** (Line chart)
- 💵 **Tren Kas 6 Bulan** (Bar chart)
- 🔥 **Aktivitas API 30 Hari** (Area chart)
- 🏆 **Top 3 Leaderboard** dengan podium (gold/silver/bronze)

#### Fitur Tambahan:
- 🎥 **Mode Presentasi** — Fullscreen dashboard untuk tampilan layar
- ⚡ **Form Quick Add** — Tambah anggota langsung dari dashboard
- 🔄 **Auto-refresh** data setiap 30 detik
- 📱 **Responsive** — Mobile-friendly layout

---

### 4. 👥 Manajemen Anggota

**Halaman:** `/siswa`

#### Fitur CRUD:
- ➕ **Tambah Anggota** — Form lengkap dengan validasi
- ✏️ **Edit Anggota** — Update data (nama, kelas, email, jabatan, status)
- 🗑️ **Hapus Anggota** — Soft delete dengan confirmation dialog
- 👁️ **Detail Anggota** — View profil lengkap dengan riwayat

#### Fitur Pencarian & Filter:
- 🔍 **Search** by nama atau NIS
- 🏫 **Filter Kelas** — X, XI, XII, atau semua
- 📚 **Filter Kejuruan** — SKARLA, SKAKES
- 📄 **Pagination** — 10/25/50/100 per halaman
- 🔄 **Sorting** — By nama, kelas, level, XP

#### Data Anggota:
- **Personal**: NIS, Nama, Email, Kelas, Kejuruan
- **Organisasi**: Jabatan (Ketua, Wakil, Anggota, dll), Status (ACTIVE/INACTIVE/GRADUATED)
- **Gamifikasi**: Level (1-5), XP, Achievement earned
- **Timestamp**: Tanggal join, Last updated

#### Manajemen XP:
- ➕ **Tambah XP** — Dengan alasan (tugas, partisipasi, achievement)
- ➖ **Kurangi XP** — Untuk penalty/pelanggaran
- 📜 **Log XP** — History lengkap perubahan XP
- 🆙 **Auto Level Up** — Otomatis naik level saat XP cukup

#### Import Massal:
- 📥 **Import dari Excel/CSV**
- 🗺️ **Mapping Kolom** — Fleksibel sesuai format file
- ✅ **Validasi Data** — Check duplikat, format email, dll
- 📊 **Preview Before Import**
- ⚠️ **Error Report** — List baris yang gagal dengan alasan

---

### 5. ✅ Sistem Absensi

**Halaman:** `/absensi`, `/rekap-absensi`

#### Absensi Harian (`/absensi`):
- 📅 **Pilih Tanggal** — Input absensi untuk tanggal tertentu
- ✅ **Status Kehadiran**:
  - 🟢 **Hadir** — +10 XP otomatis
  - 🟡 **Izin** — Tanpa penalty
  - 🔴 **Sakit** — Tanpa penalty
  - ⚫ **Tidak Hadir** — Tanpa XP, mungkin ada penalty
- 💰 **Input Kas** — Per anggota (optional)
- 📝 **Catatan** — Notes tambahan untuk absensi
- 🔄 **Bulk Actions** — Mark semua hadir/izin/sakit
- 💾 **Auto-save** — Save otomatis setiap perubahan

#### Rekap Absensi (`/rekap-absensi`):
- 📊 **Statistik per Anggota**:
  - Total kehadiran bulanan
  - Persentase kehadiran
  - Streak (berapa kali berturut-turut hadir)
- 📈 **Chart 6 Bulan** — Visualisasi tren kehadiran
- 📅 **Filter Periode** — Bulan/tahun tertentu
- 🎯 **Target Kehadiran** — Tracking pencapaian target (misal 80%)
- 📤 **Export** — Download rekap ke Excel/PDF

#### QR Code Integration:
- 📱 **Scan QR** untuk absen (mobile-friendly)
- ⏰ **Time-limited QR** — QR expired setelah waktu tertentu
- 📍 **GPS Validation** — Check jarak dari lokasi kegiatan
- 🔒 **Anti-fraud** — IP validation, device fingerprinting

---

### 6. 💰 Manajemen Keuangan

**Halaman:** `/kas`, `/pengeluaran`

#### Buku Kas (`/kas`):
- 💵 **Pemasukan Kas** per anggota
- 📋 **Riwayat Transaksi** dengan pagination
- 🔍 **Filter** by tanggal, anggota, organisasi
- 💰 **Saldo Berjalan** — Total kas real-time
- 📊 **Chart Pemasukan** — Visualisasi per bulan
- 📝 **Deskripsi Transaksi** — Keterangan untuk setiap transaksi

#### Pengeluaran (`/pengeluaran`):
- 💸 **Catat Pengeluaran** — Dengan jumlah dan deskripsi
- 📅 **Tanggal Pengeluaran** — Tracking kapan uang dikeluarkan
- 🏷️ **Kategori** — Konsumsi, Alat, Transport, dll
- 📊 **Statistik Pengeluaran** — Total per bulan, kategori terbanyak
- 📈 **Chart Pengeluaran vs Pemasukan**

#### Laporan Keuangan:
- 📊 **Cash Flow** — Pemasukan vs Pengeluaran
- 💹 **Profit/Loss** — Keuntungan atau defisit
- 📈 **Tren 6 Bulan** — Grafik cash flow
- 📤 **Export to Excel/PDF** — Laporan lengkap

---

### 7. 🎤 Sistem Wawancara (Interview System)

**Halaman:** `/wawancara`

Sistem wawancara untuk rekrutmen anggota baru OSIS/MPK dengan antrian terkelola.

#### Manajemen Sesi Wawancara:
- 📅 **Buat Sesi Baru** — Set jadwal mulai & selesai
- 🎯 **Status Sesi**:
  - ⏰ **SCHEDULED** — Sesi dijadwalkan
  - ✅ **ACTIVE** — Sesi berlangsung
  - 🔒 **LOCKED** — Sesi dikunci, tidak terima pendaftar baru
  - ✔️ **SELESAI** — Sesi telah berakhir
- 🏢 **Tipe Organisasi** — OSIS atau MPK
- 🔐 **Finalize** — Kunci hasil wawancara

#### QR Code System:
- 🎫 **Generate QR Token** untuk validasi peserta
- ⏰ **Time-limited** — Set masa berlaku QR
- 🔄 **Multiple QR** — Buat beberapa QR untuk berbeda pintu masuk
- 🔒 **Deactivate QR** — Matikan QR yang sudah tidak dipakai

#### Antrian Wawancara:
- 🔢 **Nomor Antrian Otomatis** — Sequential numbering
- 📱 **Scan QR untuk Daftar** — Peserta scan QR di lokasi
- 🌍 **Validasi Lokasi**:
  - 📍 **GPS Coordinates** — Latitude & Longitude
  - 📏 **Jarak dari Venue** — Hitung jarak dalam meter
  - 🚨 **Status Validasi**: SAH / MENCURIGAKAN / INVALID
  - 🗺️ **IP Geolocation** — Negara, ISP, dll
- 👤 **Data Peserta**: Nama, Kelas, Kejuruan
- 📊 **Status Antrian**: MENUNGGU / DIPANGGIL / SELESAI

#### Penilaian Hasil Wawancara:
- ✅ **Input Hasil** by interviewer
- 📋 **Keterangan**: LANJUT / TIDAK LANJUT
- 🎯 **Hasil Akhir**: LOLOS / TIDAK LOLOS
- 💯 **Persentase Nilai** (0-100)
- 📝 **Catatan Pewawancara** — Feedback detail
- 🔄 **Override by Admin** — Admin bisa ubah hasil dengan alasan
- 📊 **Riwayat Override** — Tracking perubahan hasil

#### Real-time Chat:
- 💬 **Chat Internal** antar pewawancara
- 🔔 **Live Notifications** — Via Pusher
- 👥 **Multi-user Chat** — Semua admin bisa komunikasi
- ⏰ **Timestamp** setiap pesan

#### Reporting:
- 📊 **Statistik Wawancara**:
  - Total peserta
  - Lolos / Tidak lolos
  - Rata-rata persentase nilai
  - Peserta per kelas/kejuruan
- 📤 **Export to Excel** — Data lengkap antrian + hasil
- 📄 **Print-friendly** — Format siap print

---

### 8. 📝 Pendaftaran (Registration)

**Halaman:** `/registration`

#### Pendaftaran Publik:
- 📋 **Form Pendaftaran Online** — Accessible tanpa login
- 🎯 **Pilih Organisasi** — Dropdown organisasi aktif
- 📝 **Data Pendaftar**:
  - Nama lengkap
  - Kelas & Kejuruan
  - Email Gmail (wajib)
  - NISN (optional)
- 🎫 **Generate QR Token** — Untuk verifikasi pendaftaran
- 📧 **Email Konfirmasi** — Otomatis kirim email setelah daftar

#### Admin Panel:
- 📊 **List Pendaftar** — View semua pendaftaran
- 🔍 **Filter** by status, organisasi, tanggal
- ✅ **Approval Status**:
  - ⏳ **MENUNGGU** — Pending review
  - ✅ **DITERIMA** — Approved
  - ❌ **DITOLAK** — Rejected
  - 🟡 **CALON** — Candidate (untuk OSIS/MPK)
- ✏️ **Edit Status** — Bulk atau individual
- 📧 **Kirim Email Notifikasi** — Otomatis notify peserta
- 🗑️ **Delete Pendaftar** — Hapus data yang tidak valid

#### Auto-accept Feature:
- ⚙️ **Auto-accept Setting** per organisasi
- ✅ **Langsung Terima** pendaftar tanpa review manual
- 🎯 **Conditional Auto-accept** — Based on kriteria tertentu

---

### 9. 🎮 Gamifikasi (XP & Achievement System)

**Halaman:** `/leaderboard`, `/pencapaian`, `/siswa`

#### Level System:
| Level | Nama | XP Required | Badge |
|-------|------|-------------|-------|
| 1 | 🌱 Beginner | 0 - 149 | Bronze |
| 2 | 📚 Intermediate | 150 - 349 | Silver |
| 3 | 🚀 Advanced | 350 - 599 | Gold |
| 4 | 💎 Expert | 600 - 899 | Platinum |
| 5 | 👑 Master | 900+ | Diamond |

#### Sumber XP:
- ✅ **Kehadiran** — +10 XP per absensi hadir
- 📚 **Tugas/Proyek** — +20 XP per tugas selesai
- 🎤 **Partisipasi** — +5 XP per kontribusi
- 🏆 **Achievement** — +30 XP per pencapaian
- 📖 **Baca Materi** — +5 XP
- 🎯 **Event Khusus** — Bonus XP (admin)
- ⚠️ **Pelanggaran** — -10 XP (penalty)

#### Achievement System:
- 🏆 **Buat Achievement** — Custom icon, nama, deskripsi
- 💎 **XP Reward** — Set berapa XP yang didapat
- 🎯 **Assign to Member** — Berikan achievement ke anggota
- 📊 **Tracking** — Siapa sudah dapat apa
- 🔔 **Notification** — Notif saat dapat achievement

#### Leaderboard:
- 🥇 **Top 3 Podium** — Gold, Silver, Bronze with special design
- 📊 **Full Leaderboard** — Ranking semua anggota
- 🔍 **Filter** by organisasi
- 📈 **XP Progress Bar** — Visual progress ke level berikutnya
- 🎨 **Badges** — Display level badge
- 📱 **Real-time Update** — Auto-refresh ranking

#### XP Log System:
- 📜 **History Lengkap** — Semua perubahan XP tercatat
- 📊 **Before/After** — XP sebelum & sesudah
- 📝 **Reason** — Alasan pemberian/pengurangan XP
- 👤 **Admin** — Siapa yang memberikan XP
- ⏰ **Timestamp** — Kapan XP berubah
- 🔍 **Filter & Search** — Cari log tertentu

---

### 10. 📧 Sistem Email & Pengumuman

**Halaman:** `/admin/email`, `/admin/email-import`

#### Email Blast:
- 📧 **Kirim Email Massal** ke anggota organisasi
- 📝 **Rich Text Editor** — Format email dengan HTML
- 🎨 **Email Template** — Simpan template untuk dipakai ulang
- 📎 **Attachment Support** — Kirim file lampiran
- 🎯 **Target Audience**:
  - Semua anggota organisasi
  - Filter by kelas
  - Filter by level
  - Custom list dari Excel

#### Email Template:
- 📄 **Template Library** — Simpan berbagai template
- 🏢 **Per Organisasi** — Template terpisah per organisasi
- 🔄 **Reusable** — Gunakan ulang dengan edit minor
- 📧 **Email Types**:
  - Welcome email (pendaftaran diterima)
  - Pengumuman event
  - Reminder jadwal
  - Achievement notification
  - Custom template

#### Import Recipients:
- 📥 **Import dari Excel** — List penerima email
- 🗺️ **Auto-mapping** — Kolom nama & email
- ✅ **Validation** — Check format email valid
- 📊 **Preview** — List penerima sebelum kirim
- ❌ **Skip Invalid** — Hanya kirim ke email valid

#### Email Logs:
- 📊 **Tracking Email Sent**:
  - Total email terkirim
  - Success / Failed
  - Timestamp
  - Recipient info
- ⚠️ **Error Logs** — Kenapa email gagal terkirim
- 📈 **Statistics** — Email sent per hari/bulan
- 🔍 **Search & Filter** — Cari log tertentu

#### Announcement System:
- 📢 **Post Pengumuman** — Tampil di dashboard
- 🔔 **Active/Inactive** — Kontrol visibility
- 📌 **Pinned Announcement** — Highlight pengumuman penting
- ⏰ **Schedule Posting** — Set kapan pengumuman muncul
- 🎯 **Per Organisasi** — Pengumuman terpisah per organisasi

---

### 11. 📚 Materi & Jadwal

**Halaman:** `/materi`, `/jadwal`

#### Materi Harian (`/materi`):
- 📝 **Post Materi** — Konten pembelajaran/notulen rapat
- 📅 **Tanggal Materi** — Tracking kapan materi diberikan
- 🏢 **Per Organisasi** — Materi terpisah per organisasi
- 📍 **Lokasi** — Dimana materi/rapat berlangsung
- 📋 **Notulen** — Catatan lengkap kegiatan
- 🔍 **Search & Filter** — Cari materi by tanggal/organisasi
- 📤 **Export** — Download materi ke PDF

#### Jadwal Kegiatan (`/jadwal`):
- 📅 **Buat Event/Kegiatan** — Tambah jadwal baru
- 📋 **Detail Event**:
  - Judul kegiatan
  - Tanggal & waktu
  - Lokasi/tempat
  - Deskripsi
  - Apakah wajib hadir
- 🔔 **Mandatory Flag** — Tandai kegiatan wajib
- 🏢 **Multi-organisasi** — Jadwal untuk organisasi tertentu atau semua
- 📊 **Calendar View** — Tampilan kalender interaktif
- 🔍 **Filter** by bulan, organisasi, wajib/tidak
- 📧 **Email Reminder** — Kirim notifikasi sebelum event

---

### 12. 📸 Dokumentasi Kegiatan

**Halaman:** `/dokumentasi`

#### Upload Dokumentasi:
- 📷 **Upload Foto** — Multiple files sekaligus
- 🎥 **Upload Video** — Support video documentation
- ☁️ **Cloudinary Integration** — Cloud storage otomatis
- 📝 **Metadata**:
  - Judul dokumentasi
  - Deskripsi
  - Tanggal pengambilan
  - Kategori/tag
  - Organisasi terkait

#### Gallery View:
- 🖼️ **Grid Gallery** — Tampilan grid responsive
- 🔍 **Lightbox** — View full-size image
- 🎬 **Video Player** — Embedded video player
- 📊 **Filter**:
  - By organisasi
  - By kategori
  - By tanggal
  - By tipe (foto/video)
- 🔄 **Lazy Loading** — Load image on demand

#### Manajemen Dokumentasi:
- ✏️ **Edit Info** — Update judul, deskripsi
- 🗑️ **Delete** — Hapus dokumentasi (soft delete)
- 📤 **Download** — Download original file
- 🔗 **Share Link** — Generate shareable link
- 📊 **View Statistics** — Berapa kali dilihat

---

### 13. 📊 Laporan & Export

**Halaman:** `/laporan`, `/export`

#### Laporan Tersedia:
- 📊 **Laporan Kehadiran** — Per anggota/per periode
- 💰 **Laporan Keuangan** — Pemasukan, pengeluaran, saldo
- 📈 **Laporan Gamifikasi** — XP, level, achievement per anggota
- 🎯 **Laporan Event** — Rekapitulasi kegiatan
- 👥 **Laporan Anggota** — Data lengkap anggota

#### Format Export:
- 📗 **Excel (.xlsx)** — With formatting & multiple sheets
- 📄 **PDF** — Print-ready format
- 📋 **CSV** — Simple comma-separated values
- 📊 **JSON** — For data integration

#### Export Features:
- 🎨 **Custom Styling** — Logo, header, footer
- 📊 **Chart Export** — Include charts dalam PDF
- 📅 **Date Range** — Export data periode tertentu
- 🏢 **Multi-org Export** — Gabung data beberapa organisasi
- 📧 **Email Export** — Kirim hasil export via email

---

### 14. 📜 Log Aktivitas & Audit Trail

**Halaman:** `/log`

#### Activity Logging:
- 📝 **Log Semua Aksi** admin:
  - CREATE — Tambah data baru
  - UPDATE — Edit data existing
  - DELETE — Hapus data
  - LOGIN — User login
  - LOGOUT — User logout
- 👤 **User Info** — Siapa yang melakukan aksi
- 📋 **Detail Aksi** — Apa yang dilakukan
- 🗃️ **Tabel & Record ID** — Target aksi
- 📊 **Before/After Data** — Data sebelum & sesudah edit (JSON)
- 🌐 **IP Address** — Track dari mana aksi dilakukan
- ⏰ **Timestamp** — Kapan aksi terjadi

#### Filter & Search:
- 🔍 **Search** by user, aksi, tabel
- 📅 **Filter by Date Range**
- 🏢 **Filter by Organisasi**
- 📊 **Filter by Action Type**
- 📄 **Pagination** — Handle ribuan log

#### Audit Features:
- 🕵️ **Forensic Analysis** — Tracking perubahan data
- 🔄 **Compare Changes** — Before vs After view
- 📊 **Activity Statistics** — Most active admin, peak hours
- 📤 **Export Logs** — Download audit trail

---

### 15. 🔧 Fitur Admin Lainnya

#### Manajemen User (`/admin/users`):
- 👥 **CRUD Users** — Kelola admin
- 🎭 **Assign Roles** — Set role per user
- 🏢 **Assign Organizations** — Tugaskan admin ke organisasi
- 🔒 **Reset Password** — Admin bisa reset password user
- ❌ **Deactivate User** — Nonaktifkan akses tanpa delete

#### Update Sistem (`/update-sistem`):
- 📢 **Post Update/Pengumuman** sistem
- 📝 **Changelog** — Catat perubahan versi
- 🏷️ **Version Tagging** — Semantic versioning
- 📋 **Update Types**:
  - ✨ **update** — Fitur baru
  - 📢 **pengumuman** — Announcement
  - 🔧 **perbaikan** — Bug fix
- 👁️ **Read Tracking** — Admin bisa tandai sudah baca
- 🔔 **Notification** — Notif saat ada update baru

#### QR Code Generator (`/qr-code`):
- 🎫 **Generate QR** untuk berbagai keperluan
- ⏰ **Expiry Time** — Set masa berlaku
- 🔐 **Secure Token** — Random token generation
- 📊 **QR Usage Stats** — Berapa kali di-scan
- 🗑️ **Deactivate QR** — Nonaktifkan QR lama

#### Import Data (`/import`):
- 📥 **Import Anggota** dari Excel/CSV
- 📥 **Import Email List** untuk blast email
- 🗺️ **Column Mapping** — Fleksibel mapping kolom
- ✅ **Data Validation** — Check format & duplikat
- 📊 **Preview Import** — Review sebelum save
- ⚠️ **Error Handling** — Report baris yang error
- 📜 **Import Logs** — History import dengan stats

#### Ambil Data Siswa (`/ambil-siswa`):
- 📥 **Fetch Data** dari database eksternal (jika ada)
- 🔄 **Sync Data** siswa dari sistem lain
- 📊 **Mapping Data** — Convert format data
- ✅ **Validation** — Check consistency

#### Hapus Peserta Wawancara (`/hapus-peserta`):
- 🗑️ **Batch Delete** peserta wawancara
- 🔍 **Filter & Select** — Pilih peserta tertentu
- ⚠️ **Confirmation** — Double confirm before delete
- 📜 **Log Deletion** — Track siapa hapus apa

---

### 16. 🚀 Kenaikan Kelas Otomatis (School Year Progression)

#### Fitur:
- 🎓 **Otomatis Naikkan Kelas** siswa di akhir tahun ajaran
- 📊 **Batch Processing** — Process semua siswa sekaligus
- 🏫 **Class Mapping**:
  - X → XI
  - XI → XII
  - XII → GRADUATED
- 📜 **Progression Log** — History kenaikan kelas
- 🔄 **Revert Function** — Undo kenaikan kelas jika ada kesalahan
- 📋 **Graduation Tracking** — Tandai siswa lulus

#### Progression Details:
- 📅 **School Year** — Track tahun ajaran (misal: 2024/2025 → 2025/2026)
- 📊 **Statistics**:
  - Total dipromosikan (naik kelas)
  - Total graduated (lulus)
- 👤 **Executed By** — Admin yang menjalankan
- ⏰ **Timestamp** — Kapan progression dijalankan
- 🔄 **Revert Info** — Jika di-revert, by siapa & kapan

---

## 🗄️ Database Schema

### Model Database Utama (29 Models):

#### Core System:
- **User** — Admin/pengguna sistem dengan role & permissions
- **Organization** — Ekstrakurikuler/organisasi dinamis
- **OrganizationAdmin** — Relasi many-to-many User ↔ Organization

#### Member Management:
- **Member** — Anggota organisasi dengan XP, level, jabatan
- **Siswa** — Data siswa ekstrakurikuler umum
- **AnggotaOsis** — Anggota OSIS
- **AnggotaMpk** — Anggota MPK

#### Attendance System:
- **Attendance** — Absensi per member per organisasi
- **Absensi** — Absensi siswa umum
- **AbsensiOrganisasi** — Absensi OSIS/MPK

#### Financial System:
- **CashTransaction** — Pemasukan kas
- **CashExpense** — Pengeluaran kas
- **PengeluaranKas** — Pengeluaran OSIS/MPK

#### Registration System:
- **Registration** — Pendaftaran umum
- **RegistrationEskul** — Pendaftaran ekstrakurikuler
- **RegistrationOsisMpk** — Pendaftaran OSIS/MPK

#### Interview System:
- **SesiWawancara** — Sesi wawancara dengan status & jadwal
- **QrWawancara** — QR token untuk validasi
- **AntrianWawancara** — Queue peserta dengan GPS validation
- **HasilWawancara** — Hasil penilaian wawancara
- **ChatWawancara** — Chat internal antar pewawancara

#### Gamification:
- **Achievement** — Pencapaian yang bisa diraih
- **MemberAchievement** — Tracking achievement per member
- **Pencapaian** — Pencapaian global
- **ExpLog** — Log perubahan XP

#### Content Management:
- **Material** — Materi pembelajaran/notulen
- **MateriHariIni** — Materi harian OSIS/MPK
- **Schedule** — Jadwal kegiatan
- **JadwalKegiatan** — Jadwal kegiatan umum
- **Documentation** — Dokumentasi dengan foto (JSON array)
- **DokumentasiFoto** — Dokumentasi foto individual
- **Announcement** — Pengumuman organisasi

#### Email System:
- **EmailTemplate** — Template email reusable
- **EmailLog** — Log email terkirim
- **EmailImportLog** — Log import recipient
- **EmailSetting** — Konfigurasi email (SMTP)

#### System Management:
- **LogAktivitas** — Activity log dengan before/after data
- **SystemUpdate** — Update sistem & changelog
- **SchoolYearProgression** — Kenaikan kelas batch
- **ClassProgressionLog** — Log detail kenaikan kelas per siswa

#### Master Data:
- **MasterKelas** — Master data kelas (X, XI, XII)
- **MasterKejuruan** — Master data kejuruan (SKARLA, SKAKES)
- **Kegiatan** — Master kegiatan
- **PengelompokanKegiatan** — Grouping siswa per kegiatan

---

## 🔐 Security Features

### Authentication & Authorization:
- 🔒 **JWT Authentication** dengan httpOnly cookies
- 🔄 **Auto-refresh Token** — Prevent session drop
- 🛡️ **Password Hashing** — bcrypt dengan 10 salt rounds
- 🚫 **Rate Limiting** — Prevent brute force attacks
- 📝 **Activity Logging** — Audit trail lengkap
- 🎭 **Role-Based Access Control (RBAC)** — Granular permissions

### Data Protection:
- 🏢 **Organization Isolation** — Data terisolasi per organisasi
- 🔐 **Input Validation** — Zod schema validation
- 🛡️ **SQL Injection Prevention** — Prisma ORM
- 🔒 **XSS Prevention** — Sanitized input/output
- 🚧 **CSRF Protection** — Token-based

### Infrastructure Security:
- 🔐 **HTTPS Only** — Enforce SSL/TLS
- 🛡️ **Security Headers**:
  - HSTS (HTTP Strict Transport Security)
  - X-Frame-Options: DENY
  - X-Content-Type-Options: nosniff
  - Referrer-Policy: strict-origin-when-cross-origin
- 🔒 **Environment Variables** — Sensitive data di .env
- 🐳 **Docker Security** — Non-root user, minimal base image

### API Security:
- 🔑 **API Authentication** — JWT required
- 🚦 **Rate Limiting** — Prevent API abuse
- 📊 **Request Validation** — Validate all input
- 🔒 **Response Sanitization** — No sensitive data leak
- 📝 **API Logging** — Track all API calls

---

## 🚀 Installation & Setup

### Prerequisites:
- Node.js 20+ 
- PostgreSQL 16+
- npm atau yarn

### 1. Clone Repository:
```bash
git clone https://github.com/your-repo/sistem-ekstrakurikuler.git
cd sistem-ekstrakurikuler
```

### 2. Install Dependencies:
```bash
npm install
# atau
yarn install
```

### 3. Setup Environment Variables:
Copy `.env.example` ke `.env` dan isi variabel:

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/dbname"
DIRECT_URL="postgresql://user:password@localhost:5432/dbname"

# JWT
JWT_SECRET="your-super-secret-jwt-key"

# Cloudinary
NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME="your-cloud-name"
CLOUDINARY_API_KEY="your-api-key"
CLOUDINARY_API_SECRET="your-api-secret"

# Pusher (Real-time)
NEXT_PUBLIC_PUSHER_APP_KEY="your-pusher-key"
NEXT_PUBLIC_PUSHER_CLUSTER="ap1"
PUSHER_APP_ID="your-app-id"
PUSHER_SECRET="your-pusher-secret"

# Email (Gmail)
GMAIL_USER="your-email@gmail.com"
GMAIL_APP_PASSWORD="your-app-password"

# Other
NEXT_PUBLIC_BASE_URL="http://localhost:3000"
```

### 4. Setup Database:
```bash
# Generate Prisma Client
npx prisma generate

# Push schema ke database
npx prisma db push

# Atau jalankan migrasi
npx prisma migrate dev

# Seed initial data (optional)
npm run db:seed
```

### 5. Run Development Server:
```bash
npm run dev
# Buka http://localhost:3000
```

### 6. Build for Production:
```bash
npm run build
npm start
```

---

## 🐳 Docker Deployment

### Build Docker Image:
```bash
docker build -t artemis-ekskul:latest .
```

### Run with Docker Compose:
```bash
docker-compose up -d
```

### Docker Compose Example:
```yaml
version: '3.8'
services:
  app:
    image: artemis-ekskul:latest
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - db
  
  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=artemis
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

---

## 📚 Usage Guide

### Login:
1. Buka `https://artemis.smkairlangga.sch.id/login`
2. Masukkan email & password
3. Klik "Login" — Redirect ke dashboard

### Membuat Organisasi Baru:
1. Login sebagai **SUPER_ADMIN**
2. Klik menu **Organisasi** di sidebar
3. Klik tombol **"+ Buat Organisasi"**
4. Isi form:
   - Nama organisasi
   - Slug (URL-friendly)
   - Kategori (Ekstrakurikuler/Organisasi)
   - Deskripsi
   - Jadwal pertemuan (hari, waktu, lokasi)
5. Klik **"Simpan"**
6. Organisasi baru siap digunakan!

### Menambah Anggota:
1. Pilih organisasi di dropdown
2. Klik menu **"Siswa/Anggota"**
3. Klik **"+ Tambah Anggota"**
4. Isi data anggota
5. Klik **"Simpan"**

### Input Absensi:
1. Klik menu **"Absensi"**
2. Pilih tanggal
3. Mark status kehadiran setiap anggota
4. (Optional) Input uang kas
5. Klik **"Simpan Semua"**

### Kelola Kas:
1. Klik menu **"Kas"** untuk pemasukan
2. Input transaksi per anggota
3. Klik menu **"Pengeluaran"** untuk pengeluaran
4. Lihat saldo di dashboard

### Buat Sesi Wawancara:
1. Klik menu **"Wawancara"**
2. Klik **"+ Buat Sesi Baru"**
3. Set jadwal & organisasi
4. Generate QR code
5. Peserta scan QR untuk daftar antrian
6. Input hasil wawancara
7. Finalize sesi

---

## 🔧 Scripts npm

| Command | Deskripsi |
|---------|-----------|
| `npm run dev` | Jalankan development server |
| `npm run build` | Build untuk production |
| `npm start` | Jalankan production server |
| `npm run db:generate` | Generate Prisma Client |
| `npm run db:push` | Push schema ke database |
| `npm run db:migrate` | Jalankan migrasi database |
| `npm run db:seed` | Seed database dengan data awal |
| `npm run db:studio` | Buka Prisma Studio (GUI database) |
| `npm run setup` | Setup lengkap (generate + push + seed) |

---

## 🎨 UI/UX Features

### Design System:
- 🎨 **Consistent Colors** — Color palette terorganisir
- 📱 **Responsive Design** — Mobile, tablet, desktop
- 🌙 **Dark Mode Ready** — Support dark theme (optional)
- ♿ **Accessibility** — WCAG compliant
- 🎯 **Loading States** — Skeleton, spinner, progress bar
- ✅ **Error Handling** — User-friendly error messages
- 🔔 **Toast Notifications** — React Hot Toast

### Animations:
- 🎬 **Page Transitions** — Smooth navigation
- 📊 **Chart Animations** — Animated data viz
- 🎭 **Micro-interactions** — Hover effects, button feedback
- 🌊 **Parallax Effects** — Depth illusion
- 🔄 **Loading Animations** — GSAP powered

### Components:
- 🎴 **Cards** — Dengan shadow & hover effects
- 📊 **Tables** — Sortable, filterable, pagination
- 📋 **Forms** — Validation, error messages
- 🔘 **Buttons** — Multiple variants & sizes
- 🔔 **Modals** — Confirm dialogs, forms
- 🏷️ **Badges** — Status indicators
- 📈 **Charts** — Line, bar, pie, area
- 🎨 **Color Picker** — Custom color selection

---

## 🐛 Troubleshooting

### Issue: Session Drop (Auto-logout)
**Solution:** Sudah diperbaiki dengan auto-refresh token. Token akan di-refresh otomatis sebelum expired.

### Issue: Data Leak Antar Organisasi
**Solution:** Implementasi `org-context.ts` untuk isolasi ketat data per organisasi.

### Issue: Absensi/Kas Tidak Tersimpan
**Solution:** Tambah verifikasi data setelah save. Check response status dan refetch data.

### Issue: Database Connection Error
**Solution:** 
- Check DATABASE_URL di .env
- Pastikan PostgreSQL running
- Pastikan firewall tidak block connection

### Issue: Email Tidak Terkirim
**Solution:**
- Check GMAIL_USER & GMAIL_APP_PASSWORD
- Pastikan "Less secure app access" di-enable (atau gunakan App Password)
- Check email quota limit

### Issue: Cloudinary Upload Failed
**Solution:**
- Verifikasi CLOUDINARY credentials
- Check file size (max 10MB)
- Check file format (jpg, png, pdf, etc)

### Issue: Build Error
**Solution:**
```bash
# Clear cache
rm -rf .next node_modules
npm install
npm run build
```

---

## 📊 API Documentation

### Authentication Endpoints:

#### POST `/api/auth/login`
Login user dengan email & password.
```json
{
  "email": "admin@example.com",
  "password": "password123"
}
```

#### POST `/api/auth/logout`
Logout user & clear session.

#### GET `/api/auth/me`
Get current user info.

### Member Endpoints:

#### GET `/api/members`
Get list anggota (dengan pagination & filter).

Query params:
- `organization_id` (required)
- `search` (optional)
- `page` (default: 1)
- `limit` (default: 10)

#### POST `/api/members`
Tambah anggota baru.

#### PUT `/api/members/:id`
Update anggota.

#### DELETE `/api/members/:id`
Hapus anggota.

### Attendance Endpoints:

#### GET `/api/attendance`
Get absensi (filter by date, organization).

#### POST `/api/attendance`
Input absensi harian.

#### PUT `/api/attendance/:id`
Update absensi.

### Cash Endpoints:

#### GET `/api/cash/transactions`
Get pemasukan kas.

#### POST `/api/cash/transactions`
Tambah transaksi kas.

#### GET `/api/cash/expenses`
Get pengeluaran kas.

#### POST `/api/cash/expenses`
Tambah pengeluaran.

### Wawancara Endpoints:

#### GET `/api/wawancara/sesi`
Get list sesi wawancara.

#### POST `/api/wawancara/sesi`
Buat sesi wawancara baru.

#### GET `/api/wawancara/antrian`
Get antrian wawancara.

#### POST `/api/wawancara/hasil`
Input hasil wawancara.

---

## 🤝 Contributing

### Development Workflow:
1. Fork repository
2. Create feature branch: `git checkout -b feature/nama-fitur`
3. Commit changes: `git commit -m "Add: fitur baru"`
4. Push to branch: `git push origin feature/nama-fitur`
5. Create Pull Request

### Commit Convention:
- `feat:` — Fitur baru
- `fix:` — Bug fix
- `docs:` — Update dokumentasi
- `style:` — Format code (tidak ubah logic)
- `refactor:` — Refactor code
- `test:` — Tambah/update tests
- `chore:` — Update dependencies, config

### Code Style:
- TypeScript strict mode
- ESLint + Prettier
- Functional components (React)
- Named exports
- Comment untuk logic kompleks

---

## 📝 Changelog

### Version 2.0.0 (Current)
- ✨ Multi-organisasi dinamis
- ✨ Gamifikasi lengkap (XP, level, achievement)
- ✨ Sistem wawancara dengan GPS validation
- ✨ Real-time chat (Pusher)
- ✨ Email blast dengan template
- ✨ Import/export Excel
- 🔧 Fix session drop issue
- 🔧 Fix data leak antar organisasi
- 🔧 Improve RBAC middleware
- 🔧 Add activity logging

### Version 1.0.0
- 🎉 Initial release
- Basic CRUD anggota
- Absensi harian
- Keuangan sederhana

---

## 📄 License

Copyright © 2024-2026 SMK Airlangga Balikpapan - Yayasan Airlangga Balikpapan.  
All rights reserved.

Project ini dikembangkan khusus untuk internal SMK Airlangga Balikpapan.

---

## 👥 Team

**Developed by:**
- SMK Airlangga Balikpapan IT Team
- SKARLAKES Ecosystem

**Contact:**
- Website: [https://smkairlangga.sch.id](https://smkairlangga.sch.id)
- Email: info@smkairlangga.sch.id
- Deploy: [artemis.smkairlangga.sch.id](https://artemis.smkairlangga.sch.id)

---

## 🙏 Acknowledgments

Special thanks to:
- Next.js team untuk framework yang luar biasa
- Prisma untuk ORM yang powerful
- Vercel untuk hosting & deployment
- Supabase/Neon untuk PostgreSQL hosting
- Cloudinary untuk image hosting
- Pusher untuk real-time infrastructure
- shadcn/ui untuk komponen UI yang bagus
- Dan semua open-source contributors!

---

## 🔮 Roadmap

### Planned Features:
- [ ] Mobile app (React Native / Flutter)
- [ ] Chatbot AI untuk FAQ
- [ ] Advanced analytics & reporting
- [ ] Integration dengan sistem akademik sekolah
- [ ] Multi-language support (Bahasa & English)
- [ ] Dark mode full support
- [ ] PWA (Progressive Web App)
- [ ] Notifikasi push
- [ ] Video conference integration
- [ ] E-certificate untuk achievement
- [ ] Sistem polling & voting
- [ ] Forum diskusi antar anggota
- [ ] Marketplace untuk merchandise organisasi

---

## ❓ FAQ

**Q: Apakah bisa digunakan untuk sekolah lain?**  
A: Ya! Sistem ini bersifat multi-organisasi dinamis dan bisa disesuaikan dengan kebutuhan sekolah mana pun.

**Q: Berapa banyak organisasi yang bisa dibuat?**  
A: Tidak ada limit. Bisa puluhan atau ratusan organisasi.

**Q: Apakah data aman?**  
A: Ya. Data terisolasi per organisasi dengan RBAC ketat, JWT authentication, dan activity logging lengkap.

**Q: Bagaimana cara backup data?**  
A: Gunakan `pg_dump` untuk backup PostgreSQL database. Atau gunakan fitur backup otomatis Supabase/Neon.

**Q: Support mobile?**  
A: Web responsive (mobile-friendly). Mobile app native masih dalam roadmap.

**Q: Biaya hosting?**  
A: Tergantung pilihan:
- Vercel: Free tier (dengan limit)
- Railway: $5-$20/bulan
- VPS: $10-$50/bulan (tergantung spec)
- Supabase/Neon: Free tier available

---

<div align="center">

**⭐ Made with ❤️ by SMK Airlangga Balikpapan**

**Artemis Series — SKARLAKES Ecosystem**

[🌐 Website](https://smkairlangga.sch.id) • [📧 Contact](mailto:info@smkairlangga.sch.id) • [🚀 Demo](https://artemis.smkairlangga.sch.id)

</div>
