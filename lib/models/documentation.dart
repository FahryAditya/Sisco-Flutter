import 'package:cloud_firestore/cloud_firestore.dart';
class Documentation {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String organizationId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime dateTaken;
  final List<String> photos;

  Documentation({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.organizationId,
    required this.createdBy,
    required this.createdAt,
    required this.dateTaken,
    this.photos = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'organizationId': organizationId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'dateTaken': Timestamp.fromDate(dateTaken),
      'photos': photos,
    };
  }

  factory Documentation.fromMap(Map<String, dynamic> map, String docId) {
    final photosRaw = map['photos'];
    List<String> photos = [];
    if (photosRaw is List) {
      photos = photosRaw.map((e) => e.toString()).toList();
    }

    return Documentation(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      category: map['category'] as String? ?? '',
      organizationId: map['organizationId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateTaken: (map['dateTaken'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photos: photos,
    );
  }
}

