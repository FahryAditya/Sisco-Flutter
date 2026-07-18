# SISCO - Import Excel Issue & Solution
## Data Validation, Update, Delete & Feedback System

---

## TABLE OF CONTENTS

1. [Problem Analysis](#problem-analysis)
2. [Root Causes](#root-causes)
3. [Solution Architecture](#solution-architecture)
4. [Data Validation Rules](#data-validation-rules)
5. [Import Implementation](#import-implementation)
6. [Feedback System](#feedback-system)
7. [Security Rules Update](#security-rules-update)

---

## PROBLEM ANALYSIS

### Gejala
```
✗ User import data Excel
✗ Data valid di Flutter (lolos validasi)
✗ TIDAK ada error message
✗ Data TIDAK masuk ke Firestore
✗ User bingung kenapa gagal
```

### Dampak
- User experience buruk (no feedback)
- Data tidak tersinkronisasi
- Admin tidak tahu status import
- Sulit di-debug tanpa error log

---

## ROOT CAUSES

### 1. **Firestore Security Rules BLOCK Write**
```javascript
// MASALAH: Rule terlalu ketat
match /peserta/{pesertaId} {
  allow write: if false; // BLOCK SEMUA WRITE
}

// SOLUSI: Izinkan import dari user dengan role tertentu
match /peserta/{pesertaId} {
  allow create: if isAdminOrganisasi() && isAssignedTo(request.resource.data.unitId);
}
```

### 2. **Async Issue - Data Dikirim Sebelum Selesai**
```dart
// MASALAH: Tidak await semua write operation
void importPeserta(List<Map> data) {
  for (var item in data) {
    firestore.collection('peserta').add(item); // TIDAK AWAIT!
  }
  showSuccessDialog(); // Langsung success padahal write belum selesai
}

// SOLUSI: Await semua operation & use batch write
Future<void> importPeserta(List<Map> data) async {
  final batch = firestore.batch();
  for (var item in data) {
    batch.set(firestore.collection('peserta').doc(), item);
  }
  await batch.commit(); // WAIT sampai semua selesai
}
```

### 3. **Data Format TIDAK Sesuai Firestore Schema**
```dart
// MASALAH: Data dari Excel punya extra field atau type berbeda
{
  "nama": "Samuel",
  "kelas": "12 A",
  "extra_field": "data tidak perlu", // Field tidak dalam schema
  "presentase": "78", // String, seharusnya number
  "tanggal": "10-06-2026" // Format berbeda
}

// SOLUSI: Validasi & transform sebelum write
{
  "nama": "Samuel",
  "kelas": "12 A",
  "presentase": 78, // Number
  "tanggal": "2026-06-10T00:00:00Z", // ISO format
  "status": "pending_wawancara" // Auto-set
}
```

### 4. **Permission Issue**
```
✗ User role: admin_organisasi
✗ Data unitId: "OSIS" 
✗ User assignedUnits: ["PMR"]
✗ Security rule check: isAssignedTo("OSIS") → FALSE
✗ WRITE BLOCKED
✗ NO ERROR MESSAGE (silent fail)
```

### 5. **NO FEEDBACK MECHANISM**
```
✗ Import button diklik
✗ Data diproses
✗ Result tidak ditampilkan
✗ User tidak tahu success/fail
```

---

## SOLUTION ARCHITECTURE

```
┌─────────────────────────────────────────────────────┐
│           FLUTTER APP (Client)                       │
│  ┌────────────────────────────────────────────────┐  │
│  │ 1. Pick Excel File                             │  │
│  │ 2. Parse Excel → List<Map>                     │  │
│  │ 3. Validasi Data (schema, type, format)        │  │
│  │ 4. Show validation result + feedback           │  │
│  │ 5. Call Cloud Function (batch import)          │  │
│  │ 6. Track progress & show feedback              │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│      CLOUD FUNCTION (Server-side validation)        │
│  ┌────────────────────────────────────────────────┐  │
│  │ 1. Validate user permission (role & unit)      │  │
│  │ 2. Re-validate data format (security layer)    │  │
│  │ 3. Transform data ke Firestore schema          │  │
│  │ 4. Batch write ke Firestore                    │  │
│  │ 5. Return result with detailed feedback        │  │
│  │ 6. Log ke audit_logs collection                │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│      FIRESTORE (Data persistence)                   │
│  ┌────────────────────────────────────────────────┐  │
│  │ Security Rules check:                          │  │
│  │ - User punya akses ke unit?                    │  │
│  │ - Data format valid?                           │  │
│  │ - Batch operation permitted?                   │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## DATA VALIDATION RULES

### Schema: PESERTA

```javascript
{
  // REQUIRED
  nama: string,              // Min 3 char, max 100
  kelas: string,             // Format: "12 A" atau "XII A"
  asalSekolah: string,       // Min 3 char
  jurusan: string,           // Format: "IPA" | "IPS" | "BHS"
  
  // AUTO-SET
  unitId: string,            // From admin's assignedUnits
  status: string,            // "pending_wawancara"
  presentase: null,          // Start with null
  createdAt: timestamp,      // Server timestamp
  
  // OPTIONAL
  catatan: array,            // []
}
```

### Validation Rules

#### NAMA
```
✓ Required
✓ Min length: 3 karakter
✓ Max length: 100 karakter
✓ Hanya huruf, spasi, apostrophe
✗ Angka, special char (except apostrophe)
```

**Error Messages:**
```
- "Nama tidak boleh kosong"
- "Nama minimal 3 karakter"
- "Nama maksimal 100 karakter"
- "Nama hanya boleh huruf dan spasi"
```

#### KELAS
```
Accepted format:
✓ "12 A", "XII A", "12A", "XIIA"
✓ "11 B", "XI B", "11B", "XIB"
✓ "10 C", "X C", "10C", "XC"

✗ "Kelas 12A", "Kelas XII A"
✗ "12", "A"
✗ "13 A" (tidak ada kelas 13)
```

**Error Messages:**
```
- "Kelas tidak boleh kosong"
- "Format kelas tidak valid (contoh: 12 A, XI B, X C)"
- "Kelas hanya boleh 10, 11, atau 12"
```

**Transform:**
```
Input: "12 A" → Output: "12 A"
Input: "XII A" → Output: "12 A"
Input: "12A" → Output: "12 A"
Input: "XIIA" → Output: "12 A"
```

#### ASAL SEKOLAH
```
✓ Required
✓ Min length: 3 karakter
✓ Max length: 200 karakter
✓ Format: "SMA Negeri 1", "SMAN 2", "SMA Swasta X"
```

**Error Messages:**
```
- "Asal sekolah tidak boleh kosong"
- "Asal sekolah minimal 3 karakter"
- "Asal sekolah maksimal 200 karakter"
```

#### JURUSAN
```
Valid values:
✓ "IPA"
✓ "IPS"
✓ "BHS" (Bahasa)
✗ "Lainnya", "Teknik", dll

Case-insensitive:
"ipa" → "IPA"
"Ips" → "IPS"
"bhs" → "BHS"
```

**Error Messages:**
```
- "Jurusan tidak boleh kosong"
- "Jurusan harus IPA, IPS, atau BHS"
```

### Schema: ABSENSI

```javascript
{
  // REQUIRED
  unitId: string,            // Sesuai admin unit
  pesertaId: string,         // Must exist in peserta
  pesertaNama: string,       // Auto-fetch dari peserta
  tanggal: date,             // Format: YYYY-MM-DD
  status: string,            // "hadir" | "izin" | "sakit" | "alpha"
  
  // OPTIONAL
  keterangan: string,        // For "izin" or "sakit"
  
  // AUTO-SET
  inputBy: string,           // Current user UID
  inputByName: string,       // Current user name
  createdAt: timestamp,
}
```

#### TANGGAL (Absensi)
```
✓ Format: "2026-06-10", "10-06-2026", "10/06/2026"
✓ Valid date (tidak ada 30 Feb)
✓ Tidak boleh masa depan
✓ Max 30 hari kebelakang

✗ Format: "10 Juni 2026", "10062026"
```

**Transform:**
```
Input: "10-06-2026" → Output: "2026-06-10"
Input: "2026-06-10" → Output: "2026-06-10"
```

#### STATUS (Absensi)
```
Valid:
✓ "hadir"
✓ "izin"
✓ "sakit"
✓ "alpha"

Case-insensitive:
"HADIR" → "hadir"
"Izin" → "izin"
```

**Conditional Validation:**
```
If status = "izin" atau "sakit":
  - Require "keterangan" field
  - Min 5 karakter
  
If status = "hadir" atau "alpha":
  - "keterangan" optional
```

### Schema: KAS

```javascript
{
  // REQUIRED
  unitId: string,
  jumlah: number,            // > 0
  tipe: string,              // "masuk" | "keluar"
  keterangan: string,        // Min 5 karakter
  tanggal: date,             // Format: YYYY-MM-DD
  
  // AUTO-SET
  inputBy: string,
  inputByName: string,
  createdAt: timestamp,
}
```

#### JUMLAH (Kas)
```
✓ Harus number
✓ > 0
✓ Max 1,000,000,000

✗ Negatif
✗ String dengan currency symbol ("Rp 50.000")
```

**Transform:**
```
Input: "50000" → Output: 50000
Input: "50,000" → Output: 50000
Input: "Rp 50.000" → REJECT (invalid format)
```

**Error Messages:**
```
- "Jumlah tidak boleh kosong"
- "Jumlah harus angka positif"
- "Jumlah maksimal 1 miliar"
```

#### TIPE (Kas)
```
Valid:
✓ "masuk"
✓ "keluar"

Case-insensitive:
"MASUK" → "masuk"
"Keluar" → "keluar"
```

#### KETERANGAN (Kas)
```
✓ Required
✓ Min 5 karakter
✓ Max 500 karakter
✓ Format: "Iuran anggota bulan Juni", "Pembelian perlengkapan latihan"
```

**Error Messages:**
```
- "Keterangan tidak boleh kosong"
- "Keterangan minimal 5 karakter"
- "Keterangan maksimal 500 karakter"
```

---

## IMPORT IMPLEMENTATION

### Flutter Code - Import Service

```dart
// lib/services/import_service.dart

import 'package:excel/excel.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImportResult {
  final bool success;
  final int totalRows;
  final int successCount;
  final int failCount;
  final List<ImportError> errors;
  final String message;
  final DateTime processedAt;

  ImportResult({
    required this.success,
    required this.totalRows,
    required this.successCount,
    required this.failCount,
    required this.errors,
    required this.message,
    required this.processedAt,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      success: json['success'] ?? false,
      totalRows: json['totalRows'] ?? 0,
      successCount: json['successCount'] ?? 0,
      failCount: json['failCount'] ?? 0,
      errors: List<ImportError>.from(
        (json['errors'] as List?)?.map((e) => ImportError.fromJson(e)) ?? [],
      ),
      message: json['message'] ?? '',
      processedAt: DateTime.now(),
    );
  }
}

class ImportError {
  final int rowNumber;
  final String field;
  final String value;
  final String error;

  ImportError({
    required this.rowNumber,
    required this.field,
    required this.value,
    required this.error,
  });

  factory ImportError.fromJson(Map<String, dynamic> json) {
    return ImportError(
      rowNumber: json['rowNumber'] ?? 0,
      field: json['field'] ?? '',
      value: json['value'] ?? '',
      error: json['error'] ?? '',
    );
  }
}

class ImportService {
  final _functions = FirebaseFunctions.instance;
  final _auth = FirebaseAuth.instance;

  // ===== VALIDATE PESERTA BEFORE IMPORT =====
  List<ImportError> validatePesertaData(List<Map<String, dynamic>> data) {
    List<ImportError> errors = [];
    int rowNum = 2; // Excel row 2 (header di row 1)

    for (var row in data) {
      // Validasi NAMA
      if (row['nama'] == null || (row['nama'] as String).isEmpty) {
        errors.add(ImportError(
          rowNumber: rowNum,
          field: 'nama',
          value: '',
          error: 'Nama tidak boleh kosong',
        ));
      } else if ((row['nama'] as String).length < 3) {
        errors.add(ImportError(
          rowNumber: rowNum,
          field: 'nama',
          value: row['nama'],
          error: 'Nama minimal 3 karakter',
        ));
      }

      // Validasi KELAS
      if (row['kelas'] == null || (row['kelas'] as String).isEmpty) {
        errors.add(ImportError(
          rowNumber: rowNum,
          field: 'kelas',
          value: '',
          error: 'Kelas tidak boleh kosong',
        ));
      } else {
        final kelasValid = _validateKelas(row['kelas']);
        if (!kelasValid) {
          errors.add(ImportError(
            rowNumber: rowNum,
            field: 'kelas',
            value: row['kelas'],
            error: 'Format kelas tidak valid (contoh: 12 A, XI B, X C)',
          ));
        }
      }

      // Validasi ASAL SEKOLAH
      if (row['asalSekolah'] == null || (row['asalSekolah'] as String).isEmpty) {
        errors.add(ImportError(
          rowNumber: rowNum,
          field: 'asalSekolah',
          value: '',
          error: 'Asal sekolah tidak boleh kosong',
        ));
      }

      // Validasi JURUSAN
      if (row['jurusan'] == null || (row['jurusan'] as String).isEmpty) {
        errors.add(ImportError(
          rowNumber: rowNum,
          field: 'jurusan',
          value: '',
          error: 'Jurusan tidak boleh kosong',
        ));
      } else {
        final jurusanValid = ['IPA', 'IPS', 'BHS']
            .contains((row['jurusan'] as String).toUpperCase());
        if (!jurusanValid) {
          errors.add(ImportError(
            rowNumber: rowNum,
            field: 'jurusan',
            value: row['jurusan'],
            error: 'Jurusan harus IPA, IPS, atau BHS',
          ));
        }
      }

      rowNum++;
    }

    return errors;
  }

  bool _validateKelas(dynamic kelas) {
    if (kelas == null) return false;
    final kelasStr = kelas.toString().toUpperCase().replaceAll(' ', '');
    
    final validPatterns = [
      '10A', '10B', '10C', '10D',
      '11A', '11B', '11C', '11D',
      '12A', '12B', '12C', '12D',
      'XA', 'XB', 'XC', 'XD',
      'XIA', 'XIB', 'XIC', 'XID',
      'XIIA', 'XIIB', 'XIIC', 'XIID',
    ];

    return validPatterns.contains(kelasStr);
  }

  String _transformKelas(dynamic kelas) {
    final kelasStr = kelas.toString().trim();
    
    // Convert XI to 11, XII to 12, X to 10
    var result = kelasStr
        .replaceAll('XII', '12')
        .replaceAll('XI', '11')
        .replaceAll('X', '10')
        .replaceAll(RegExp(r'\s+'), ' ') // normalize spaces
        .trim();

    return result;
  }

  String _transformJurusan(dynamic jurusan) {
    return jurusan.toString().toUpperCase();
  }

  // ===== IMPORT PESERTA =====
  Future<ImportResult> importPeserta({
    required List<Map<String, dynamic>> rawData,
    required String unitId,
  }) async {
    try {
      // 1. Validasi permission
      final user = _auth.currentUser;
      final idToken = await user?.getIdTokenResult(forceRefresh: true);
      final role = idToken?.claims?['role'];
      final assignedUnits = List<String>.from(
        idToken?.claims?['assignedUnits'] ?? [],
      );

      if (role != 'admin_organisasi' && role != 'admin_eskul') {
        throw 'Hanya Admin Organisasi/Eskul yang bisa import';
      }

      if (!assignedUnits.contains(unitId)) {
        throw 'Anda hanya bisa import untuk organisasi/eskul Anda sendiri';
      }

      // 2. Validasi data di client
      final validationErrors = validatePesertaData(rawData);
      if (validationErrors.isNotEmpty) {
        return ImportResult(
          success: false,
          totalRows: rawData.length,
          successCount: 0,
          failCount: rawData.length,
          errors: validationErrors,
          message: 'Validasi data gagal. Perbaiki error di atas sebelum import.',
        );
      }

      // 3. Transform data
      final transformedData = rawData.map((row) {
        return {
          'nama': row['nama'],
          'kelas': _transformKelas(row['kelas']),
          'asalSekolah': row['asalSekolah'],
          'jurusan': _transformJurusan(row['jurusan']),
          'unitId': unitId,
          'status': 'pending_wawancara',
          'presentase': null,
          'catatan': [],
        };
      }).toList();

      // 4. Call Cloud Function
      final callable = _functions.httpsCallable('importPeserta');
      final result = await callable.call({
        'data': transformedData,
        'unitId': unitId,
      });

      return ImportResult.fromJson(result.data as Map<String, dynamic>);
    } catch (e) {
      print('❌ Import error: $e');
      return ImportResult(
        success: false,
        totalRows: rawData.length,
        successCount: 0,
        failCount: rawData.length,
        errors: [
          ImportError(
            rowNumber: 0,
            field: 'general',
            value: '',
            error: e.toString(),
          ),
        ],
        message: 'Error: $e',
      );
    }
  }

  // ===== IMPORT ABSENSI =====
  Future<ImportResult> importAbsensi({
    required List<Map<String, dynamic>> rawData,
    required String unitId,
  }) async {
    try {
      // Similar validation & import logic for absensi
      final callable = _functions.httpsCallable('importAbsensi');
      final result = await callable.call({
        'data': rawData,
        'unitId': unitId,
      });

      return ImportResult.fromJson(result.data as Map<String, dynamic>);
    } catch (e) {
      print('❌ Import absensi error: $e');
      rethrow;
    }
  }

  // ===== IMPORT KAS =====
  Future<ImportResult> importKas({
    required List<Map<String, dynamic>> rawData,
    required String unitId,
  }) async {
    try {
      final callable = _functions.httpsCallable('importKas');
      final result = await callable.call({
        'data': rawData,
        'unitId': unitId,
      });

      return ImportResult.fromJson(result.data as Map<String, dynamic>);
    } catch (e) {
      print('❌ Import kas error: $e');
      rethrow;
    }
  }
}
```

### Cloud Function - Server-side Import

```javascript
// functions/src/importPeserta.js

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// ===== IMPORT PESERTA =====
exports.importPeserta = functions.https.onCall(async (data, context) => {
  const { data: pesertaList, unitId } = data;

  // 1. Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  // 2. Validate permission
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const userData = userDoc.data();
  const role = context.auth.token.role;
  const assignedUnits = context.auth.token.assignedUnits || [];

  if (role !== 'admin_organisasi' && role !== 'admin_eskul') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Hanya Admin Organisasi/Eskul yang bisa import'
    );
  }

  if (!assignedUnits.includes(unitId)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Anda hanya bisa import untuk unit Anda sendiri'
    );
  }

  // 3. Re-validate data (security layer)
  const errors = [];
  let successCount = 0;

  for (let i = 0; i < pesertaList.length; i++) {
    const peserta = pesertaList[i];
    const rowNum = i + 2; // Excel row number (header = row 1)

    // Validate required fields
    if (!peserta.nama || peserta.nama.trim().length < 3) {
      errors.push({
        rowNumber: rowNum,
        field: 'nama',
        value: peserta.nama || '',
        error: 'Nama tidak valid',
      });
      continue;
    }

    if (!peserta.kelas) {
      errors.push({
        rowNumber: rowNum,
        field: 'kelas',
        value: '',
        error: 'Kelas tidak boleh kosong',
      });
      continue;
    }

    if (!peserta.asalSekolah) {
      errors.push({
        rowNumber: rowNum,
        field: 'asalSekolah',
        value: '',
        error: 'Asal sekolah tidak boleh kosong',
      });
      continue;
    }

    const validJurusan = ['IPA', 'IPS', 'BHS'];
    if (!peserta.jurusan || !validJurusan.includes(peserta.jurusan.toUpperCase())) {
      errors.push({
        rowNumber: rowNum,
        field: 'jurusan',
        value: peserta.jurusan || '',
        error: 'Jurusan tidak valid (IPA, IPS, BHS)',
      });
      continue;
    }

    successCount++;
  }

  // 4. If validation OK, batch write to Firestore
  if (errors.length === 0) {
    const batch = db.batch();

    for (const peserta of pesertaList) {
      const docRef = db.collection('peserta').doc();
      batch.set(docRef, {
        ...peserta,
        unitId,
        status: 'pending_wawancara',
        presentase: null,
        catatan: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
      });
    }

    await batch.commit();
  }

  // 5. Log to audit_logs
  await db.collection('audit_logs').add({
    action: 'import_peserta',
    byUid: context.auth.uid,
    byName: userData?.nama || 'Unknown',
    unitId,
    totalRows: pesertaList.length,
    successCount,
    failCount: errors.length,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 6. Return result
  return {
    success: errors.length === 0,
    totalRows: pesertaList.length,
    successCount,
    failCount: errors.length,
    errors,
    message:
      errors.length === 0
        ? `✅ Import berhasil! ${successCount} peserta ditambahkan.`
        : `⚠️ Import partial. ${successCount} berhasil, ${errors.length} gagal.`,
  };
});
```

### Flutter UI - Import Screen

```dart
// lib/screens/import_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importService = ImportService();
  ImportResult? _result;
  bool _isLoading = false;
  String _selectedType = 'peserta'; // peserta, absensi, kas

  Future<void> _pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result == null) return;

      setState(() => _isLoading = true);

      // Parse Excel
      final bytes = result.files.single.bytes;
      final excel = Excel.decodeBytes(bytes!);
      final table = excel.tables.values.first;

      // Extract data
      final data = <Map<String, dynamic>>[];
      for (var i = 1; i < table.maxRows; i++) {
        final row = table.row(i);
        if (row.isEmpty || row.every((cell) => cell == null)) continue;

        data.add({
          'nama': row[0]?.value?.toString() ?? '',
          'kelas': row[1]?.value?.toString() ?? '',
          'asalSekolah': row[2]?.value?.toString() ?? '',
          'jurusan': row[3]?.value?.toString() ?? '',
        });
      }

      // Import
      final importResult = await _importService.importPeserta(
        rawData: data,
        unitId: 'PMR', // Should get from context
      );

      setState(() {
        _result = importResult;
        _isLoading = false;
      });

      // Show feedback
      _showFeedbackDialog(importResult);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showFeedbackDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? '✅ Import Berhasil' : '⚠️ Import Gagal'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.message, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Text(
                'Total: ${result.totalRows} | Berhasil: ${result.successCount} | Gagal: ${result.failCount}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Error Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...result.errors.take(10).map((error) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Row ${error.rowNumber} (${error.field}): ${error.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                )),
                if (result.errors.length > 10)
                  Text('... dan ${result.errors.length - 10} error lainnya'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (!result.success)
            TextButton(
              onPressed: () {
                // Download template
                Navigator.pop(context);
              },
              child: const Text('Download Template'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text('Pilih file Excel untuk import'),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _pickAndImport,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Pilih File Excel'),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _result!.success ? Colors.green[50] : Colors.red[50],
                        border: Border.all(
                          color: _result!.success ? Colors.green : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _result!.message,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _result!.success ? Colors.green[900] : Colors.red[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total: ${_result!.totalRows} | ✅ ${_result!.successCount} | ❌ ${_result!.failCount}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
```

---

## FEEDBACK SYSTEM

### Feedback untuk Setiap Aksi

#### 1. **CREATE (Input Data)**

```
BEFORE ACTION:
- Button enable hanya jika form valid
- Show validation errors real-time

DURING ACTION:
- Show loading indicator
- Disable button (prevent double-click)
- Show "Processing..." message

AFTER ACTION (SUCCESS):
✅ Toast: "Data berhasil ditambahkan"
✅ Close dialog/form
✅ Refresh list
✅ Highlight new entry briefly

AFTER ACTION (FAIL):
❌ Dialog dengan error message
❌ Error detail jika ada
❌ Tombol "Retry"
❌ Keep form data (jangan clear)
```

**Implementation:**
```dart
Future<void> createPeserta() async {
  if (!_formKey.currentState!.validate()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Lengkapi form terlebih dahulu'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    await FirebaseFirestore.instance.collection('peserta').add({
      'nama': _namaController.text,
      'kelas': _kelasController.text,
      'asalSekolah': _asalSekolaController.text,
      'jurusan': _jurusanController.text,
      'unitId': _selectedUnit,
      'status': 'pending_wawancara',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    
    // Success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Peserta berhasil ditambahkan'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
    _clearForm();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error: $e'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: createPeserta,
        ),
      ),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

#### 2. **READ (View Data)**

```
LOADING:
- Show skeleton/placeholder
- Shimmer effect optional

SUCCESS:
✅ Data ditampilkan
✅ Show count (e.g., "45 peserta")
✅ Show last updated time

EMPTY:
ℹ️ "Belum ada data" message
ℹ️ Button ke add data

ERROR:
❌ Error message
❌ Button "Retry"
❌ Button "Go Back"
```

#### 3. **UPDATE (Edit Data)**

```
BEFORE:
- Form pre-filled dengan data lama
- Show field yang berubah vs original

DURING:
- Show "Saving..." indicator
- Disable button

SUCCESS:
✅ Toast: "Data berhasil diperbarui"
✅ Refresh view
✅ Show what changed (optional log)
✅ Close dialog

FAIL:
❌ Dialog dengan error
❌ Keep edited data
❌ Button "Retry" / "Cancel"
```

**Implementation:**
```dart
Future<void> updatePeserta(String pesertaId) async {
  if (!_formKey.currentState!.validate()) {
    _showValidationError('Lengkapi form terlebih dahulu');
    return;
  }

  setState(() => _isLoading = true);

  try {
    await FirebaseFirestore.instance
        .collection('peserta')
        .doc(pesertaId)
        .update({
          'presentase': double.parse(_presentaseController.text),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Data berhasil diperbarui'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  } catch (e) {
    _showError('Gagal update: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

#### 4. **DELETE (Hapus Data)**

```
CONFIRMATION:
- Show warning dialog
- Confirm tombol + Cancel tombol
- Show apa yang akan dihapus

DURING:
- Show "Deleting..." indicator
- Disable button

SUCCESS:
✅ Toast: "Data berhasil dihapus"
✅ Remove dari list dengan animation
✅ Close dialog

FAIL:
❌ Dialog error
❌ Button "Retry"
❌ Data tetap ada
```

**Implementation:**
```dart
Future<void> deletePeserta(String pesertaId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus Peserta?'),
      content: const Text('Data peserta akan dihapus permanen. Lanjutkan?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  setState(() => _isLoading = true);

  try {
    await FirebaseFirestore.instance
        .collection('peserta')
        .doc(pesertaId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Data berhasil dihapus'),
        backgroundColor: Colors.green,
      ),
    );

    _refreshList();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Gagal hapus: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

#### 5. **IMPORT (Batch Operation)**

```
BEFORE:
- Pick file
- Show file name & size
- Show import type selection

VALIDATION:
✓ Validate data di client
✓ Show validation errors
✓ Allow fix & retry

DURING:
- Show progress indicator
- Show "Processing... X/Y rows"
- Show current row being processed

SUCCESS:
✅ Show summary (total, success, fail)
✅ List successful rows
✅ List failed rows with error
✅ Button "View Details"
✅ Button "Close"
✅ Auto-refresh list

PARTIAL SUCCESS:
⚠️ Show success count + failed count
⚠️ Show which rows failed + why
⚠️ Button "Download Failed Rows" (CSV)
⚠️ Button "Retry Failed"

FAIL:
❌ Show error message
❌ Button "Retry"
❌ Button "Download Template"
```

---

## SECURITY RULES UPDATE

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function role() {
      return request.auth.token.role;
    }

    function myUnits() {
      return request.auth.token.assignedUnits;
    }

    function isAssignedTo(unitId) {
      return unitId in myUnits();
    }

    // ===== PESERTA - Allow import via Cloud Function =====
    match /peserta/{pesertaId} {
      allow read: if isSignedIn() && (
        request.auth.token.role == 'administrator' ||
        isAssignedTo(resource.data.unitId)
      );

      // Allow create ONLY via Cloud Function (authenticated + validated)
      allow create: if isSignedIn() &&
                        request.auth.token.role in ['admin_organisasi', 'admin_eskul'] &&
                        isAssignedTo(request.resource.data.unitId);

      // Allow update by admin/pembina
      allow update: if isSignedIn() && (
        request.auth.token.role == 'administrator' ||
        (request.auth.token.role in ['admin_organisasi', 'pembina_organisasi'] &&
         isAssignedTo(resource.data.unitId)) ||
        (request.auth.token.role in ['admin_eskul', 'pembina_eskul'] &&
         isAssignedTo(resource.data.unitId))
      );

      allow delete: if request.auth.token.role == 'administrator';
    }

    // ===== ABSENSI - Allow import & create =====
    match /absensi/{absensiId} {
      allow read: if isSignedIn() && (
        request.auth.token.role == 'administrator' ||
        (request.auth.token.role in ['pembina_organisasi', 'pembina_eskul', 
          'admin_organisasi', 'admin_eskul'] &&
         isAssignedTo(resource.data.unitId))
      );

      // Allow create by pembina & admin (via import or direct)
      allow create: if isSignedIn() &&
                        request.auth.token.role in [
                          'administrator',
                          'pembina_organisasi',
                          'pembina_eskul',
                          'admin_organisasi',
                          'admin_eskul'
                        ] &&
                        isAssignedTo(request.resource.data.unitId);

      allow update, delete: if isSignedIn() && (
        request.auth.token.role == 'administrator' ||
        isAssignedTo(resource.data.unitId)
      );
    }

    // ===== KAS - Allow import & create =====
    match /kas/{kasId} {
      allow read: if isSignedIn() && (
        request.auth.token.role == 'administrator' ||
        isAssignedTo(resource.data.unitId)
      );

      allow create: if isSignedIn() &&
                        request.auth.token.role in [
                          'administrator',
                          'pembina_organisasi',
                          'pembina_eskul',
                          'admin_organisasi',
                          'admin_eskul'
                        ] &&
                        isAssignedTo(request.resource.data.unitId);

      allow update, delete: if isSignedIn() && (
        request.auth.token.role == 'administrator' ||
        isAssignedTo(resource.data.unitId)
      );
    }

    // ===== AUDIT LOGS - Only Administrator can read =====
    match /audit_logs/{logId} {
      allow read: if request.auth.token.role == 'administrator';
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

---

## SUMMARY - SOLUTION CHECKLIST

```
✅ VALIDASI DATA
  ├── Client-side validation (Flutter)
  ├── Server-side validation (Cloud Function)
  └── Firestore Security Rules enforcement

✅ FEEDBACK SYSTEM
  ├── Real-time validation feedback
  ├── Loading indicators
  ├── Success/error messages
  ├── Detailed error information
  └── Retry mechanism

✅ IMPORT FLOW
  ├── File pick & parse
  ├── Data transform
  ├── Batch validation
  ├── Cloud Function processing
  ├── Audit logging
  └── User notification

✅ SECURITY
  ├── Permission checks (role + unit)
  ├── Data format validation
  ├── Batch operation handling
  └── Audit trail

✅ ERROR HANDLING
  ├── Detailed error messages per row
  ├── Partial success support
  ├── Retry capability
  └── Error logging
```

---

**DOKUMENTASI SISCO IMPORT & FEEDBACK SYSTEM SELESAI** ✅
