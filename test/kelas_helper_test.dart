import 'package:flutter_test/flutter_test.dart';
import 'package:sisko/utils/kelas_helper.dart';

void main() {
  group('KelasHelper.isValid', () {
    test('jurusan tanpa rombel valid tanpa angka', () {
      expect(KelasHelper.isValid('X PPLG'), isTrue);
      expect(KelasHelper.isValid('XI DKV'), isTrue);
      expect(KelasHelper.isValid('X AKL'), isTrue);
      expect(KelasHelper.isValid('XI AKL'), isTrue);
      expect(KelasHelper.isValid('XII AKL'), isTrue);
      expect(KelasHelper.isValid('XII TLM'), isTrue);
      expect(KelasHelper.isValid('X FARMASI'), isTrue);
    });

    test('jurusan tanpa rombel TIDAK boleh punya angka', () {
      // Inti bug yang dilaporkan: "X PPLG 1" harus ditolak.
      expect(KelasHelper.isValid('X PPLG 1'), isFalse);
      expect(KelasHelper.isValid('XI DKV 2'), isFalse);
      expect(KelasHelper.isValid('X AKL 1'), isFalse);
    });

    test('jurusan berrombel valid dengan angka yang benar', () {
      expect(KelasHelper.isValid('X TJKT 1'), isTrue);
      expect(KelasHelper.isValid('XI TJKT 2'), isTrue);
      expect(KelasHelper.isValid('X MPLB 1'), isTrue);
      expect(KelasHelper.isValid('XII MPLB 2'), isTrue);
      expect(KelasHelper.isValid('X KESEHATAN 1'), isTrue);
      expect(KelasHelper.isValid('XII KESEHATAN 6'), isTrue);
    });

    test('jurusan berrombel TIDAK valid tanpa/di luar rentang angka', () {
      expect(KelasHelper.isValid('X TJKT'), isFalse); // wajib ada rombel
      expect(KelasHelper.isValid('X TJKT 3'), isFalse); // hanya 1-2
      expect(KelasHelper.isValid('X MPLB 3'), isFalse); // hanya 1-2
      expect(KelasHelper.isValid('X KESEHATAN 7'), isFalse); // hanya 1-6
    });

    test('jurusan tak dikenal ditolak', () {
      expect(KelasHelper.isValid('X ABCD 1'), isFalse);
    });

    test('tingkat tak dikenal ditolak', () {
      expect(KelasHelper.isValid('XIII PPLG'), isFalse);
      expect(KelasHelper.isValid('IX PPLG'), isFalse);
    });

    test('menerima angka Arab & spasi/kapital berlebih untuk tingkat', () {
      expect(KelasHelper.isValid('10 pplg'), isTrue);
      expect(KelasHelper.isValid('  11   tjkt   2 '), isTrue);
      expect(KelasHelper.isValid('12 KESEHATAN 3'), isTrue);
    });
  });

  group('KelasHelper.normalize', () {
    test('menyeragamkan bentuk kanonik', () {
      expect(KelasHelper.normalize('10 pplg'), 'X PPLG');
      expect(KelasHelper.normalize('11 akl'), 'XI AKL');
      expect(KelasHelper.normalize('  xi   tjkt 2 '), 'XI TJKT 2');
      expect(KelasHelper.normalize('12 kesehatan 6'), 'XII KESEHATAN 6');
    });

    test('mengembalikan null untuk input tidak valid', () {
      expect(KelasHelper.normalize('X PPLG 1'), isNull);
      expect(KelasHelper.normalize('X ABCD 9'), isNull);
    });
  });

  group('KelasHelper.suggest', () {
    test('membuang angka pada jurusan tanpa rombel', () {
      // Perilaku lama yang salah: menyarankan "X PPLG 1".
      expect(KelasHelper.suggest('X PPLG 1'), 'X PPLG');
      expect(KelasHelper.suggest('XI DKV 3'), 'XI DKV');
      expect(KelasHelper.suggest('XII AKL 2'), 'XII AKL');
    });

    test('menambahkan rombel pertama bila hilang', () {
      expect(KelasHelper.suggest('X TJKT'), 'X TJKT 1');
      expect(KelasHelper.suggest('XI MPLB'), 'XI MPLB 1');
    });

    test('mengoreksi rombel di luar rentang ke yang terdekat', () {
      expect(KelasHelper.suggest('X TJKT 9'), 'X TJKT 2');
      expect(KelasHelper.suggest('X KESEHATAN 9'), 'X KESEHATAN 6');
    });

    test('null bila jurusan tak dikenal', () {
      expect(KelasHelper.suggest('X ABCD 1'), isNull);
    });
  });

  group('KelasHelper.jurusanOf', () {
    test('mengambil nama jurusan', () {
      expect(KelasHelper.jurusanOf('X PPLG'), 'PPLG');
      expect(KelasHelper.jurusanOf('XI AKL'), 'AKL');
      expect(KelasHelper.jurusanOf('XI KESEHATAN 3'), 'KESEHATAN');
      expect(KelasHelper.jurusanOf('X ABCD 1'), isNull);
    });
  });

  group('KelasHelper.semuaKelasValid', () {
    test('menghasilkan jumlah kombinasi yang benar', () {
      // Per tingkat: PPLG,DKV,AKL,TLM,FARMASI (5) + TJKT(2)+MPLB(2)+KESEHATAN(6) = 15
      // 3 tingkat => 45
      expect(KelasHelper.semuaKelasValid.length, 45);
      expect(KelasHelper.semuaKelasValid, contains('X PPLG'));
      expect(KelasHelper.semuaKelasValid, contains('XI AKL'));
      expect(KelasHelper.semuaKelasValid, contains('XII KESEHATAN 6'));
      expect(KelasHelper.semuaKelasValid, isNot(contains('X PPLG 1')));
    });
  });
}
