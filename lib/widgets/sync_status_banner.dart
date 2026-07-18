import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Banner status sinkronisasi offline.
///
/// - Offline / ada antrian tertunda -> banner kuning + tombol "Sinkronkan".
/// - Sedang menyinkronkan -> indikator progress berputar.
/// - Online tanpa antrian -> banner disembunyikan.
///
/// Menonton [SyncService.instance.status] lewat [ValueListenableBuilder] agar
/// hemat rebuild. Sisipkan di atas body halaman (mis. Home).
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.status,
      builder: (context, s, _) {
        // Online, tidak menyinkron, dan tak ada antrian -> tidak perlu banner.
        if (s.isOnline && !s.isSyncing && !s.hasPending) {
          return const SizedBox.shrink();
        }

        final Color bg;
        final Color fg;
        final IconData icon;
        final String message;
        final bool showSyncButton;

        if (s.isSyncing) {
          bg = AppColors.info.withValues(alpha: 0.12);
          fg = AppColors.info;
          icon = Icons.sync;
          message =
              'Menyinkronkan${s.hasPending ? ' ${s.pendingCount} perubahan' : ''}...';
          showSyncButton = false;
        } else if (!s.isOnline) {
          bg = AppColors.warning.withValues(alpha: 0.14);
          fg = AppColors.warning;
          icon = Icons.cloud_off;
          message = s.hasPending
              ? 'Mode offline - ${s.pendingCount} perubahan menunggu sinkronisasi'
              : 'Mode offline - perubahan disimpan sementara di perangkat';
          showSyncButton = false;
        } else {
          // Online tapi masih ada antrian (mis. gagal sebagian).
          bg = AppColors.warning.withValues(alpha: 0.14);
          fg = AppColors.warning;
          icon = Icons.cloud_upload_outlined;
          message = '${s.pendingCount} perubahan belum tersinkron';
          showSyncButton = true;
        }

        return Material(
          color: bg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (s.isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else
                  Icon(icon, size: 18, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showSyncButton)
                  TextButton(
                    onPressed: () => SyncService.instance.flush(),
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Sinkronkan'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
