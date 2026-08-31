import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Security & Alert Logs',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear All Alerts',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _confirmClearAll(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No security or operational alerts logged.',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, idx) {
              final doc = docs[idx];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? 'Alert';
              final body = data['body'] as String? ?? '';
              final type = data['type'] as String? ?? 'info';
              final timestampVal = data['timestamp'];
              
              DateTime time = DateTime.now();
              if (timestampVal is Timestamp) {
                time = timestampVal.toDate();
              } else if (timestampVal is String) {
                time = DateTime.tryParse(timestampVal) ?? DateTime.now();
              }

              IconData icon = Icons.info_outline_rounded;
              Color color = AppColors.primary;

              switch (type) {
                case 'mock_gps':
                  icon = Icons.gps_fixed_rounded;
                  color = AppColors.error;
                  break;
                case 'low_battery':
                  icon = Icons.battery_alert_rounded;
                  color = Colors.orange;
                  break;
                case 'internet_loss':
                  icon = Icons.signal_wifi_off_rounded;
                  color = Colors.orange.shade700;
                  break;
                case 'long_idle':
                  icon = Icons.bedtime_rounded;
                  color = Colors.blue;
                  break;
                case 'duty_start':
                  icon = Icons.play_circle_fill_rounded;
                  color = AppColors.success;
                  break;
                case 'duty_end':
                  icon = Icons.stop_circle_rounded;
                  color = AppColors.error;
                  break;
                case 'missing_photo':
                  icon = Icons.no_photography_rounded;
                  color = AppColors.error;
                  break;
                case 'completed_visit':
                  icon = Icons.check_circle_rounded;
                  color = AppColors.success;
                  break;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(time),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          body,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(time),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                    onPressed: () => FirebaseFirestore.instance.collection('notifications').doc(doc.id).delete(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Alerts?'),
        content: const Text('This will delete all logged alert entries permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final snap = await FirebaseFirestore.instance.collection('notifications').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
