import 'package:cloud_firestore/cloud_firestore.dart';
class Organization {
  final String id;
  final String nama;
  final String slug;
  final String category;
  final String schoolOrigin;
  final String status;
  final String? deskripsi;
  final String? hariPertemuan;
  final String? lokasi;
  final String? waktuMulai;
  final String? waktuSelesai;
  final String? ketuaId;
  final String jurusan;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Organization({
    required this.id,
    required this.nama,
    required this.slug,
    this.category = 'Ekstrakurikuler',
    this.schoolOrigin = 'SMK Airlangga',
    this.status = 'Aktif',
    this.deskripsi,
    this.hariPertemuan,
    this.lokasi,
    this.waktuMulai,
    this.waktuSelesai,
    this.ketuaId,
    this.jurusan = '',
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Organization.fromMap(Map<String, dynamic> map, String docId) {
    return Organization(
      id: docId,
      nama: map['nama'] as String? ?? '',
      slug: map['slug'] as String? ?? docId,
      category: map['category'] as String? ?? 'Ekstrakurikuler',
      schoolOrigin: map['schoolOrigin'] as String? ?? 'SMK Airlangga',
      status: map['status'] as String? ?? 'Aktif',
      deskripsi: map['deskripsi'] as String?,
      hariPertemuan: map['hariPertemuan'] as String?,
      lokasi: map['lokasi'] as String?,
      waktuMulai: map['waktuMulai'] as String?,
      waktuSelesai: map['waktuSelesai'] as String?,
      ketuaId: map['ketuaId'] as String?,
      jurusan: map['jurusan'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'slug': slug,
      'category': category,
      'schoolOrigin': schoolOrigin,
      'status': status,
      'deskripsi': deskripsi,
      'hariPertemuan': hariPertemuan,
      'lokasi': lokasi,
      'waktuMulai': waktuMulai,
      'waktuSelesai': waktuSelesai,
      'ketuaId': ketuaId,
      'jurusan': jurusan,
      'logoUrl': logoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get tipeDisplay {
    if (slug.contains('program')) return 'Programming';
    if (slug.contains('english') || slug.contains('inggris')) return 'English';
    if (slug.contains('osis')) return 'OSIS';
    if (slug.contains('mpk')) return 'MPK';
    return nama;
  }

  Organization copyWith({
    String? id,
    String? nama,
    String? slug,
    String? category,
    String? schoolOrigin,
    String? status,
    String? deskripsi,
    String? hariPertemuan,
    String? lokasi,
    String? waktuMulai,
    String? waktuSelesai,
    String? ketuaId,
    String? jurusan,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Organization(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      schoolOrigin: schoolOrigin ?? this.schoolOrigin,
      status: status ?? this.status,
      deskripsi: deskripsi ?? this.deskripsi,
      hariPertemuan: hariPertemuan ?? this.hariPertemuan,
      lokasi: lokasi ?? this.lokasi,
      waktuMulai: waktuMulai ?? this.waktuMulai,
      waktuSelesai: waktuSelesai ?? this.waktuSelesai,
      ketuaId: ketuaId ?? this.ketuaId,
      jurusan: jurusan ?? this.jurusan,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

