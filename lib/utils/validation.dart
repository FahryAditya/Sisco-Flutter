class Validation {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email wajib diisi';
    final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(value)) return 'Email tidak valid';
    return null;
  }

  static String? required(String? value, [String field = 'field']) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    return null;
  }

  static String? nama(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nama wajib diisi';
    if (value.length > 100) return 'Nama maksimal 100 karakter';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;
    final phoneRegex = RegExp(r'^\+?[\d\s-]{8,15}$');
    if (!phoneRegex.hasMatch(value)) return 'No. HP tidak valid';
    return null;
  }

  static String? nis(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length < 5) return 'NIS minimal 5 karakter';
    return value.length > 20 ? 'NIS maksimal 20 karakter' : null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) return 'Jumlah wajib diisi';
    final n = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n == null) return 'Jumlah tidak valid';
    return n <= 0 ? 'Jumlah harus lebih dari 0' : null;
  }
}
