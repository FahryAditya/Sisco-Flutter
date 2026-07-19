# 🚨 Laporan Bug Kritis --- Firestore Index & Firebase Storage

## Status

**Prioritas: Tinggi**\
**Tujuan: Segera dilakukan perbaikan sebelum aplikasi digunakan secara
luas.**

------------------------------------------------------------------------

## Ringkasan

Ditemukan beberapa error pada aplikasi yang menyebabkan fitur utama
gagal digunakan.

Bug ditemukan pada:

1.  **Persetujuan Pendaftaran**
2.  **Kirim Email**
3.  **Backup Seluruh Data**
4.  **Konsistensi data Firestore dan Firebase Storage**

------------------------------------------------------------------------

# 1. Bug: Firestore Query Membutuhkan Index

## Error

``` text
[cloud_firestore/failed-precondition]
The query requires an index.
```

Firestore memberikan link untuk membuat Composite Index.

## Dampak

Halaman **Persetujuan Pendaftaran** gagal memuat data pendaftaran pada
beberapa organisasi, seperti:

-   Programming
-   OSIS Skarlakes
-   MPK SKARLAKES

Akibatnya, pengguna tidak dapat melihat atau memproses daftar
pendaftaran.

## Penyebab Kemungkinan

Query menggunakan kombinasi beberapa operasi, contohnya:

``` dart
.where('organizationId', isEqualTo: organizationId)
.where('status', isEqualTo: 'pending')
.orderBy('createdAt')
```

Kombinasi filter dan sorting tertentu membutuhkan **Composite Index** di
Firestore.

## Perbaikan

### Solusi cepat

1.  Buka link index yang diberikan pada error.
2.  Login ke Firebase Console.
3.  Klik **Create Index**.
4.  Tunggu hingga status index menjadi aktif.
5.  Uji kembali halaman Persetujuan Pendaftaran.

### Solusi jangka panjang

Audit seluruh query Firestore yang menggunakan:

-   lebih dari satu `.where()`
-   `.where()` + `.orderBy()`
-   filter pada beberapa field
-   query yang sama untuk organisasi berbeda

Pastikan index yang dibutuhkan sudah tersedia.

------------------------------------------------------------------------

# 2. Bug: Firebase Storage Object Not Found

## Error

``` text
[firebase_storage/object-not-found]
No object exists at the desired reference.
```

Error ditemukan pada:

-   fitur **Kirim Email**
-   fitur **Backup Seluruh Data**

## Penyebab

Aplikasi mencoba mengakses file di Firebase Storage menggunakan path
tertentu, tetapi file tersebut tidak ditemukan.

Kemungkinan penyebab:

-   File belum pernah di-upload.
-   File sudah dihapus.
-   Path file berubah.
-   Data Firestore masih menyimpan referensi file lama.
-   URL atau path foto sudah tidak valid.
-   Referensi Storage tidak sesuai dengan lokasi file sebenarnya.

------------------------------------------------------------------------

# 3. Bug Kritis pada Backup Data

## Masalah

Fitur **Backup Seluruh Data** gagal apabila salah satu file yang
direferensikan tidak ditemukan.

Contoh alur yang bermasalah:

``` text
Ambil semua data anggota
        ↓
Ambil URL/foto anggota
        ↓
Satu file foto tidak ditemukan
        ↓
getDownloadURL() gagal
        ↓
Seluruh proses backup gagal ❌
```

## Perilaku yang Seharusnya

Satu file yang hilang tidak boleh menggagalkan seluruh backup.

``` text
Ambil semua data anggota
        ↓
Cek foto setiap anggota
        ↓
Foto tersedia?
   ├── Ya → ambil URL
   └── Tidak → photoUrl = null
        ↓
Lanjutkan proses backup
        ↓
Backup tetap berhasil ✅
```

## Contoh Penanganan Error

``` dart
String? photoUrl;

try {
  photoUrl = await storageRef.getDownloadURL();
} on FirebaseException catch (e) {
  if (e.code == 'object-not-found') {
    photoUrl = null;
  } else {
    rethrow;
  }
}
```

Kemudian data tetap dimasukkan ke backup:

``` json
{
  "name": "Nama Siswa",
  "photoUrl": null
}
```

------------------------------------------------------------------------

# 4. Sistem Backup Harus Tahan terhadap Data Tidak Lengkap

Semua data yang berasal dari Firebase Storage harus dianggap sebagai
data yang bisa hilang.

Contoh:

-   Foto anggota
-   Foto profil
-   Logo organisasi
-   Dokumen
-   File lampiran
-   File ekspor/import

Jangan menganggap semua file yang memiliki path di Firestore pasti masih
tersedia di Storage.

## Prinsip yang Harus Digunakan

> **Firestore menyimpan metadata/referensi. Firebase Storage menyimpan
> file fisik. Keduanya harus dianggap dapat tidak sinkron.**

Oleh karena itu:

``` text
Firestore Reference
        ↓
Validasi file di Storage
        ↓
File tersedia?
   ├── Ya → gunakan file
   └── Tidak → catat sebagai missing/null
```

------------------------------------------------------------------------

# 5. Perbaikan Fitur Kirim Email

Fitur **Kirim Email** juga gagal karena kemungkinan mengambil file atau
URL dari Firebase Storage yang sudah tidak tersedia.

## Perbaikan yang Disarankan

Sebelum menggunakan file:

``` dart
try {
  final url = await storageRef.getDownloadURL();

  // Lanjutkan proses email
} on FirebaseException catch (e) {
  if (e.code == 'object-not-found') {
    // File tidak ditemukan
    // Tampilkan peringatan atau lanjutkan tanpa file
  } else {
    rethrow;
  }
}
```

Jika file bersifat opsional:

``` text
File tersedia → lampirkan file
File tidak tersedia → kirim email tanpa file
```

Jika file wajib:

``` text
File tidak tersedia
        ↓
Batalkan proses
        ↓
Tampilkan pesan yang jelas kepada administrator
```

------------------------------------------------------------------------

# 6. Rekomendasi Sistem Error Handling

Jangan menampilkan error mentah Firebase langsung kepada pengguna.

Saat ini:

``` text
Gagal memuat pendaftaran:
[cloud_firestore/failed-precondition] The query requires an index.
```

Lebih baik:

``` text
Gagal memuat pendaftaran

Sistem membutuhkan konfigurasi database tambahan.
Silakan hubungi administrator sistem.
```

Untuk administrator/developer, error teknis tetap dicatat di log:

``` dart
debugPrint('Firestore Error: ${e.code}');
debugPrint('Message: ${e.message}');
```

## Prinsip

``` text
User biasa
    ↓
Pesan sederhana dan mudah dipahami

Developer/Admin
    ↓
Error teknis lengkap + log
```

------------------------------------------------------------------------

# 7. Checklist Perbaikan

## Firestore

-   [ ] Buat Composite Index yang diminta oleh Firestore.
-   [ ] Uji halaman Persetujuan Pendaftaran.
-   [ ] Uji semua organisasi.
-   [ ] Uji dengan data kosong.
-   [ ] Uji dengan banyak data.
-   [ ] Audit query lain yang membutuhkan index.

## Firebase Storage

-   [ ] Cari semua path file yang sudah tidak valid.
-   [ ] Cek data Firestore yang masih menyimpan referensi file lama.
-   [ ] Tangani error `object-not-found`.
-   [ ] Jangan biarkan satu file hilang menggagalkan seluruh proses
    backup.
-   [ ] Tambahkan validasi file sebelum digunakan.

## Backup

-   [ ] Backup tetap berjalan jika foto tidak ditemukan.
-   [ ] Gunakan `null` atau status `missing` untuk file yang hilang.
-   [ ] Catat file yang gagal di log.
-   [ ] Tampilkan ringkasan hasil backup.
-   [ ] Pastikan data utama tetap berhasil disimpan.

Contoh:

``` json
{
  "backupStatus": "success",
  "missingFiles": [
    "foto/anggota_123.jpg"
  ],
  "totalData": 150,
  "totalMissingFiles": 1
}
```

## Kirim Email

-   [ ] Validasi file sebelum mengambil URL.
-   [ ] Tangani file yang tidak ditemukan.
-   [ ] Tentukan apakah file wajib atau opsional.
-   [ ] Jangan membuat seluruh proses gagal jika attachment opsional
    hilang.

------------------------------------------------------------------------

# Prioritas Perbaikan

## 🔴 PRIORITAS 1 --- Segera

1.  Buat Firestore Composite Index.
2.  Perbaiki error `object-not-found` pada backup.
3.  Pastikan backup tidak gagal total hanya karena satu file hilang.

## 🟠 PRIORITAS 2

4.  Perbaiki fitur Kirim Email.
5.  Audit seluruh referensi Firebase Storage.
6.  Bersihkan path file yang sudah tidak valid.

## 🟡 PRIORITAS 3

7.  Perbaiki tampilan error kepada pengguna.
8.  Tambahkan logging.
9.  Tambahkan sistem validasi dan recovery.

------------------------------------------------------------------------

# Kesimpulan

Bug utama bukan hanya masalah index atau file yang hilang.

Masalah yang lebih besar adalah **ketergantungan penuh aplikasi terhadap
data eksternal tanpa fallback**.

Sistem harus dirancang dengan asumsi bahwa:

-   Query bisa membutuhkan index.
-   File Storage bisa hilang.
-   URL bisa tidak valid.
-   Firestore dan Storage bisa tidak sinkron.
-   Data bisa tidak lengkap.

### Target sistem setelah perbaikan

``` text
Query membutuhkan index
        ↓
Ditangani dengan konfigurasi index

File Storage hilang
        ↓
Ditangani dengan fallback

Satu data rusak
        ↓
Tidak menggagalkan seluruh proses

Backup
        ↓
Tetap menghasilkan data yang dapat dipulihkan
```

**Perbaikan utama yang harus dilakukan terlebih dahulu adalah membuat
Firebase Storage dan sistem backup lebih toleran terhadap file yang
hilang.**
