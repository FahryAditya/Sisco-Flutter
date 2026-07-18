/// Konstanta bersama Airlangga QR Quest.
class QuestConstants {
  QuestConstants._();

  /// Base URL halaman web soal (di-deploy ke Vercel).
  ///
  /// GANTI dengan domain Vercel final SEBELUM mencetak QR. Setelah QR dicetak,
  /// URL ini tidak boleh berubah — QR mengarah ke slot, dan hanya ISI slot
  /// (soal) yang boleh diacak, bukan URL/token-nya.
  static const String questBaseUrl = 'https://web-quest-opal.vercel.app';

  /// URL yang tercetak di QR. Mengarah ke SLOT (token stabil), bukan soal.
  /// Isi soal pada slot bisa diacak tanpa mengganti QR ini.
  static String slotUrl(String slotId) => '$questBaseUrl/?slot=$slotId';
}
