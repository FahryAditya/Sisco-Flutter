import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/interview.dart';
import '../services/firestore_service.dart';

class InterviewProvider extends ChangeNotifier {
  List<InterviewSession> _sessions = [];
  List<InterviewQueue> _queues = [];
  bool _loading = false;
  String? _currentOrgId;
  String? _currentSesiId;
  StreamSubscription? _sesiSub;
  StreamSubscription? _queueSub;

  List<InterviewSession> get sessions => _sessions;
  List<InterviewQueue> get queues => _queues;
  bool get loading => _loading;

  void clear() {
    _sesiSub?.cancel();
    _queueSub?.cancel();
    _sessions = [];
    _queues = [];
    _loading = false;
    _currentOrgId = null;
    _currentSesiId = null;
    notifyListeners();
  }

  void subscribeSessions(String orgId) {
    if (_currentOrgId == orgId) return;
    _currentOrgId = orgId;
    _sesiSub?.cancel();
    _loading = true;
    notifyListeners();

    _sesiSub = FirestoreService.sessionsStream(orgId).listen((list) {
      _sessions = list;
      _loading = false;
      notifyListeners();
    }, onError: (_) {
      _sessions = [];
      _loading = false;
      notifyListeners();
    });
  }

  void subscribeQueues(String sesiId) {
    if (_currentSesiId == sesiId) return;
    _currentSesiId = sesiId;
    _queueSub?.cancel();
    _queueSub = FirestoreService.queuesStream(sesiId).listen((list) {
      _queues = list;
      notifyListeners();
    }, onError: (_) {
      _queues = [];
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sesiSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }
}
