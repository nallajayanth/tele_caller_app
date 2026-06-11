// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'package:supabase/supabase.dart';

void main() async {
  print('========================================');
  print('🛠️ MedTrac Pro — Supabase Diagnostic Check');
  print('========================================');
  
  final client = SupabaseClient(
    'https://ffvvvpkdcorvpzeuuyye.supabase.co',
    'sb_publishable_el8E3VxIXjqZPzetNt9Smw_l_5m-lVS',
  );

  try {
    print('📡 Connecting to Supabase and checking "call_logs" table...');
    final data = await client.from('call_logs').select().limit(1);
    print('🎉 DATABASE CONNECTION PERFECT! SUCCESS!');
    print('ℹ️ Records found in call_logs: ${data.length}');
    print('========================================');
  } catch (e) {
    print('❌ DATABASE CONNECTION FAILED!');
    print('========================================');
    print('⚠️ Error Details:');
    print(e);
    print('========================================');
    print('💡 Troubleshooting Checklist:');
    print('1. Have you run the SQL schema scripts in the Supabase SQL editor?');
    print('2. Are the database tables "call_logs" and "deleted_logs" created?');
    print('3. Are your RLS policies correctly configured (or disabled for testing)?');
    print('========================================');
  }
}
