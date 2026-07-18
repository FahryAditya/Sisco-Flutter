/// Sumber kebenaran tunggal untuk penamaan kelas di SISCO.
///
/// Struktur kelas: `<TINGKAT> <JURUSAN> [<ROMBEL>]`
///   - TINGKAT : X, XI, XII  (menerima juga 10, 11, 12)
///   - JURUSAN : sesuai daftar resmi di [jurusanRombel]
///   - ROMBEL  : hanya untuk jurusan yang memiliki lebih dari satu rombel
///
/// Contoh valid : "X PPLG", "XI TJKT 2", "XII KESEHATAN 6"
/// Contoh TIDAK valid : "X PPLG 1" (PPLG tidak berrombel), "X ABCD 9" (jurusan tak dikenal)
class KelasHelper {
  KelasHelper._();

  /// Tingkat yang diperbolehkan (bentuk kanonik = angka Romawi).
  static const List<String> tingkat = ['X', 'XI', 'XII'];

  /// Daftar jurusan resmi -> daftar nomor rombel yang valid.
  /// List kosong berarti jurusan tersebut TIDAK memakai nomor rombel.
  static const Map<String, List<int>> jurusanRombel = {
    'PPLG': [],
    'TJKT': [1, 2],
    'MPLB': [1, 2],
    'DKV': [],
    'KESEHATAN': [1, 2, 3, 4, 5, 6],
    'TLM': [],
    'FARMASI': [],
  };

  /// Peta alias tingkat (angka Arab & variasi lain) -> bentuk kanonik Romawi.
  static const Map<String, String> _tingkatAlias = {
    'X': 'X', '10': 'X',
    'XI': 'XI', '11': 'XI',
    'XII': 'XII', '12': 'XII',
  };

  /// Semua nama kelas valid (mis. untuk dropdown / saran / contoh).
  static List<String> get semuaKelasValid {
    final result = <String>[];
    for (final t in tingkat) {
      for (final entry in jurusanRombel.entries) {
        if (entry.value.isEmpty) {
          result.add('$t ${entry.key}');
        } else {
          for (final n in entry.value) {
            result.add('$t ${entry.key} $n');
          }
        }
      }
    }
    return result;
  }

  /// Beberapa contoh kelas yang benar-benar ada (untuk pesan bantuan).
  static String get contohKelas => 'X PPLG, XI TJKT 2, XII KESEHATAN 3';

  /// Pisahkan input mentah menjadi (tingkat, jurusan, rombel).
  /// Mengembalikan null jika struktur dasar tidak terpenuhi.
  static _KelasParts? _parse(String raw) {
    final tokens = raw
        .trim()
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.length < 2) return null;

    final tingkat = _tingkatAlias[tokens.first];
    if (tingkat == null) return null;

    int? rombel;
    var rest = tokens.sublist(1);
    // Token terakhir berupa angka dianggap sebagai nomor rombel.
    if (rest.length >= 2 && RegExp(r'^\d+$').hasMatch(rest.last)) {
      rombel = int.tryParse(rest.last);
      rest = rest.sublist(0, rest.length - 1);
    }
    final jurusan = rest.join(' ');
    if (jurusan.isEmpty) return null;

    return _KelasParts(tingkat: tingkat, jurusan: jurusan, rombel: rombel);
  }

  /// Validasi ketat terhadap daftar jurusan & rombel resmi.
  static bool isValid(String raw) {
    final p = _parse(raw);
    if (p == null) return false;

    final allowed = jurusanRombel[p.jurusan];
    if (allowed == null) return false; // jurusan tak dikenal

    if (allowed.isEmpty) {
      return p.rombel == null; // jurusan tanpa rombel: tidak boleh ada nomor
    }
    return p.rombel != null && allowed.contains(p.rombel);
  }

  /// Bentuk kanonik yang seragam (mis. "10 pplg" -> "X PPLG").
  /// Mengembalikan null jika input tidak valid.
  static String? normalize(String raw) {
    if (!isValid(raw)) return null;
    final p = _parse(raw)!;
    return p.rombel == null
        ? '${p.tingkat} ${p.jurusan}'
        : '${p.tingkat} ${p.jurusan} ${p.rombel}';
  }

  /// Nama jurusan (mis. "PPLG", "KESEHATAN") dari sebuah kelas, atau null bila
  /// jurusannya tidak dikenali. Berguna untuk mengisi field kejuruan.
  static String? jurusanOf(String raw) {
    final p = _parse(raw);
    if (p == null) return null;
    return jurusanRombel.containsKey(p.jurusan) ? p.jurusan : null;
  }

  /// Saran kelas valid TERDEKAT untuk input yang salah, atau null bila
  /// jurusannya benar-benar tidak dikenali.
  ///
  /// Contoh: "X PPLG 1" -> "X PPLG" (buang nomor yang tak seharusnya ada),
  ///         "XI TJKT"  -> "XI TJKT 1" (tambahkan rombel pertama),
  ///         "XI TJKT 9"-> "XI TJKT 2" (rombel di luar jangkauan -> yang terdekat).
  static String? suggest(String raw) {
    final p = _parse(raw);
    if (p == null) return null;

    final allowed = jurusanRombel[p.jurusan];
    if (allowed == null) return null; // jurusan tak dikenal -> tak bisa disarankan

    if (allowed.isEmpty) {
      // Jurusan tanpa rombel: buang nomor apa pun.
      return '${p.tingkat} ${p.jurusan}';
    }
    // Jurusan berrombel: pastikan nomor berada di rentang yang valid.
    var rombel = p.rombel;
    if (rombel == null || !allowed.contains(rombel)) {
      rombel = _nearest(allowed, rombel ?? allowed.first);
    }
    return '${p.tingkat} ${p.jurusan} $rombel';
  }

  static int _nearest(List<int> options, int target) {
    return options.reduce(
      (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
    );
  }
}

class _KelasParts {
  final String tingkat;
  final String jurusan;
  final int? rombel;
  _KelasParts({required this.tingkat, required this.jurusan, this.rombel});
}
