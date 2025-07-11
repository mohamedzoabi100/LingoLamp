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

class _XPDisplayWidgetState extends State<XPDisplayWidget> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _xpStats = {};
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _loadXPStats();
    XPService.addXPListener(_loadXPStats);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    XPService.removeXPListener(_loadXPStats);
    _animController.dispose();
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
      return ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(33, 150, 243, 1).withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color.fromRGBO(33, 150, 243, 1).withOpacity(0.3), width: 2),
          ),
          child: Card(
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Remove icon from header
                  Text(
                    'Experience Points',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildStatItem('Total XP', '$totalXP', Icons.star, Colors.amber)),
                      Container(
                        height: 48,
                        width: 1.2,
                        color: const Color.fromRGBO(33, 150, 243, 1).withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(child: _buildStatItem('XP Today', '+$todayXP', Icons.today, Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Streak Panel only
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.10),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
        ),
        child: Card(
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row(
                //   children: [
                //     Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                //     const SizedBox(width: 10),
                //     Text(
                //       'Streak',
                //       style: TextStyle(
                //         fontSize: 20,
                //         fontWeight: FontWeight.bold,
                //         color: Theme.of(context).primaryColor,
                //       ),
                //     ),
                //   ],
                // ),
                Text(
                  'Streak',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildStatItem('Current Streak', '$currentStreak', Icons.local_fire_department, Colors.orange)),
                    Container(
                      height: 48,
                      width: 1.2,
                      color: Colors.teal.withOpacity(0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Expanded(child: _buildStatItem('Longest Streak', '$longestStreak', Icons.emoji_events, Colors.amber)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: color, size: 32),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.teal[900],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 