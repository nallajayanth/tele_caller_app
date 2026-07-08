import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/telecaller_model.dart';
import '../../common/widgets/success_toast.dart';

// Employee list provider (loaded directly from DB)
final employeesProvider = FutureProvider<List<TelecallerModel>>((ref) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('telecallers')
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => TelecallerModel.fromJson(doc.data()))
        .toList();
  } catch (_) {
    return [];
  }
});

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  // ignore: unused_field
  bool _isProcessing = false;

  void _showAddUserDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String role = 'staff';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
              title: Text('Add New Employee', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                          decoration: const InputDecoration(labelText: 'Phone Number (10 digits) *', prefixIcon: Icon(Icons.phone)),
                          validator: (v) => v == null || v.trim().length != 10 ? '10-digit phone number required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: pinCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                          decoration: const InputDecoration(labelText: 'Access PIN (4 digits) *', prefixIcon: Icon(Icons.lock)),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Access PIN required';
                            if (v.trim().length != 4) return 'PIN must be exactly 4 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'System Access Role'),
                          items: const [
                            DropdownMenuItem(value: 'staff', child: Text('Telecaller / Staff')),
                            DropdownMenuItem(value: 'warehouse', child: Text('Warehouse Operator')),
                            DropdownMenuItem(value: 'admin', child: Text('System Admin')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => role = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    Navigator.of(ctx).pop();
                    await _addUser(phoneCtrl.text, nameCtrl.text, pinCtrl.text, role);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addUser(String phone, String name, String pin, String role) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final client = FirebaseFirestore.instance;
      await client.collection('telecallers').doc(phone).set({
        'phone_number': phone,
        'name': name,
        'pin': pin,
        'role': role,
      });

      ref.invalidate(employeesProvider);
      if (mounted) {
        SuccessToast.show(context, message: 'New employee created!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add employee: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showEditUserDialog(BuildContext context, TelecallerModel user) {
    final formKey = GlobalKey<FormState>();
    final phoneCtrl = TextEditingController(text: user.phoneNumber);
    final nameCtrl = TextEditingController(text: user.name);
    final pinCtrl = TextEditingController(text: user.pin);
    String role = user.role;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
              title: Text('Edit Employee', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                          decoration: const InputDecoration(labelText: 'Phone Number (10 digits) *', prefixIcon: Icon(Icons.phone)),
                          validator: (v) => v == null || v.trim().length != 10 ? '10-digit phone number required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: pinCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                          decoration: const InputDecoration(labelText: 'Access PIN (4 digits) *', prefixIcon: Icon(Icons.lock)),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Access PIN required';
                            if (v.trim().length != 4) return 'PIN must be exactly 4 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'System Access Role'),
                          items: const [
                            DropdownMenuItem(value: 'staff', child: Text('Telecaller / Staff')),
                            DropdownMenuItem(value: 'warehouse', child: Text('Warehouse Operator')),
                            DropdownMenuItem(value: 'admin', child: Text('System Admin')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => role = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    Navigator.of(ctx).pop();
                    await _updateUser(user.phoneNumber, phoneCtrl.text, nameCtrl.text, pinCtrl.text, role);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateUser(String oldPhone, String newPhone, String name, String pin, String role) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final client = FirebaseFirestore.instance;
      
      if (oldPhone == newPhone) {
        await client.collection('telecallers').doc(oldPhone).update({
          'name': name,
          'pin': pin,
          'role': role,
        });
      } else {
        // Create new document with new phone number (doc ID) and copy data, then delete old document
        await client.collection('telecallers').doc(newPhone).set({
          'phone_number': newPhone,
          'name': name,
          'pin': pin,
          'role': role,
        });
        await client.collection('telecallers').doc(oldPhone).delete();

        final oldDeviceId = '00000000-0000-0000-0000-${oldPhone.padLeft(12, '0')}';
        final newDeviceId = '00000000-0000-0000-0000-${newPhone.padLeft(12, '0')}';

        final batch = client.batch();

        // Migrate targets
        final targetSnap = await client
            .collection('monthly_targets')
            .where('staff_device_id', isEqualTo: oldDeviceId)
            .get();
        for (final doc in targetSnap.docs) {
          batch.update(doc.reference, {'staff_device_id': newDeviceId});
        }
        
        // Migrate call logs
        final callSnap = await client
            .collection('call_logs')
            .where('device_id', isEqualTo: oldDeviceId)
            .get();
        for (final doc in callSnap.docs) {
          batch.update(doc.reference, {'device_id': newDeviceId});
        }

        // Migrate orders
        final orderSnap = await client
            .collection('orders')
            .where('assigned_staff_device_id', isEqualTo: oldDeviceId)
            .get();
        for (final doc in orderSnap.docs) {
          batch.update(doc.reference, {'assigned_staff_device_id': newDeviceId});
        }

        await batch.commit();
      }

      ref.invalidate(employeesProvider);
      if (mounted) {
        SuccessToast.show(context, message: 'Employee updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update employee: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteUser(String phone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 36),
        title: Text('Delete Employee?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to remove this employee from the system? They will immediately lose access.', style: GoogleFonts.plusJakartaSans(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      final client = FirebaseFirestore.instance;
      await client.collection('telecallers').doc(phone).delete();
      ref.invalidate(employeesProvider);
      if (mounted) {
        SuccessToast.show(context, message: 'Employee removed.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete employee: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Management', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => _showAddUserDialog(context),
            tooltip: 'Add New Employee',
          ),
        ],
      ),
      body: employeesAsync.when(
        data: (employees) {
          if (employees.isEmpty) {
            return Center(
              child: Text(
                'No employees registered.',
                style: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, i) {
              final user = employees[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: _roleColor(user.role).withValues(alpha: 0.1),
                    child: Icon(_roleIcon(user.role), color: _roleColor(user.role)),
                  ),
                  title: Text(
                    user.name,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('📞 ${user.phoneNumber}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(height: 2),
                      Text('🔑 PIN: ${user.pin}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                        onPressed: () => _showEditUserDialog(context, user),
                        tooltip: 'Edit / Reassign phone',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        onPressed: () => _deleteUser(user.phoneNumber),
                        tooltip: 'Delete Employee',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error loading employees: $e')),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.shield_rounded;
      case 'warehouse':
        return Icons.inventory_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.accent;
      case 'warehouse':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.primary;
    }
  }
}
