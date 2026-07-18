import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/cash_transaction.dart';
import '../services/firestore_service.dart';

class CashProvider extends ChangeNotifier {
  List<CashTransaction> _transactions = [];
  List<CashExpense> _expenses = [];
  int _balance = 0;
  bool _loading = false;
  String? _currentOrgId;
  int _errorCode = 0;
  StreamSubscription? _txSub;
  StreamSubscription? _exSub;
  bool _txLoaded = false;
  bool _exLoaded = false;

  List<CashTransaction> get transactions => _transactions;
  List<CashExpense> get expenses => _expenses;
  int get balance => _balance;
  bool get loading => _loading;
  int get errorCode => _errorCode;

  void _recalculateBalance() {
    int totalTx = 0;
    for (final t in _transactions) {
      totalTx += t.amount;
    }
    int totalEx = 0;
    for (final e in _expenses) {
      totalEx += e.nominal;
    }
    _balance = totalTx - totalEx;
  }

  void _checkLoaded() {
    if (_txLoaded && _exLoaded) {
      _loading = false;
      notifyListeners();
    }
  }

  void subscribe(String orgId) {
    if (_currentOrgId == orgId && (_txSub != null || _exSub != null)) return;
    _currentOrgId = orgId;
    _errorCode = 0;
    _cancelSubs();
    _txLoaded = false;
    _exLoaded = false;
    _loading = true;
    _transactions = [];
    _expenses = [];
    _balance = 0;
    notifyListeners();

    _txSub = FirestoreService.cashTransactionsStream(orgId).listen((list) {
      _transactions = list;
      _recalculateBalance();
      _txLoaded = true;
      _checkLoaded();
    }, onError: (e) {
      debugPrint('CashProvider txStream error: $e');
      _txSub?.cancel();
      _txSub = null;
      FirestoreService.getCashTransactions(orgId).then((list) {
        _transactions = list;
        _recalculateBalance();
        _txLoaded = true;
        _errorCode = 1;
        _checkLoaded();
      });
    });

    _exSub = FirestoreService.expensesStream(orgId).listen((list) {
      _expenses = list;
      _recalculateBalance();
      _exLoaded = true;
      _checkLoaded();
    }, onError: (e) {
      debugPrint('CashProvider exStream error: $e');
      _exSub?.cancel();
      _exSub = null;
      FirestoreService.getExpenses(orgId).then((list) {
        _expenses = list;
        _recalculateBalance();
        _exLoaded = true;
        _errorCode = 1;
        _checkLoaded();
      });
    });
  }

  void _cancelSubs() {
    _txSub?.cancel();
    _txSub = null;
    _exSub?.cancel();
    _exSub = null;
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }
}
