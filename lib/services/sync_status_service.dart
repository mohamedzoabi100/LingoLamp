import 'package:rxdart/rxdart.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
  error,
}

class SyncStatusService {
  static final SyncStatusService _instance = SyncStatusService._internal();
  factory SyncStatusService() => _instance;
  SyncStatusService._internal();

  final _statusSubject = BehaviorSubject<SyncStatus>.seeded(SyncStatus.synced);

  Stream<SyncStatus> get statusStream => _statusSubject.stream;
  SyncStatus get currentStatus => _statusSubject.value;

  void updateStatus(SyncStatus status) {
    if (status != currentStatus) {
      _statusSubject.add(status);
    }
  }

  void dispose() {
    _statusSubject.close();
  }
} 