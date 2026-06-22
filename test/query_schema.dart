import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ffvvvpkdcorvpzeuuyye.supabase.co',
    'sb_publishable_el8E3VxIXjqZPzetNt9Smw_l_5m-lVS',
  );

  try {
    final res = await client.from('information_schema.tables').select().limit(1);
    print('SUCCESS: Schema tables: $res');
  } catch (e) {
    print('FAIL information_schema: $e');
  }

  try {
    final res = await client.from('pg_tables').select().limit(1);
    print('SUCCESS: pg_tables: $res');
  } catch (e) {
    print('FAIL pg_tables: $e');
  }
}
