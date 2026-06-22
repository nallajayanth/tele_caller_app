import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/call_log_providers.dart';
import '../../common/widgets/success_toast.dart';
import 'user_management_screen.dart';

// Employee target provider
final adminTargetProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    final now = DateTime.now();
    final response = await Supabase.instance.client
        .from('monthly_targets')
        .select('staff_device_id, target_amount')
        .eq('month', now.month)
        .eq('year', now.year);
    
    final Map<String, double> targetMap = {};
    for (final row in response as List<dynamic>) {
      targetMap[row['staff_device_id'] as String] = (row['target_amount'] as num).toDouble();
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
  bool _isSaving = false;

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _saveTarget(String staffPhone, double amount) async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      
      // UUID format of staff device ID based on phone number
      final staffDeviceId = '00000000-0000-0000-0000-${staffPhone.padLeft(12, '0')}';

      // Check if target already exists
      final existing = await client
          .from('monthly_targets')
          .select('id')
          .eq('staff_device_id', staffDeviceId)
          .eq('month', now.month)
          .eq('year', now.year)
          .maybeSingle();

      if (existing == null) {
        // Insert
        await client.from('monthly_targets').insert({
          'staff_device_id': staffDeviceId,
          'month': now.month,
          'year': now.year,
          'target_amount': amount,
          'set_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Update
        await client.from('monthly_targets').update({
          'target_amount': amount,
          'set_at': DateTime.now().toIso8601String(),
        }).eq('id', existing['id'] as String);
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
      setState(() => _isSaving = false);
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
                                  child: ElevatedButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            final val = double.tryParse(controller.text) ?? 0.0;
                                            _saveTarget(staff.phoneNumber, val);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Save'),
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
