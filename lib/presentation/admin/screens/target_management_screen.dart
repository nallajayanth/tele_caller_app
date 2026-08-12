import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/call_log_providers.dart';
import '../../common/widgets/success_toast.dart';
import 'user_management_screen.dart';

// Employee target provider
final adminTargetProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    final now = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('monthly_targets')
        .where('month', isEqualTo: now.month)
        .where('year', isEqualTo: now.year)
        .get();
    
    final Map<String, double> targetMap = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final deviceId = data['staff_device_id'] as String;
      final targetAmount = (data['target_amount'] as num).toDouble();
      targetMap[deviceId] = targetAmount;
    }
    return targetMap;
  } catch (_) {
    return {};
  }
});

class TargetManagementScreen extends ConsumerStatefulWidget {
  const TargetManagementScreen({super.key});

  @override
  ConsumerState<TargetManagementScreen> createState() => _TargetManagementScreenState();
}

class _TargetManagementScreenState extends ConsumerState<TargetManagementScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _savingStaffPhones = {};

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _saveTarget(String staffPhone, double amount) async {
    setState(() => _savingStaffPhones.add(staffPhone));
    HapticFeedback.mediumImpact();

    try {
      final client = FirebaseFirestore.instance;
      final now = DateTime.now();
      
      // UUID format of staff device ID based on phone number
      final staffDeviceId = '00000000-0000-0000-0000-${staffPhone.padLeft(12, '0')}';

      // Check if target already exists
      final snapshot = await client
          .collection('monthly_targets')
          .where('staff_device_id', isEqualTo: staffDeviceId)
          .where('month', isEqualTo: now.month)
          .where('year', isEqualTo: now.year)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Insert
        final docRef = client.collection('monthly_targets').doc();
        await docRef.set({
          'id': docRef.id,
          'staff_device_id': staffDeviceId,
          'month': now.month,
          'year': now.year,
          'target_amount': amount,
          'set_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Update
        final docId = snapshot.docs.first.id;
        await client.collection('monthly_targets').doc(docId).update({
          'target_amount': amount,
          'set_at': DateTime.now().toIso8601String(),
        });
      }

      // Refresh providers
      ref.invalidate(adminTargetProvider);
      ref.invalidate(staffMonthlyTargetProvider);

      if (mounted) {
        SuccessToast.show(context, message: 'Target updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update target: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingStaffPhones.remove(staffPhone));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    final employeesAsync = ref.watch(employeesProvider);
    final targetsAsync = ref.watch(adminTargetProvider);

    final currentMonthName = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Monthly Targets', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: employeesAsync.when(
        data: (employees) {
          // Filter to show only staff (telecallers) as they have targets
          final staffMembers = employees.where((e) => e.role == 'staff').toList();

          if (staffMembers.isEmpty) {
            return Center(
              child: Text(
                'No staff members registered.',
                style: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
              ),
            );
          }

          return targetsAsync.when(
            data: (targetsMap) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Set monthly targets for staff. Targets must be set by the 31st of the previous month. The app locks on the 1st if targets are not set.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Targets for $currentMonthName',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...staffMembers.map((staff) {
                    final deviceId = '00000000-0000-0000-0000-${staff.phoneNumber.padLeft(12, '0')}';
                    final currentTarget = targetsMap[deviceId] ?? 0.0;

                    if (!_controllers.containsKey(staff.phoneNumber)) {
                      _controllers[staff.phoneNumber] = TextEditingController(
                        text: currentTarget > 0 ? currentTarget.toStringAsFixed(0) : '',
                      );
                    }

                    final controller = _controllers[staff.phoneNumber]!;

                                final isThisSaving = _savingStaffPhones.contains(staff.phoneNumber);

                                return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      staff.phoneNumber,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (currentTarget > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(
                                      labelText: 'Monthly Target (₹)',
                                      hintText: 'Enter target amount',
                                      prefixText: '₹ ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 48,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: isThisSaving
                                          ? null
                                          : const LinearGradient(
                                              colors: [Color(0xFF00857A), Color(0xFF005F54)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      color: isThisSaving ? (isDark ? Colors.white10 : Colors.black12) : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: isThisSaving
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: const Color(0xFF005F54).withValues(alpha: 0.22),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: isThisSaving
                                          ? null
                                          : () {
                                              final val = double.tryParse(controller.text) ?? 0.0;
                                              _saveTarget(staff.phoneNumber, val);
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: isDark ? Colors.white30 : Colors.black38,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isThisSaving)
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else ...[
                                            const Icon(Icons.check_circle_outline_rounded, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Save',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading targets: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading staff: $e')),
      ),
    );
  }
}
