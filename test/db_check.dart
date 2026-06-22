// ignore_for_file: avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ffvvvpkdcorvpzeuuyye.supabase.co',
    'sb_publishable_el8E3VxIXjqZPzetNt9Smw_l_5m-lVS',
  );

  print('--- SELECTING SPECIFIC COLUMNS TO VERIFY ---');
  try {
    final res = await client.from('orders').select('id, call_log_id, customer_name, product, order_value, status, packed_photo_url, dispatched_photo_url, logistics_provider, tracking_id, assigned_staff_device_id, created_at, updated_at').limit(0);
    print('orders columns: VERIFIED SUCCESS! $res');
  } catch (e) {
    print('orders columns verification failed: $e');
  }

  try {
    final res = await client.from('monthly_targets').select('id, staff_device_id, month, year, target_amount, set_at').limit(0);
    print('monthly_targets columns: VERIFIED SUCCESS! $res');
  } catch (e) {
    print('monthly_targets columns verification failed: $e');
  }
}
