import 'package:flutter/material.dart';
import '../services/sync_status_service.dart';

class SyncStatusBar extends StatelessWidget {
  final SyncStatusService _syncStatusService = SyncStatusService();

  SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: _syncStatusService.statusStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == SyncStatus.synced) {
          return const SizedBox.shrink(); // Show nothing when synced
        }

        final status = snapshot.data!;
        IconData icon;
        String text;
        Color color;

        switch (status) {
          case SyncStatus.syncing:
            icon = Icons.sync;
            text = 'Syncing...';
            color = Colors.orange;
            break;
          case SyncStatus.offline:
            icon = Icons.cloud_off;
            text = 'Offline';
            color = Colors.grey;
            break;
          case SyncStatus.error:
            icon = Icons.error_outline;
            text = 'Sync Error';
            color = Colors.red;
            break;
          case SyncStatus.synced:
            return const SizedBox.shrink();
        }

        return Container(
          color: color,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
} 