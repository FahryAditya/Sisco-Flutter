import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/organization.dart';
import '../../models/quest_feature.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/character_dialog.dart';

/// Alur aktivasi "Airlangga QR Quest" yang bisa dipanggil dari Admin Panel
/// maupun halaman Admin Org. Satu sumber kebenaran agar tidak ada duplikasi.
///
/// Alur: konfirmasi → form (pilih pemegang akses + organisasi peserta 2–6)
/// → simpan konfigurasi + catat activity log.
class QuestActivation {
  QuestActivation._();

  /// Role yang boleh menjadi pemegang akses (menu quest muncul di app mereka).
  static const _accessRoles = {
    'administrator', 'admin_organisasi', 'admin_eskul',
    'pembina_organisasi', 'pembina_eskul',
    // alias lama yang mungkin masih tersimpan di data
    'superadmin', 'admin', 'organization_admin', 'organisasi', 'eskul',
  };

  /// Buka alur aktivasi. [restrictOrgIds] membatasi daftar organisasi peserta
  /// yang bisa dipilih (dipakai Admin Org yang hanya boleh memilih orgnya).
  /// Null = semua organisasi (Administrator).
  static Future<void> show(
    BuildContext context, {
    List<String>? restrictOrgIds,
  }) async {
    // 1. Konfirmasi aktivasi.
    final ok = await AppDialogs.showConfirm(
      context,
      message: 'Anda yakin mengaktifkan Airlangga QR Quest?',
      confirmLabel: 'Ya',
      cancelLabel: 'Tidak',
    );
    if (!ok || !context.mounted) return;

    // 2. Muat data yang dibutuhkan: users, organisasi, dan config terkini.
    List<UserModel> users;
    List<Organization> orgs;
    QuestFeatureConfig cfg;
    try {
      users = await FirestoreService.getUsers();
      orgs = await FirestoreService.getOrganizations();
      cfg = await FirestoreService.getQuestConfig();
    } catch (e) {
      if (context.mounted) {
        await AppDialogs.showError(context, 'Gagal memuat data: $e');
      }
      return;
    }
    if (!context.mounted) return;

    if (restrictOrgIds != null) {
      orgs = orgs.where((o) => restrictOrgIds.contains(o.id)).toList();
    }
    final eligibleUsers =
        users.where((u) => _accessRoles.contains(u.role)).toList();

    final selectedUsers = <String>{...cfg.accessUserIds};
    final selectedOrgs = <String>{...cfg.participantOrgIds};
    final actor = context.read<AuthProvider>().user;

    await _showForm(
      context,
      eligibleUsers: eligibleUsers,
      orgs: orgs,
      selectedUsers: selectedUsers,
      selectedOrgs: selectedOrgs,
      actor: actor,
    );
  }

  static Future<void> _showForm(
    BuildContext context, {
    required List<UserModel> eligibleUsers,
    required List<Organization> orgs,
    required Set<String> selectedUsers,
    required Set<String> selectedOrgs,
    required UserModel? actor,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Aktivasi Airlangga QR Quest'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Pilih pemegang akses (menu quest muncul di app '
                          'mereka) dan organisasi peserta (2–6 organisasi).',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      _userTile(eligibleUsers, selectedUsers, setDialogState),
                      _orgTile(orgs, selectedOrgs, setDialogState),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        // Validasi.
                        if (selectedUsers.isEmpty) {
                          await AppDialogs.showError(
                              ctx, 'Pilih minimal 1 pemegang akses');
                          return;
                        }
                        if (selectedOrgs.length < 2 ||
                            selectedOrgs.length > 6) {
                          await AppDialogs.showError(
                              ctx, 'Pilih 2 sampai 6 organisasi peserta');
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await FirestoreService.saveQuestConfig({
                            'enabled': true,
                            'accessUserIds': selectedUsers.toList(),
                            'participantOrgIds': selectedOrgs.toList(),
                            'activatedBy': actor?.id,
                            'activatedByNama': actor?.nama,
                            'activatedAt': FieldValue.serverTimestamp(),
                          }).timeout(const Duration(seconds: 120));
                          await FirestoreService.logAction(
                            userId: actor?.id ?? '',
                            userNama: actor?.nama ?? '',
                            aksi: 'UPDATE',
                            tabel: 'app_features',
                            recordId: QuestFeatureConfig.docId,
                            deskripsi:
                                'Mengaktifkan Airlangga QR Quest '
                                '(${selectedUsers.length} akses, '
                                '${selectedOrgs.length} organisasi peserta)',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (ctx.mounted) {
                            await AppDialogs.showSuccess(
                                ctx, 'Airlangga QR Quest diaktifkan');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            await AppDialogs.showError(
                                ctx, 'Gagal menyimpan: $e');
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _userTile(
    List<UserModel> users,
    Set<String> selected,
    StateSetter setDialogState,
  ) {
    if (users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Belum ada user yang memenuhi syarat menjadi pemegang akses.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Pemegang Akses (${selected.length})',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: users.map((u) {
                return CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(u.id),
                  title: Text(u.nama, style: const TextStyle(fontSize: 14)),
                  subtitle:
                      Text(u.roleDisplay, style: const TextStyle(fontSize: 11)),
                  onChanged: (v) => setDialogState(() {
                    if (v == true) {
                      selected.add(u.id);
                    } else {
                      selected.remove(u.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _orgTile(
    List<Organization> orgs,
    Set<String> selected,
    StateSetter setDialogState,
  ) {
    if (orgs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Belum ada organisasi. Buat dulu di menu Organisasi.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ),
      );
    }
    final count = selected.length;
    final valid = count >= 2 && count <= 6;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.groups_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Organisasi Peserta ($count/6)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valid ? AppColors.textSecondary : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          if (!valid)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Pilih 2 sampai 6 organisasi.',
                style: TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: orgs.map((o) {
                final isSelected = selected.contains(o.id);
                // Blokir menambah lebih dari 6; item terpilih tetap bisa dilepas.
                final atMax = selected.length >= 6 && !isSelected;
                return CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: isSelected,
                  enabled: !atMax,
                  title: Text(o.nama, style: const TextStyle(fontSize: 14)),
                  subtitle:
                      Text(o.category, style: const TextStyle(fontSize: 11)),
                  onChanged: (v) => setDialogState(() {
                    if (v == true) {
                      selected.add(o.id);
                    } else {
                      selected.remove(o.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
