import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/activity_log.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_app_bar.dart';

class LogAktivitasPage extends StatefulWidget {
  const LogAktivitasPage({super.key});

  @override
  State<LogAktivitasPage> createState() => _LogAktivitasPageState();
}

class _LogAktivitasPageState extends State<LogAktivitasPage> {
  List<ActivityLog> _logs = [];
  bool _loading = false;
  bool _loadingMore = false;
  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await FirestoreService.getLogs(limit: _pageSize);
      _logs = result;
      _lastDoc = await FirestoreService.getLastLogDoc(limit: _pageSize);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat log: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final result = await FirestoreService.getLogs(limit: _pageSize, startAfter: _lastDoc);
      if (result.isEmpty) {
        _lastDoc = null;
      } else {
        _logs.addAll(result);
        _lastDoc = await FirestoreService.getLastLogDoc(limit: _pageSize, startAfter: _lastDoc);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat lebih banyak: $e')));
    }
    setState(() => _loadingMore = false);
  }

  IconData _aksiIcon(String aksi) {
    switch (aksi) {
      case 'CREATE': return Icons.add_circle_outline;
      case 'UPDATE': return Icons.edit_outlined;
      case 'DELETE': return Icons.delete_outline;
      case 'LOGIN': return Icons.login;
      case 'LOGOUT': return Icons.logout;
      default: return Icons.info_outline;
    }
  }

  Color _aksiColor(String aksi) {
    switch (aksi) {
      case 'CREATE': return AppColors.success;
      case 'UPDATE': return AppColors.info;
      case 'DELETE': return AppColors.danger;
      case 'LOGIN': return AppColors.primary;
      case 'LOGOUT': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Log Aktivitas',
        colors: const [Color(0xFF90A4AE), Color(0xFF546E7A)],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _logs.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Belum ada log', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length + (_lastDoc != null ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _logs.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: _loadingMore
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _loadMore,
                                child: const Text('Muat lebih banyak'),
                              ),
                        );
                      }
                      final l = _logs[i];
                      return Card(child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _aksiColor(l.aksi).withAlpha(30),
                          child: Icon(_aksiIcon(l.aksi), color: _aksiColor(l.aksi), size: 20),
                        ),
                        title: Text(l.deskripsi, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                        subtitle: Text('${l.userNama} - ${Formatters.formatDateTime(l.createdAt)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: Chip(label: Text(l.aksi, style: const TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: _aksiColor(l.aksi)),
                      ));
                    },
                  ),
                ),
    );
  }
}
