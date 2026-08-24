import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/call_log_model.dart';
import '../../staff/widgets/activity_log_card.dart';

class AdminLogCard extends ConsumerWidget {
  final CallLogModel log;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AdminLogCard({
    super.key,
    required this.log,
    required this.index,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActivityLogCard(
      log: log,
      index: index,
      showStaffName: true,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}
