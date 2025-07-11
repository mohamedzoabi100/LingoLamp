import 'package:flutter/material.dart';
import '../services/xp_service.dart';

class XPDisplayWidget extends StatefulWidget {
  final bool showStreak;
  final bool compact;
  
  const XPDisplayWidget({
    Key? key,
    this.showStreak = true,
    this.compact = false,
  }) : super(key: key);

  @override
  State<XPDisplayWidget> createState() => _XPDisplayWidgetState();
}

class _XPDisplayWidgetState extends State<XPDisplayWidget> {
  Map<String, dynamic> _xpStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadXPStats();
    XPService.addXPListener(_loadXPStats);
  }

  @override
  void dispose() {
    XPService.removeXPListener(_loadXPStats);
    super.dispose();
  }

  Future<void> _loadXPStats() async {
    final stats = await XPService().getXPStats();
    if (mounted) {
      setState(() {
        _xpStats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.compact
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Center(child: CircularProgressIndicator());
    }

    final totalXP = _xpStats['totalXP'] ?? 0;
    final todayXP = _xpStats['todayXP'] ?? 0;
    final currentStreak = _xpStats['currentStreak'] ?? 0;
    final longestStreak = _xpStats['longestStreak'] ?? 0;

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            '$totalXP',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.showStreak && currentStreak > 0) ...[
            const SizedBox(width: 8),
            Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
            const SizedBox(width: 4),
            Text(
              '$currentStreak',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      );
    }

    if (!widget.showStreak) {
      // XP Panel only
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Experience Points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Total XP', '$totalXP', Icons.star, Colors.amber),
                  _buildStatItem('XP earned today', '+$todayXP', Icons.today, Colors.green),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Streak Panel only
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Streak',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Current', '$currentStreak 🔥', Icons.local_fire_department, Colors.orange),
                _buildStatItem('Longest', '$longestStreak 🏆', Icons.emoji_events, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 