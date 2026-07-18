import 'package:excel/excel.dart' hide Border;
import '../models/member.dart';
import '../models/attendance.dart';
import '../models/cash_transaction.dart';
import '../utils/formatters.dart';

/// Membangun file Excel (.xlsx) sebagai bytes untuk fitur Export.
///
/// Hanya bertugas menyusun workbook; penyimpanan ke perangkat ditangani
/// pemanggil (mis. lewat FilePicker.saveFile) agar layanan ini bebas dari
/// dependensi platform/UI.
class ExcelExportService {
  /// Header sel dengan gaya tebal + latar agar tabel mudah dibaca.
  static CellStyle get _headerStyle => CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('FF0057B3'),
        fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      );

  static void _writeHeader(Sheet sheet, List<String> headers) {
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = _headerStyle;
      sheet.setColumnAutoFit(c);
    }
  }

  /// Excel anggota. Mengembalikan bytes .xlsx.
  static List<int> buildMembers(List<Member> members) {
    final excel = Excel.createExcel();
    final sheet = excel['Anggota'];
    excel.setDefaultSheet('Anggota');
    excel.delete('Sheet1');

    _writeHeader(sheet, ['Nama', 'NIS', 'Kelas', 'Email', 'Jabatan', 'Level', 'EXP', 'Status']);
    for (final m in members) {
      sheet.appendRow([
        TextCellValue(m.name),
        TextCellValue(m.nis ?? ''),
        TextCellValue(m.kelas ?? ''),
        TextCellValue(m.email ?? ''),
        TextCellValue(m.jabatan),
        IntCellValue(m.level),
        IntCellValue(m.exp),
        TextCellValue(m.status),
      ]);
    }
    return excel.encode() ?? <int>[];
  }

  /// Excel absensi pada satu tanggal.
  static List<int> buildAttendance(
    List<Member> members,
    Map<String, Attendance> attByMemberId, {
    required DateTime date,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Absensi'];
    excel.setDefaultSheet('Absensi');
    excel.delete('Sheet1');

    _writeHeader(sheet, ['Nama', 'Kelas', 'Status', 'Catatan', 'Tanggal']);
    final tgl = Formatters.formatDate(date);
    for (final m in members) {
      final a = attByMemberId[m.id];
      sheet.appendRow([
        TextCellValue(m.name),
        TextCellValue(m.kelas ?? ''),
        TextCellValue(a?.status ?? 'Belum absen'),
        TextCellValue(a?.notes ?? ''),
        TextCellValue(tgl),
      ]);
    }
    return excel.encode() ?? <int>[];
  }

  /// Excel kas: dua sheet (Pemasukan & Pengeluaran) + ringkasan saldo.
  static List<int> buildCash(
    List<CashTransaction> pemasukan,
    List<CashExpense> pengeluaran,
  ) {
    final excel = Excel.createExcel();

    final inSheet = excel['Pemasukan'];
    excel.setDefaultSheet('Pemasukan');
    excel.delete('Sheet1');
    _writeHeader(inSheet, ['Deskripsi', 'Kategori', 'Nominal', 'Tanggal']);
    var totalIn = 0;
    for (final t in pemasukan) {
      totalIn += t.amount;
      inSheet.appendRow([
        TextCellValue(t.description),
        TextCellValue(t.category),
        IntCellValue(t.amount),
        TextCellValue(Formatters.formatDate(t.tanggal)),
      ]);
    }

    final outSheet = excel['Pengeluaran'];
    _writeHeader(outSheet, ['Keterangan', 'Kategori', 'Nominal', 'Tanggal']);
    var totalOut = 0;
    for (final e in pengeluaran) {
      totalOut += e.nominal;
      outSheet.appendRow([
        TextCellValue(e.keterangan),
        TextCellValue(e.kategori),
        IntCellValue(e.nominal),
        TextCellValue(Formatters.formatDate(e.tanggal)),
      ]);
    }

    // Ringkasan saldo di sheet terpisah.
    final sum = excel['Ringkasan'];
    _writeHeader(sum, ['Keterangan', 'Jumlah']);
    sum.appendRow([TextCellValue('Total Pemasukan'), IntCellValue(totalIn)]);
    sum.appendRow([TextCellValue('Total Pengeluaran'), IntCellValue(totalOut)]);
    sum.appendRow([TextCellValue('Saldo'), IntCellValue(totalIn - totalOut)]);

    return excel.encode() ?? <int>[];
  }
}
