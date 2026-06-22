import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ffvvvpkdcorvpzeuuyye.supabase.co',
    'sb_publishable_el8E3VxIXjqZPzetNt9Smw_l_5m-lVS',
  );

  print('--- TELECALLERS ---');
  try {
    final callers = await client.from('telecallers').select();
    for (var c in callers) {
      print('Name: ${c['name']}, Phone: ${c['phone_number']}, Role: ${c['role']}, PIN: ${c['pin']}');
    }
  } catch (e) {
    print('Failed to get telecallers: $e');
  }

  print('\n--- RECENT CALL LOGS ---');
  try {
    final logs = await client.from('call_logs').select().order('date', ascending: false).limit(10);
    for (var l in logs) {
      print('ID: ${l['id']}, Customer: ${l['customer_name']}, Device ID: ${l['device_id']}, Date: ${l['date']}, Connected Status: ${l['connected_status']}');
    }
  } catch (e) {
    print('Failed to get call logs: $e');
  }

  print('\n--- RECENT ORDERS ---');
  try {
    final orders = await client.from('orders').select().order('created_at', ascending: false).limit(10);
    for (var o in orders) {
      print('ID: ${o['id']}, Customer: ${o['customer_name']}, Assigned Device ID: ${o['assigned_staff_device_id']}, Status: ${o['status']}');
    }
  } catch (e) {
    print('Failed to get orders: $e');
  }

  print('\n--- MONTHLY TARGETS ---');
  try {
    final targets = await client.from('monthly_targets').select();
    for (var t in targets) {
      print('ID: ${t['id']}, Staff Device ID: ${t['staff_device_id']}, Month: ${t['month']}, Year: ${t['year']}, Target: ${t['target_amount']}');
    }
  } catch (e) {
    print('Failed to get targets: $e');
  }
}
