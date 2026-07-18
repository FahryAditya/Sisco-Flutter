
> Flutter = Admin Dashboard
QR Code = Pintu Masuk Peserta
HTML + CSS + JavaScript = Web Peserta
Firestore = Database dan Sinkronisasi Real-Time



# AIRLANGGA QR QUEST

Anda adalah Senior Flutter Developer, Web Developer, Firebase Engineer, UI/UX Designer, dan System Architect.

Saya ingin membangun sebuah sistem bernama:

AIRLANGGA QR QUEST

Sistem ini digunakan untuk kegiatan LDK OSIS & MPK 2026/2027.

---

# KONSEP UTAMA

Airlangga QR QUEST adalah sistem quest digital berbasis QR Code.

Peserta tidak perlu menginstal aplikasi.

Peserta cukup:

1. Mendapatkan QR Code.
2. Memindai QR Code menggunakan kamera HP.
3. Masuk ke Web Quest.
4. Membaca soal atau tantangan.
5. Mengirim jawaban.
6. Mendapatkan skor.

Admin dan panitia menggunakan aplikasi Flutter untuk mengontrol seluruh sistem.

---

# ARSITEKTUR SISTEM

```text
                    👨‍💻 ADMIN / PANITIA
                           │
                           ▼
                  📱 FLUTTER ADMIN APP
                  ADMIN DASHBOARD
                           │
                           │ Firebase SDK
                           ▼
                    🔥 FIRESTORE
                    DATABASE UTAMA
                           ▲
                           │ Firebase SDK
                           │
                           ▼
                🌐 WEB QUEST PESERTA
                  HTML + CSS + JS
                           ▲
                           │
                       📷 SCAN QR
                           │
                        PESERTA


---

TEKNOLOGI

Admin Application

Gunakan:

Flutter

Dart

Firebase SDK

Cloud Firestore

Firebase Authentication jika diperlukan


Web Peserta

Gunakan:

HTML

CSS

JavaScript

Firebase Web SDK

Cloud Firestore


Database

Gunakan:

Firebase Firestore


Jangan menggunakan Prisma atau Neon sebagai database utama.

Firestore digunakan agar Flutter dan Web dapat menggunakan database yang sama dan dapat melakukan sinkronisasi data secara real-time.


---

1. FLUTTER ADMIN DASHBOARD

Flutter hanya digunakan oleh Admin dan Panitia.

Flutter bukan aplikasi utama peserta.

Fitur Admin Dashboard

Admin dapat:

Melihat status kegiatan.

Mengelola soal aktif.

Membuat soal.

Mengedit soal.

Menghapus soal.

Menandai soal sebagai bocor.

Mengganti soal bocor.

Mengelola soal cadangan.

Melihat peserta.

Melihat jawaban peserta.

Melihat skor.

Melihat leaderboard.

Melihat activity log.



---

2. QR CODE

Terdapat 10 QR Code utama:

SL01
SL02
SL03
SL04
SL05
SL06
SL07
SL08
SL09
SL10

SL berarti:

SL = Soal LDK

Setiap QR Code memiliki identitas permanen.

Contoh:

SL08

QR Code SL08 tidak boleh berubah.

QR Code berfungsi sebagai pintu masuk menuju soal tertentu.


---

3. ALUR PESERTA

Alur peserta:

Peserta mendapatkan QR Code
        ↓
Scan QR Code menggunakan kamera HP
        ↓
Browser terbuka
        ↓
Web Quest terbuka
        ↓
JavaScript membaca kode soal
        ↓
Web mengambil data dari Firestore
        ↓
Soal ditampilkan
        ↓
Peserta menjawab
        ↓
Jawaban dikirim ke Firestore
        ↓
Sistem memproses jawaban
        ↓
Skor diperbarui

Contoh:

Scan QR SL08
        ↓
Web membuka halaman SL08
        ↓
JavaScript membaca kode:
SL08
        ↓
Firestore mencari soal dengan kode:
SL08
        ↓
Soal SL08 ditampilkan


---

4. WEB PESERTA

Web peserta harus:

Dibuat menggunakan HTML.

Dibuat menggunakan CSS.

Dibuat menggunakan JavaScript.

Mobile-first.

Responsive.

Ringan.

Cepat dibuka setelah QR Code dipindai.

Tidak membutuhkan instalasi aplikasi.

Tidak membutuhkan login rumit jika sistem identitas peserta menggunakan kode unik.


Halaman Web

Contoh:

/quest/SL01
/quest/SL02
/quest/SL03
/quest/SL04
/quest/SL05
/quest/SL06
/quest/SL07
/quest/SL08
/quest/SL09
/quest/SL10

Web menampilkan:

Logo Airlangga QR QUEST.

Kode soal.

Pertanyaan.

Input jawaban.

Tombol kirim.

Status pengiriman.

Feedback berhasil atau gagal.



---

5. SISTEM SOAL

Terdapat dua jenis soal.

SOAL AKTIF

SL01
SL02
SL03
SL04
SL05
SL06
SL07
SL08
SL09
SL10

SOAL CADANGAN

SB01
SB02
SB03
SB04
SB05
...

SB berarti:

SB = Soal Backup

Soal cadangan digunakan apabila soal aktif:

Bocor.

Rusak.

Tidak dapat digunakan.

Perlu diganti oleh admin.



---

6. SISTEM PERGANTIAN SOAL

QR Code harus tetap sama walaupun isi soal berubah.

Contoh awal:

SL08
↓
Soal A

Kemudian soal SL08 bocor.

Admin membuka Flutter:

Flutter Admin
      ↓
Pilih SL08
      ↓
Tandai sebagai BOCOR
      ↓
Pilih soal cadangan
      ↓
Pilih SB04

Sistem kemudian:

SL08
↓
Soal B

QR Code tetap:

SL08

Peserta berikutnya:

Scan QR SL08
      ↓
Web Quest SL08
      ↓
Firestore
      ↓
Soal B ditampilkan


---

7. PERUBAHAN SOAL HARUS INDEPENDEN

Jika hanya SL08 yang bocor:

SL01 → Tidak berubah
SL02 → Tidak berubah
SL03 → Tidak berubah
SL04 → Tidak berubah
SL05 → Tidak berubah
SL06 → Tidak berubah
SL07 → Tidak berubah
SL08 → Diganti
SL09 → Tidak berubah
SL10 → Tidak berubah

Jika SL06, SL07, dan SL08 bocor:

SL06 → Diganti secara independen
SL07 → Diganti secara independen
SL08 → Diganti secara independen

PENTING:

Jangan mengubah soal lain secara otomatis.

Setiap kode soal harus memiliki data dan statusnya sendiri.


---

8. VERSION HISTORY

Setiap perubahan soal harus memiliki riwayat.

Contoh:

SL08

Versi 1
Soal Awal

Versi 2
Soal Pengganti

Versi 3
Soal Terbaru

Simpan:

Isi soal lama.

Isi soal baru.

Waktu perubahan.

Admin yang melakukan perubahan.

Alasan perubahan.

Nomor versi.



---

9. SISTEM JAWABAN

Saat peserta mengirim jawaban:

Web Peserta
      ↓
JavaScript
      ↓
Firebase Firestore
      ↓
Validasi
      ↓
Jawaban disimpan
      ↓
Skor diperbarui

Sistem harus mencatat:

ID peserta.

Kode kelompok jika digunakan.

Kode soal.

Jawaban peserta.

Waktu menjawab.

Status jawaban.

Skor.



---

10. IDENTITAS PESERTA

Sistem harus menentukan cara peserta dikenali.

Gunakan salah satu metode:

Kode Peserta

Contoh:

P001
P002
P003

atau:

Kode Kelompok

Contoh:

GARUDA
ELANG
RAJAWALI

atau:

Token Unik

Gunakan token unik untuk setiap peserta atau kelompok.

PENTING:

Jangan mempercayai ID peserta dari URL tanpa validasi.

Validasi identitas harus dilakukan sebelum peserta dapat mengirim jawaban.


---

11. STRUKTUR FIRESTORE

Gunakan struktur database yang terorganisasi.

Contoh:

firestore
│
├── questions
│   ├── SL01
│   ├── SL02
│   ├── SL03
│   ├── SL04
│   ├── SL05
│   ├── SL06
│   ├── SL07
│   ├── SL08
│   ├── SL09
│   └── SL10
│
├── backup_questions
│   ├── SB01
│   ├── SB02
│   ├── SB03
│   └── SB04
│
├── participants
│
├── groups
│
├── answers
│
├── scores
│
├── leaderboard
│
└── activity_logs

Contoh data soal:

{
  "code": "SL08",
  "question": "Apa arti kepemimpinan?",
  "status": "active",
  "version": 1,
  "updatedAt": "timestamp"
}


---

12. ADMIN DASHBOARD FLUTTER

Dashboard

Tampilkan:

Total peserta.

Total kelompok.

Total soal aktif.

Total soal cadangan.

Total jawaban.

Total skor.

Status kegiatan.


Manajemen Soal

Admin dapat:

Melihat SL01 sampai SL10.

Melihat status soal.

Mengedit soal.

Menandai soal sebagai bocor.

Mengganti soal.

Melihat history soal.


Status soal:

ACTIVE
LEAKED
REPLACED
INACTIVE

Soal Cadangan

Admin dapat:

Membuat soal cadangan.

Mengedit soal cadangan.

Menghapus soal cadangan.

Menggunakan soal cadangan untuk mengganti soal aktif.


Peserta

Admin dapat melihat:

Nama.

Kelas.

Kelompok.

Progress.

Jumlah jawaban.

Total skor.


Leaderboard

Leaderboard dapat menampilkan:

Individu

1. Peserta A
2. Peserta B
3. Peserta C

Kelompok

1. Garuda
2. Elang
3. Rajawali

Activity Log

Catat aktivitas penting:

Admin mengganti SL08
Admin mengedit SL03
Peserta membuka SL01
Peserta mengirim jawaban SL01


---

13. FIRESTORE REAL-TIME SYNCHRONIZATION

Flutter dan Web harus menggunakan Firestore sebagai sumber data yang sama.

Contoh:

📱 Flutter Admin
      │
      │ Update Data
      ▼
🔥 Firestore
      │
      │ Data Terbaru
      ▼
🌐 Web Peserta

Contoh:

SL08
↓
Soal Lama

Admin mengubah melalui Flutter:

SL08
↓
Soal Baru

Web peserta yang mengambil data terbaru akan mendapatkan:

Soal Baru

QR Code tidak perlu dicetak ulang.


---

14. KEAMANAN FIRESTORE

Buat Firestore Security Rules yang aman.

Admin:

Dapat membaca data admin.

Dapat mengubah soal.

Dapat mengelola peserta.

Dapat melihat jawaban.


Peserta:

Hanya dapat membaca data soal yang diperlukan.

Dapat mengirim jawaban sesuai aturan.

Tidak dapat mengubah soal.

Tidak dapat membaca jawaban peserta lain.

Tidak dapat membaca jawaban benar secara langsung.

Tidak dapat mengakses data admin.


Validasi penting harus dilakukan dengan aman.

Jangan menaruh jawaban benar secara terbuka di frontend jika hal tersebut dapat menyebabkan peserta melihat jawaban.


---

15. UI/UX

Flutter Admin

Gunakan desain:

Modern.

Profesional.

Clean.

Futuristic.

Mudah digunakan.

Cocok untuk panitia siswa.

Dashboard informatif.


Web Peserta

Gunakan desain:

Mobile-first.

Sederhana.

Cepat.

Modern.

Mudah dipahami.

Tidak terlalu banyak elemen.


Prioritaskan:

Loading state.

Error state.

Success state.

Empty state.

Network error state.



---

16. ARSITEKTUR FINAL

┌────────────────────────────┐
│     📱 FLUTTER APP         │
│     ADMIN DASHBOARD        │
└──────────────┬─────────────┘
               │
               │ Firebase SDK
               ▼
┌────────────────────────────┐
│      🔥 FIRESTORE          │
│      DATABASE UTAMA        │
└──────────────┬─────────────┘
               ▲
               │ Firebase Web SDK
               │
┌──────────────┴─────────────┐
│      🌐 WEB PESERTA        │
│    HTML + CSS + JAVASCRIPT │
└──────────────▲─────────────┘
               │
               │
          📷 SCAN QR
               │
               ▼
            PESERTA


---

URUTAN PEMBANGUNAN

Bangun sistem secara bertahap.

FASE 1

Tentukan struktur Firestore.

FASE 2

Buat Firebase Project.

FASE 3

Buat sistem autentikasi Admin Flutter.

FASE 4

Buat Flutter Admin Dashboard.

FASE 5

Buat sistem CRUD soal.

FASE 6

Buat Web Peserta HTML + CSS + JavaScript.

FASE 7

Hubungkan Web Peserta dengan Firestore.

FASE 8

Buat sistem QR Code.

FASE 9

Buat sistem jawaban.

FASE 10

Buat sistem skor.

FASE 11

Buat sistem pergantian soal bocor.

FASE 12

Buat Version History.

FASE 13

Buat Leaderboard.

FASE 14

Buat Activity Log.

FASE 15

Buat Firestore Security Rules.

FASE 16

Lakukan testing.

Testing minimal:

Scan QR SL01.

Scan QR SL08.

Mengirim jawaban.

Mengganti soal SL08.

Memastikan QR SL08 tetap sama.

Memastikan SL01 sampai SL07 dan SL09 sampai SL10 tidak berubah.

Mengganti beberapa soal secara bersamaan.

Menguji 30 peserta secara bersamaan.

Menguji koneksi lambat.

Menguji keamanan Firestore.



---

ATURAN UTAMA SISTEM

1. Flutter digunakan untuk Admin Dashboard.


2. Peserta tidak perlu menggunakan aplikasi Flutter.


3. Peserta cukup scan QR Code.


4. Web peserta dibuat menggunakan HTML, CSS, dan JavaScript.


5. Firestore menjadi database utama.


6. Flutter dan Web menggunakan Firestore yang sama.


7. QR Code bersifat permanen.


8. Isi soal dapat diganti tanpa mencetak QR baru.


9. Setiap soal dapat diganti secara independen.


10. Jika SL08 bocor, hanya SL08 yang berubah.


11. Riwayat perubahan soal harus disimpan.


12. Admin memiliki kontrol penuh melalui Flutter.


13. Peserta hanya dapat mengakses fitur yang diperlukan.


14. Keamanan Firestore harus menjadi prioritas.



Sebelum menulis kode, jelaskan terlebih dahulu:

1. Arsitektur sistem.


2. Struktur Firestore.


3. Struktur data setiap collection.


4. Alur Flutter Admin ke Firestore.


5. Alur Web Peserta ke Firestore.


6. Alur QR Code.


7. Alur pergantian soal.


8. Sistem Version History.


9. Firestore Security Rules.


10. Struktur folder project.



Jangan langsung membuat seluruh sistem sekaligus.

Mulai dari perencanaan arsitektur dan database terlebih dahulu.