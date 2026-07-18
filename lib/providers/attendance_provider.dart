import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../services/firestore_service.dart';

class AttendanceProvider extends ChangeNotifier {
  List<Attendance> _attendances = [];
  bool _loading = false;

  List<Attendance> get attendances => _attendances;
  bool get loading => _loading;

  Future<void> loadAttendance(String orgId, DateTime date) async {
    _loading = true;
    notifyListeners();
    try {
      _attendances = await FirestoreService.getAttendanceByDate(orgId, date);
    } catch (_) {
      _attendances = [];
    }
    _loading = false;
    notifyListeners();
  }
}
