import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ffvvvpkdcorvpzeuuyye.supabase.co',
    'sb_publishable_el8E3VxIXjqZPzetNt9Smw_l_5m-lVS',
  );

  final tablesToCheck = ['inventory', 'items', 'products', 'settings', 'product_list'];
  for (final table in tablesToCheck) {
    try {
      final res = await client.from(table).select().limit(1);
      print('SUCCESS for $table: $res');
    } catch (e) {
      print('FAIL for $table: $e');
    }
  }
}
