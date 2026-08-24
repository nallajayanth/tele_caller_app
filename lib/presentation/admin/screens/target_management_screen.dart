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

// State provider for selected target month/year
final targetDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Employee target provider
final adminTargetProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    final selectedDate = ref.watch(targetDateProvider);
    final now = DateTime.now();

    var snapshot = await FirebaseFirestore.instance
        .collection('monthly_targets')
        .where('month', isEqualTo: selectedDate.month)
        .where('year', isEqualTo: selectedDate.year)
        .get();
    
    // If empty for selected month and selected date is not current month, try current month
    if (snapshot.docs.isEmpty && (selectedDate.month != now.month || selectedDate.year != now.year)) {
      snapshot = await FirebaseFirestore.instance
          .collection('monthly_targets')
          .where('month', isEqualTo: now.month)
          .where('year', isEqualTo: now.year)
          .get();
    }

    // Ultimate fallback: fetch all monthly targets if date query returns empty
    if (snapshot.docs.isEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection('monthly_targets')
          .get();
    }

    final Map<String, double> targetMap = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final deviceId = data['staff_device_id'] as String?;
      final phone = data['staff_phone'] as String?;
      final targetAmount = data['target_amount'];
      final targetVal = targetAmount is num ? targetAmount.toDouble() : 0.0;

      if (deviceId != null && deviceId.isNotEmpty) {
        targetMap[deviceId] = targetVal;
      }
      if (phone != null && phone.isNotEmpty) {
        targetMap[phone] = targetVal;
        final aliasDeviceId = '00000000-0000-0000-0000-${phone.padLeft(12, '0')}';
        targetMap[aliasDeviceId] = targetVal;
      }
    }
    return targetMap;
  } catch (e) {
    debugPrint('Error loading admin targets: $e');
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

  Future<void> _saveTarget(String staffPhone, double amount, DateTime targetDate) async {
    setState(() => _savingStaffPhones.add(staffPhone));
    HapticFeedback.mediumImpact();

    try {
      final client = FirebaseFirestore.instance;
      
      // UUID format of staff device ID based on phone number
      final staffDeviceId = '00000000-0000-0000-0000-${staffPhone.padLeft(12, '0')}';
      final docId = '${staffDeviceId}_${targetDate.year}_${targetDate.month}';

      final batch = client.batch();

      // Find any existing docs for this staff/month/year to clean duplicates
      final snapshot = await client
          .collection('monthly_targets')
          .where('staff_device_id', isEqualTo: staffDeviceId)
          .where('month', isEqualTo: targetDate.month)
          .where('year', isEqualTo: targetDate.year)
          .get();

      // Delete all existing ones
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // Set the new deterministic document
      final docRef = client.collection('monthly_targets').doc(docId);
      batch.set(docRef, {
        'id': docId,
        'staff_device_id': staffDeviceId,
        'staff_phone': staffPhone,
        'month': targetDate.month,
        'year': targetDate.year,
        'target_amount': amount,
        'set_at': DateTime.now().toIso8601String(),
      });

      await batch.commit();

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

    final selectedDate = ref.watch(targetDateProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final targetsAsync = ref.watch(adminTargetProvider);

    final currentMonthName = DateFormat('MMMM yyyy').format(selectedDate);

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
                  // Month Selector Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppColors.primary),
                          onPressed: () {
                            final prev = DateTime(selectedDate.year, selectedDate.month - 1);
                            ref.read(targetDateProvider.notifier).state = prev;
                          },
                        ),
                        Text(
                          currentMonthName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.primary),
                          onPressed: () {
                            final next = DateTime(selectedDate.year, selectedDate.month + 1);
                            ref.read(targetDateProvider.notifier).state = next;
                          },
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
                    final key = '${staff.phoneNumber}_${selectedDate.year}_${selectedDate.month}';

                    if (!_controllers.containsKey(key)) {
                      _controllers[key] = TextEditingController(
                        text: currentTarget > 0 ? currentTarget.toStringAsFixed(0) : '',
                      );
                    }

                    final controller = _controllers[key]!;
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
                                              _saveTarget(staff.phoneNumber, val, selectedDate);
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
