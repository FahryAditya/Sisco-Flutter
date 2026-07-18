# LAPORAN ANALISIS SISTEM SISCO (Sistem Absensi Organisasi Skarlakes)

**Tanggal Analisis:** 11 Juli 2026  
**Lingkup:** Flutter Mobile App + Next.js Web App + Firebase Config  
**Total Masalah Teridentifikasi:** 70+  

---

## RINGKASAN EKSEKUTIF

Sistem SISCO memiliki **kerentanan kritis pada autentikasi, otorisasi, integritas data, dan keamanan infrastruktur Firebase**. Beberapa masalah paling serius meliputi penyimpanan password plaintext, JWT secret hardcoded, backup SQL mengandung password hash, absennya validasi server-side, Firestore security rules yang tidak lengkap, dan credential Cloudinary yang terekspos di binary aplikasi.

### Severity Distribution

| Severity | Jumlah |
|----------|--------|
| **KRITIS** | 12 |
| **TINGGI** | 25 |
| **SEDANG** | 22 |
| **RENDAH** | 11+ |

---

## A. KRITIS — Harus Diperbaiki Segera

### A.1 Password Disimpan Plaintext di Firestore (Flutter)
**File:** `lib/services/auth_service.dart:87`  
**Masalah:** Password user disimpan sebagai plaintext di field `password` dokumen Firestore.  
**Dampak:** Admin Firebase Console atau siapapun yang mengeksploitasi Firestore rules bisa melihat password semua user.  
**File terkait:** `lib/screens/admin/admin_page.dart:1399-1461` — ada fitur "Lihat Password" yang menampilkan password user ke administrator.

### A.2 Password Disimpan di LocalStorage (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/login/page.tsx:48-52`  
**Masalah:** Password disimpan di `localStorage` dalam plaintext untuk user non-administrator.  
**Dampak:** Siapa pun dengan akses browser (malware, XSS) bisa membaca password semua user.

### A.3 JWT Secret Fallback Hardcoded (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/lib/auth.ts:8-10`  
**Masalah:** `const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET || 'fallback-secret-change-this')` — jika env tidak diset, secret fallback digunakan.  
**Dampak:** Siapa pun yang tahu source code bisa menandatangani token JWT palsu dan mengakses sistem penuh.

### A.4 Email App Password Disimpan Tanpa Enkripsi (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/admin/email-setting/route.ts:60-68`  
**Masalah:** App password Gmail disimpan dalam plaintext di database.  
**Dampak:** Siapa pun dengan akses database bisa membaca credential email.

### A.5 Credential Cloudinary Terekspos di Binary Aplikasi
**File:** `.env:1-2` dan `pubspec.yaml:66`  
**Masalah:** `.env` berisi `CLOUDINARY_CLOUD_NAME=pebviapm` dan `CLOUDINARY_UPLOAD_PRESET=sisko_unsigned`. File ini dideklarasikan sebagai asset Flutter (`pubspec.yaml:66`), sehingga **terbungkus dalam APK/IPA/web build**.  
**Dampak:** Siapa pun yang decompile APK bisa mendapatkan credential Cloudinary. Upload preset bernama "unsigned" mengonfirmasi bahwa siapapun bisa upload ke Cloudinary tanpa autentikasi.

### A.6 Backup SQL Mengandung Password Hash (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/admin/backup/route.ts:52-123`  
**Masalah:** Backup SQL mengandung bcrypt password hash yang bisa di-download.  
**Dampak:** Attacker bisa melakukan offline brute force terhadap password hash.

### A.7 Password Hash Dikirim ke Client via API (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/users/route.ts:23-26`  
**Masalah:** `select: { id: true, nama: true, email: true, role: true, password: true, created_at: true }` — password hash dikirim ke client.  
**Dampak:** Offline brute force attack pada password hash.

### A.8 Tidak Ada Firestore Security Rules yang Ketat
**File:** `firestore.rules:159-163` (tidak ada `request.auth != null` di koleksi `registrations`)  
**Masalah:** Beberapa koleksi tidak memiliki proteksi auth, update rules tidak ada untuk `cash_transactions`, `cash_expenses`, `documentation`, `achievements`.  
**Dampak:** Siapa pun (bahkan tanpa login) bisa menulis data ke Firestore.

### A.9 Android/iOS API Key Tanpa Restriction
**File:** `android/app/google-services.json:31` dan `lib/firebase_options.dart:44,54,62,73,84`  
**Masalah:** Firebase API keys hardcoded tanpa restriction di Google Cloud Console.  
**Dampak:** API key bisa digunakan oleh siapapun untuk abuse Firebase project (Auth, Storage, Firestore).

### A.10 Registrasi Publik Tanpa Proteksi (Firestore Rules)
**File:** `firestore.rules:159-163`  
**Masalah:** Collection `registrations` mengizinkan write tanpa `request.auth != null`.  
**Dampak:** Siapa pun di dunia bisa mendaftarkan diri berkali-kali (spam), data bisa dimanipulasi.

### A.11 Tidak Ada Validasi Server-side untuk Semua Operasi CRUD
**File:** Semua provider dan screen Flutter  
**Masalah:** Semua operasi CRUD dijalankan langsung dari client side. Firestore security rules adalah satu-satunya pertahanan.  
**Dampak:** Jika security rules lemah, user bisa memanipulasi data milik organisasi lain, mengubah role sendiri, dll.

### A.12 Manual SQL Escaping — Potensi SQL Injection (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/admin/clear-database/route.ts:25-33`  
**Masalah:** Fungsi `escapeSqlValue()` melakukan escape manual untuk INSERT backup. Ada risiko karakter berbahaya lolos dari escaping.  
**Dampak:** SQL injection pada operasi backup/restore database.

---

## B. TINGGI — Prioritas Tinggi

### B.1 App Check DebugProvider di Production (Flutter)
**File:** `lib/main.dart:20-23`  
**Masalah:** `AndroidProvider.debug` dan `AppleProvider.debug` digunakan untuk App Check.  
**Dampak:** Attacker bisa bypass Firebase App Check.

### B.2 User Bisa Registrasi dengan Role Sembarang (Flutter)
**File:** `lib/services/auth_service.dart:26-47`  
**Masalah:** Parameter `role` di method `register()` tidak divalidasi. User bisa daftar dengan role `administrator`.  
**Dampak:** Privilege escalation via registrasi.

### B.3 Tidak Ada Verifikasi Kepemilikan Organisasi (Flutter)
**File:** `lib/screens/absensi/absensi_page.dart:142-149`, `kas_page.dart:221-226`, dan banyak file lain  
**Masalah:** Siapa pun dengan `_selectedOrgId` bisa CRUD data organisasi. Tidak ada pengecekan apakah user adalah admin organisasi tersebut.  
**Dampak:** User dari organisasi A bisa mengubah data organisasi B.

### B.4 Role-Based Access Hanya di UI Layer (Flutter)
**File:** `lib/screens/home/home_page.dart:73-80,129-150`  
**Masalah:** Role checking hanya untuk menampilkan/menyembunyikan menu. Tidak ada pengecekan di sisi Firestore write operations.  
**Dampak:** User "siswa" yang menggunakan Firebase SDK langsung bisa mengakses endpoint admin.

### B.5 isOrganizationAdmin Terlalu Permisif (Flutter)
**File:** `lib/models/user.dart:82-84`  
**Masalah:** Method ini mengembalikan true untuk 5 role berbeda (`organization_admin`, `admin_organisasi`, `admin_eskul`, `organisasi`, `eskul`) tanpa hierarki yang jelas.  
**Dampak:** Role legacy `organisasi` dan `eskul` mungkin tidak seharusnya memiliki akses admin.

### B.6 Semua User Bisa Melihat Semua Data (Flutter)
**File:** `lib/services/firestore_service.dart:118-123`  
**Masalah:** `getUsers()` mengambil SEMUA user tanpa filter.  
**Dampak:** Non-admin user bisa melihat daftar semua user termasuk email dan role mereka.

### B.7 Batch Import Tanpa Transaksi (Flutter)
**File:** `lib/screens/import/import_page.dart:331-366`  
**Masalah:** Import menggunakan `batch.set()` tanpa transaksi. Error di tengah batch menyebabkan data parsial tercommit.  
**Dampak:** Data inkonsisten.

### B.8 N+1 Queries pada Dashboard per 30 Detik (Flutter)
**File:** `lib/screens/dashboard/dashboard_page.dart:98-104`  
**Masalah:** Loop `for (final id in _orgIds)` memanggil `getCashBalance(id)` untuk setiap organisasi. 2 query Firestore per organisasi, di-refresh setiap 30 detik.  
**Dampak:** Beban baca Firestore sangat tinggi, biaya membengkak.

### B.9 N+1 Queries pada Admin Page (Flutter)
**File:** `lib/screens/admin/admin_page.dart:75-87`  
**Masalah:** Loop `for (final org in _orgs)` memanggil `getMembers(org.id)` untuk setiap organisasi.  
**Dampak:** 50+ query Firestore dalam satu render.

### B.10 Tidak Ada Rate Limiting pada Form Submission (Flutter & Web)
**File:** `lib/screens/registration/registration_form_page.dart` dan berbagai endpoint API  
**Masalah:** User bisa mengirim form pendaftaran berkali-kali tanpa batas. Rate limiter hanya ada di endpoint login (`app/api/auth/login/route.ts:18`).  
**Dampak:** Spam registrasi, abuse sistem.

### B.11 Tidak Ada CSRF Protection (Web)
**File:** Semua endpoint API (`lib/auth.ts:46-49`, `app/api/auth/login/route.ts:76-82`)  
**Masalah:** Semua API endpoint tidak memiliki perlindungan CSRF. Hanya `SameSite: lax` yang digunakan.  
**Dampak:** Rentan terhadap serangan CSRF dari subdomain.

### B.12 IDOR — Organization Ownership Tidak Diverifikasi (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/organizations/route.ts`  
**Masalah:** Tidak ada endpoint yang memverifikasi bahwa user adalah admin dari suatu organization tertentu.  
**Dampak:** User bisa mengakses data organisasi yang bukan miliknya.

### B.13 Admin OSIS/MPK Bisa Akses Semua Dokumentasi (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/lib/documentation-auth.ts:15-16`  
**Masalah:** `admin_osis_mpk` dapat mengelola dokumentasi untuk **semua** organisasi.  
**Dampak:** Privilege escalation.

### B.14 Update EXP Manual Tanpa Validasi Status Aktif (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/exp/route.ts:65-117`  
**Masalah:** Tidak ada pengecekan apakah target anggota masih aktif (status = ACTIVE) sebelum update EXP.  
**Dampak:** EXP bisa diberikan ke anggota yang sudah tidak aktif.

### B.15 Race Condition Nomor Antrian Wawancara (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/wawancara/antrian/route.ts:153-178`  
**Masalah:** Dua request bersamaan bisa mendapatkan `nomor_antrian` yang sama. Tidak ada retry loop pada error P2002.  
**Dampak:** Duplikat nomor antrian.

### B.16 Clear Sesi Wawancara Tanpa Verifikasi (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/admin/clear-wawancara/route.ts:40-48`  
**Masalah:** Menghapus semua sesi tanpa konfirmasi apakah ada wawancara yang sedang berlangsung.  
**Dampak:** Kehilangan data wawancara aktif.

### B.17 Upload Expense Proof Tanpa Validasi Tipe File (Storage Rules)
**File:** `storage.rules:39`  
**Masalah:** `expense_proofs` tidak memanggil `isImageFile()`. Semua tipe file bisa diupload.  
**Dampak:** Malware distribution, XSS, storage abuse.

### B.18 Tidak Ada Field Size Limits di Firestore Rules
**File:** `firestore.rules` (hanya member name yang punya min length)  
**Masalah:** Tidak ada validasi ukuran maksimum field.  
**Dampak:** Overflow 1 MiB Firestore document limit, excessive billing.

### B.19 Queue Number Logic Bermasalah (Flutter)
**File:** `lib/screens/wawancara/wawancara_page.dart:223`  
**Masalah:** `nomorAntrian: _queues.length + 1` — nomor antrian berdasarkan list lokal.  
**Dampak:** Duplikat atau loncatan nomor dalam kondisi race.

### B.20 getCashBalance Full Scan (Flutter)
**File:** `lib/services/firestore_service.dart:313-326`  
**Masalah:** Mengambil SEMUA transaksi dan expense untuk dihitung di client. Tidak scalable.  
**Dampak:** Performa menurun drastis untuk organisasi dengan ribuan transaksi.

### B.21 Error Messages Bocor ke User (Flutter & Web)
**File:** Banyak file — contoh: `lib/screens/absensi/absensi_page.dart:155`, `app/api/siswa/route.ts:82`  
**Masalah:** Exception message (`$e`) dan Prisma error codes ditampilkan langsung ke user via SnackBar atau API response.  
**Dampak:** Information disclosure — attacker bisa mendapat informasi struktur database.

### B.22 User ID Tidak Tervalidasi di Log Action (Flutter)
**File:** `lib/services/firestore_service.dart:654-674`  
**Masalah:** `userId: user?.id ?? ''` — user ID bisa string kosong. Tidak ada verifikasi user valid.  
**Dampak:** Log palsu bisa dibuat tanpa identitas valid.

### B.23 Tidak Ada Soft Delete (Flutter)
**File:** `lib/services/firestore_service.dart:176-178`  
**Masalah:** Semua delete adalah hard delete. Tidak ada recovery.  
**Dampak:** Data tidak bisa dipulihkan jika terhapus.

### B.24 FieldValue.serverTimestamp() Tanpa Validasi
**File:** `lib/services/firestore_service.dart:36,165-166`  
**Masalah:** Client juga bisa mengirim value timestamp sendiri jika security rules tidak memvalidasi.  
**Dampak:** Manipulasi timestamp oleh client.

### B.25 Update Member Exp Tanpa Transaksi (Flutter)
**File:** `lib/services/firestore_service.dart:229-235`  
**Masalah:** `updateMemberExp()` menimpa nilai `exp` dan `level` tanpa transaksi. Concurrent access menyebabkan data race.  
**Dampak:** Kehilangan data EXP dalam kondisi concurrent.

---

## C. SEDANG — Perlu Perbaikan

### C.1 Validasi Input Sangat Minimal (Flutter)
**File:** `lib/utils/validation.dart` (45 baris)  
**Masalah:** Hanya validasi email, nama, password, phone, NIS, amount. Tidak ada validasi format kelas, slug, XSS prevention, sanitasi Firestore injection.  
**Dampak:** Data kotor bisa masuk ke database.

### C.2 Tidak Ada Validasi Delete Side-effect (Flutter)
**File:** `lib/services/firestore_service.dart:176-178, 225-227`  
**Masalah:** `deleteOrganization()` dan `deleteMember()` tidak mengecek data terkait (absensi, transaksi kas) sebelum hapus.  
**Dampak:** Orphaned records.

### C.3 Tidak Ada Duplicate Check Registrasi (Flutter & Web)
**File:** `lib/screens/registration/registration_form_page.dart:35-60`, `app/api/registration/eskul/route.ts:9-15`  
**Masalah:** Tidak ada cek duplikasi pendaftaran untuk email/NISN yang sama ke organisasi yang sama.  
**Dampak:** Registrasi ganda.

### C.4 Some Try-Catch Blocks Kosong (Flutter)
**File:** `lib/services/firestore_service.dart:671-673`, `lib/providers/organization_provider.dart:22`  
**Masalah:** Error diabaikan total tanpa logging.  
**Dampak:** Debugging sulit, error tidak terdeteksi.

### C.5 Tidak Ada Graceful Degradation untuk Offline (Flutter)
**File:** Multiple files  
**Masalah:** Jika offline, error Firebase langsung ditampilkan ke user. Tidak ada offline-first handling.  
**Dampak:** User experience buruk di area dengan koneksi tidak stabil.

### C.6 Stream Subscription Tidak Di-cleanup (Flutter)
**File:** `lib/providers/cash_provider.dart:93-98`  
**Masalah:** `_cancelSubs()` tidak dipanggil saat provider di-resubscribe ke org berbeda. Ada edge case subscription ganda.  
**Dampak:** Memory leak, query terduplikasi.

### C.7 Race Condition AuthProvider.checkSession (Flutter)
**File:** `lib/providers/auth_provider.dart:18-33`  
**Masalah:** `checkSession()` bisa dipanggil berkali-kali (hot reload, rebuilds). State `_loading` tidak konsisten.  
**Dampak:** UI flicker, state tidak konsisten.

### C.8 Multiple Stream Subscriptions Redundan (Flutter)
**File:** `lib/screens/organisasi/organisasi_page.dart:42-49` vs `absensi_page.dart:97-124`  
**Masalah:** Data members dan attendance di-subscribe secara independen di banyak screen. Setiap screen membuat Firestore listener baru.  
**Dampak:** Biaya reads berlipat.

### C.9 whereIn Limit 10 (Flutter)
**File:** `lib/services/firestore_service.dart:152`  
**Masalah:** Firestore `whereIn` memiliki batas maksimal 10 nilai.  
**Dampak:** Jika user memiliki >10 orgIds, query akan error.

### C.10 Tidak Ada Composite Index untuk Query Umum (Flutter)
**File:** `lib/services/firestore_service.dart:238-242, 262-269, 293-297`  
**Masalah:** Query kombinasi `where` + `orderBy` memerlukan composite index. Jika tidak dibuat, Firestore menolak query.  
**Dampak:** Error di runtime saat query dijalankan.

### C.11 CashProvider Balance Race Condition (Flutter)
**File:** `lib/providers/cash_provider.dart:24-34`  
**Masalah:** `_recalculateBalance()` dipanggil dari dua listener berbeda (transactions dan expenses). Update hampir bersamaan bisa menyebabkan balance tidak akurat.  
**Dampak:** Saldo kas tidak akurat.

### C.12 Tidak Ada Hierarki Role yang Jelas (Flutter & Web)
**File:** `lib/models/user.dart:80-87`, seluruh sistem role  
**Masalah:** Tidak ada mekanisme inheritance atau permission matrix yang jelas. Role `admin_organisasi`, `admin_eskul`, `admin_osis_mpk` tumpang tindih.  
**Dampak:** Kebingungan akses, potensi privilege escalation.

### C.13 Nama Regex Tidak Menerima Karakter Aksen (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/siswa/route.ts:29-31`  
**Masalah:** Regex `^[a-zA-Z\s.'']*$` tidak mengizinkan karakter aksen seperti é, ñ, ü.  
**Dampak:** Nama siswa dengan aksen ditolak.

### C.14 Email Tidak Dinormalisasi (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/registration/eskul/route.ts:9-15`  
**Masalah:** Email tidak di-`toLowerCase()`. User bisa daftar dengan `User@Gmail.com` dan `user@gmail.com` sebagai dua pendaftaran berbeda.  
**Dampak:** Duplikasi data.

### C.15 Validasi File Upload Hanya MIME Type (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/dokumentasi/route.ts:200-204`  
**Masalah:** Hanya memeriksa MIME type dari header yang bisa dipalsukan. Tidak ada validasi magic bytes.  
**Dampak:** File berbahaya bisa diupload.

### C.16 Missing Cascade Delete untuk Registration (Web - Prisma)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/prisma/schema.prisma:185,213`  
**Masalah:** `RegistrationEskul.organization` dan `RegistrationOsisMpk.organization` tidak memiliki `onDelete: Cascade`.  
**Dampak:** Jika organization dihapus, registrasi terkait menjadi orphan (foreign key violation).

### C.17 Missing Cascade Delete untuk LogAktivitas (Web - Prisma)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/prisma/schema.prisma:424`  
**Masalah:** `LogAktivitas.user` tidak memiliki `onDelete: Cascade`.  
**Dampak:** Jika user dihapus tanpa transfer log, terjadi orphan.

### C.18 Unique Constraint Absensi Memungkinkan Null Duplikat (Web - Prisma)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/prisma/schema.prisma:405-406`  
**Masalah:** `@@unique([anggota_osis_id, tanggal])` — field bisa NULL. PostgreSQL mengizinkan multiple rows dengan NULL.  
**Dampak:** Double entry absensi mungkin terjadi.

### C.19 Documentation Tidak Cascade Delete (Web - Prisma)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/prisma/schema.prisma:250`  
**Masalah:** `Documentation.organization` tidak memiliki `onDelete: Cascade`.  
**Dampak:** Orphan documentation jika organization dihapus.

### C.20 Validasi URL Foto Cloudinary Lemah (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/documentation/create/route.ts:36-41`  
**Masalah:** Validasi hanya mengecek string mengandung "cloudinary.com". Bisa dilewati.  
**Dampak:** URL berbahaya bisa disimpan.

### C.21 Rate Limiter In-Memory Tidak Efektif di Multi-worker (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/lib/rate-limit.ts`  
**Masalah:** Rate limiter menggunakan Map in-memory. Di VPS multi-worker, rate limiter tidak berfungsi karena setiap worker punya Map sendiri.  
**Dampak:** Brute force attack bisa dilakukan 5x per worker.

### C.22 Absensi Rekap Membuat PrismaClient Baru Setiap Request (Web)
**File:** `SIstem-Absensi-Organisasi-Skarlakes/app/api/absensi/rekap/route.ts:8`  
**Masalah:** `const prisma = new PrismaClient()` tanpa disconnect.  
**Dampak:** Connection leak.

---

## D. RENDAH — Perbaikan Bertahap

### D.1 XXE Potential di Upload Excel (Web)
**File:** `lib/services/excel.service.ts:18-98`  
**Masalah:** `XLSX.read(buffer, ...)` rentan XXE jika file Excel berisi referensi entitas XML.

### D.2 Logging Gagal Hanya console.error (Web)
**File:** `lib/log.ts:30-33`  
**Masalah:** Log error hanya di console, tidak ada notifikasi ke admin.

### D.3 Try-Catch Terlalu Broad di Banyak Endpoint (Web)
**Masalah:** Hampir semua route handler menangkap semua error, sehingga error tidak terduga tidak terlihat di log.

### D.4 Bulk Delete Parameter URL (Web)
**File:** `app/api/siswa/route.ts:207-218`  
**Masalah:** Parameter `ids` comma-separated di query string. URL menjadi sangat panjang jika banyak ID.

### D.5 Dependency Versioning Caret (pubspec.yaml)
**Masalah:** Semua dependency menggunakan caret versioning. `flutter pub upgrade` bisa menarik breaking changes.

### D.6 Measurement ID Terekspos
**File:** `lib/firebase_options.dart:50,90`  
**Masalah:** Google Analytics measurement IDs terekspos di source code.

### D.7 Tidak Ada OPTIONS Handler untuk CORS
**Masalah:** Beberapa endpoint tidak memiliki handler OPTIONS untuk CORS preflight.

### D.8 Integer Overflow Potential
**Masalah:** Beberapa endpoint menggunakan `parseInt()` tanpa pengecekan overflow.

### D.9 Captcha Site Key Hardcoded (Flutter)
**File:** `lib/main.dart:23`  
**Masalah:** `ReCaptchaV3Provider('recaptcha-v3-site-key')` — hardcoded site key.

### D.10 Cloudinary Upload Preset Tidak Signed
**File:** `.env`  
**Masalah:** Upload preset bernama `sisko_unsigned` — mengonfirmasi siapapun bisa upload tanpa autentikasi.

### D.11 Tidak Ada Soft Delete Mechanism
**Masalah:** Semua delete adalah hard delete di kedua aplikasi (Flutter & Web).

---

## E. DETAIL PER-MODUL

### E.1 Modul Autentikasi & Manajemen User

| Masalah | Severity | Platform | File |
|---------|----------|----------|------|
| Password plaintext di Firestore | KRITIS | Flutter | `auth_service.dart:87` |
| Password di LocalStorage | KRITIS | Web | `login/page.tsx:48-52` |
| JWT secret fallback hardcoded | KRITIS | Web | `lib/auth.ts:8-10` |
| Password hash dikirim via API | KRITIS | Web | `users/route.ts:23-26` |
| Registrasi dengan role sembarang | TINGGI | Flutter | `auth_service.dart:26-47` |
| App Check debug di production | TINGGI | Flutter | `main.dart:20-23` |
| Role check hanya di UI layer | TINGGI | Flutter | `home_page.dart:73-80` |
| getUsers tanpa filter | TINGGI | Flutter | `firestore_service.dart:118-123` |
| Tidak ada CSRF protection | TINGGI | Web | Semua endpoint |
| Rate limiter hanya di login | TINGGI | Web | `login/route.ts:18` |
| User ID tidak tervalidasi | SEDANG | Flutter | `firestore_service.dart:654-674` |
| Race condition checkSession | SEDANG | Flutter | `auth_provider.dart:18-33` |
| Role hierarchy tidak jelas | SEDANG | Both | `user.dart:80-87` |
| Captcha key hardcoded | RENDAH | Flutter | `main.dart:23` |

### E.2 Modul Organisasi & Member

| Masalah | Severity | Platform | File |
|---------|----------|----------|------|
| No org ownership verification | TINGGI | Flutter | `absensi_page.dart:142-149` |
| isOrganizationAdmin permisif | TINGGI | Flutter | `user.dart:82-84` |
| Batch import tanpa transaksi | TINGGI | Flutter | `import_page.dart:331-366` |
| Tidak ada validasi delete side-effect | SEDANG | Flutter | `firestore_service.dart:176-178` |
| whereIn limit 10 | SEDANG | Flutter | `firestore_service.dart:152` |
| IDOR: admin bisa akses semua org | TINGGI | Web | `organizations/route.ts` |

### E.3 Modul Absensi

| Masalah | Severity | Platform | File |
|---------|----------|----------|------|
| Mass update tanpa validasi anggota | SEDANG | Flutter | `absensi_page.dart:159-178` |
| Error message bocor ke user | SEDANG | Flutter | `absensi_page.dart:155` |
| Unique constraint null duplikat | SEDANG | Web | `schema.prisma:405-406` |
| N+1 query per 30 detik | TINGGI | Flutter | `dashboard_page.dart:98-104` |
| Composite index tidak ada | SEDANG | Flutter | `firestore_service.dart:238-242` |

### E.4 Modul Kas & Keuangan

| Masalah | Severity | Platform | File |
|---------|----------|----------|------|
| Missing update rule di Firestore | KRITIS | Firestore | `firestore.rules:103-113` |
| getCashBalance full scan | TINGGI | Flutter | `firestore_service.dart:313-326` |
| Balance race condition | SEDANG | Flutter | `cash_provider.dart:24-34` |
| Stream subscription leak | SEDANG | Flutter | `cash_provider.dart:93-98` |
| expense_proofs tanpa validasi file | TINGGI | Storage | `storage.rules:39` |

### E.5 Modul Wawancara & Antrian

| Masalah | Severity | Platform | File |
|---------|----------|----------|------|
| Race condition nomor antrian | TINGGI | Web | `antrian/route.ts:153-178` |
| Queue number berdasarkan list lokal | TINGGI | Flutter | `wawancara_page.dart:223` |
| Ekspektasi lokasi GPS tidak divalidasi | SEDANG | Web | `antrian/route.ts:168-172` |
| Chat creation tanpa org-scoping | TINGGI | Firestore | `firestore.rules:139-143` |

### E.6 Modul Dokumentasi

| Masalah | Severity | Platform | File |
|---------|----------|----------|------|
| Validasi URL foto lemah | SEDANG | Web | `create/route.ts:36-41` |
| Validasi file hanya MIME type | SEDANG | Web | `dokumentasi/route.ts:200-204` |
| Admin OSIS/MPK akses semua | TINGGI | Web | `documentation-auth.ts:15-16` |
| Tidak ada cascade delete | SEDANG | Web | `schema.prisma:250` |
| Missing update rule di Firestore | TINGGI | Firestore | `firestore.rules:187-193` |

### E.7 Modul Database (Prisma)

| Masalah | Severity | File |
|---------|----------|------|
| Registration tidak cascade delete | SEDANG | `schema.prisma:185,213` |
| LogAktivitas tidak cascade delete | SEDANG | `schema.prisma:424` |
| Documentation tidak cascade delete | SEDANG | `schema.prisma:250` |
| Absensi unique constraint null | SEDANG | `schema.prisma:405-406` |
| PrismaClient baru setiap request | SEDANG | `absensi/rekap/route.ts:8` |

### E.8 Firebase Infrastructure

| Masalah | Severity | File |
|---------|----------|------|
| Registrasi publik tanpa auth | KRITIS | `firestore.rules:159-163` |
| Missing update rules (4 collections) | TINGGI | `firestore.rules:103-193` |
| Tidak ada field size limits | TINGGI | `firestore.rules` |
| Tidak ada rate limiting | MEDIUM | `firestore.rules` |
| Credential di binary app | KRITIS | `.env` + `pubspec.yaml:66` |
| API key tanpa restriction | KRITIS | `google-services.json` + `firebase_options.dart` |
| Storage expense_proofs tanpa validasi | TINGGI | `storage.rules:39` |
| email_requests/exp_logs open writes | MEDIUM | `firestore.rules:222-231` |

---

## F. REKOMENDASI PRIORITAS

### Segera (1-2 hari):
1. Hapus penyimpanan password plaintext dari Firestore. Gunakan Firebase Authentication.
2. Hapus `.env` dari `pubspec.yaml` assets. Jangan bundle secret di binary app.
3. Set App Check ke production provider (bukan debug).
4. Restrict Firebase API keys di Google Cloud Console.
5. Deploy Firestore security rules yang ketat: tambahkan `allow update` untuk collection yang missing, proteksi `registrations` dengan auth check.
6. Hapus localStorage password storage di web app.
7. Set JWT_SECRET environment variable dan hapus fallback hardcoded.
8. Enkripsi email app password di database.
9. Hapus field `password` dari select query di `users/route.ts`.
10. Proteksi endpoint backup SQL.

### Minggu ini:
1. Implementasi validasi ownership untuk setiap operasi CRUD (cek OrganizationAdmin).
2. Tambahkan CSRF protection untuk semua endpoint.
3. Rate limiting untuk form submissions dan endpoint sensitif.
4. Refactor N+1 queries dengan aggregation/queries denormalized.
5. Tambahkan composite indexes untuk query umum.
6. Implementasi cascade delete di Prisma schema.
7. Validasi file upload dengan magic bytes.

### Bulan ini:
1. Implementasi soft-delete mechanism.
2. Buat permission matrix role yang jelas.
3. Implementasi offline-first dengan local cache.
4. Error handling yang tidak membocorkan stack trace.
5. Pagination untuk daftar user/members.
6. Validasi input komprehensif (sanitasi, format).
7. Revisi regex nama untuk dukung karakter aksen.
8. Normalisasi email di registrasi.

---

*Laporan ini dibuat berdasarkan analisis statis kode sumber. Beberapa kerentanan mungkin memerlukan pengujian dinamis untuk verifikasi lebih lanjut.*
