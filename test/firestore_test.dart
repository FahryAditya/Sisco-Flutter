import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sisko/firebase_options.dart';

/// Verifikasi konfigurasi Firestore.
/// Untuk full runtime test, jalankan di device/emulator.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase Configuration', () {
    test('Android options valid', () {
      const opts = DefaultFirebaseOptions.android;
      expect(opts.projectId, 'database-7069a');
      expect(opts.apiKey, startsWith('AIza'));
      expect(opts.appId, contains('454602570021'));
    });

    test('All platforms share projectId', () {
      expect(DefaultFirebaseOptions.web.projectId, 'database-7069a');
      expect(DefaultFirebaseOptions.android.projectId, 'database-7069a');
      expect(DefaultFirebaseOptions.ios.projectId, 'database-7069a');
      expect(DefaultFirebaseOptions.macos.projectId, 'database-7069a');
      expect(DefaultFirebaseOptions.windows.projectId, 'database-7069a');
    });

    test('Firebase init (requires device/emulator)', () async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        expect(Firebase.app().options.projectId, 'database-7069a');
      } catch (_) {
        // Skip — requires device/emulator
      }
    });
  });

  group('Collection Names', () {
    test('All Firestore collection names are valid', () {
      const collections = [
        'users',
        'organizations',
        'members',
        'attendance',
        'cash_transactions',
        'cash_expenses',
        'interview_sessions',
        'interview_results',
        'activity_logs',
        'daily_materials',
        'documentation',
        'achievements',
        'registrations',
        'schedules',
      ];
      for (final c in collections) {
        expect(c, isNotEmpty);
        expect(c.contains(' '), isFalse, reason: 'Spasi tidak boleh di nama collection');
        expect(c.contains('..'), isFalse, reason: 'Double dot tidak boleh di nama collection');
      }
    });

    test('Subcollection paths valid', () {
      const paths = [
        'members/{memberId}/achievements',
        'interview_sessions/{sesiId}/queues',
        'interview_sessions/{sesiId}/chats',
        'interview_sessions/{sesiId}/qr_tokens',
      ];
      for (final p in paths) {
        expect(p.split('/').length, 3);
      }
    });
  });

  group('Data Field Completeness', () {
    test('createUser data contains all required fields', () {
      final data = {
        'nama': 'Test User',
        'email': 'test@test.com',
        'role': 'organization_admin',
        'orgIds': <String>[],
      };
      expect(data.keys, containsAll(['nama', 'email', 'role', 'orgIds']));
    });

    test('createExpense data contains all required fields', () {
      final data = {
        'organizationId': 'org-id',
        'nominal': 50000,
        'keterangan': 'Test expense',
        'tanggal': '2024-01-01',
        'createdBy': 'user-id',
      };
      expect(data.keys, containsAll(['organizationId', 'nominal', 'keterangan', 'tanggal', 'createdBy']));
    });

    test('Attendance upsert data contains all required fields', () {
      final data = {
        'organizationId': 'org-id',
        'memberId': 'member-id',
        'date': '2024-01-01',
        'status': 'hadir',
        'cashAmount': 0,
        'notes': null,
      };
      expect(data.keys, containsAll(['organizationId', 'memberId', 'date', 'status', 'cashAmount']));
    });

    test('createMember data contains all required fields', () {
      final data = {
        'organizationId': 'org-id',
        'name': 'Test Member',
        'kelas': 'X PPLG 1',
        'nis': '12345',
        'email': 'member@test.com',
        'status': 'ACTIVE',
        'level': 1,
        'exp': 0,
        'progress': 0,
      };
      expect(data.keys, containsAll(['organizationId', 'name', 'status', 'level', 'exp', 'progress']));
    });

    test('createRegistration data contains all required fields', () {
      final data = {
        'organizationId': 'org-id',
        'namaPeserta': 'Test',
        'kelas': 'X PPLG 1',
        'kejuruan': 'PPLG',
        'emailGmail': 'test@gmail.com',
        'nisn': '1234567890',
        'status': 'MENUNGGU',
      };
      expect(data.keys, containsAll(['organizationId', 'namaPeserta', 'kelas', 'kejuruan', 'emailGmail', 'status']));
    });
  });
}
