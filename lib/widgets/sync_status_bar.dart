import 'package:flutter/material.dart';
import '../services/sync_status_service.dart';

class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncStatusService().statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.synced;
        
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIcon(status),
              const SizedBox(width: 4),
              _buildStatusText(status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(SyncStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = Colors.green;
        break;
      case SyncStatus.syncing:
        icon = Icons.cloud_sync;
        color = Colors.blue;
        break;
      case SyncStatus.offline:
        icon = Icons.cloud_off;
        color = Colors.orange;
        break;
      case SyncStatus.error:
        icon = Icons.error;
        color = Colors.red;
        break;
    }
    
    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }

  Widget _buildStatusText(SyncStatus status) {
    String text;
    Color color;
    
    switch (status) {
      case SyncStatus.synced:
        text = 'Synced';
        color = Colors.green;
        break;
      case SyncStatus.syncing:
        text = 'Syncing...';
        color = Colors.blue;
        break;
      case SyncStatus.offline:
        text = 'Offline';
        color = Colors.orange;
        break;
      case SyncStatus.error:
        text = 'Sync Error';
        color = Colors.red;
        break;
    }
    
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
} 