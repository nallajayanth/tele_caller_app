import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ffvvvpkdcorvpzeuuyye.supabase.co',
    'sb_publishable_el8E3VxIXjqZPzetNt9Smw_l_5m-lVS',
  );

  print('Checking if products table exists...');
  try {
    final res = await client.from('products').select().limit(1);
    print('SUCCESS: Products table exists! Data: $res');
  } catch (e) {
    print('Failed or table does not exist: $e');
  }
}
