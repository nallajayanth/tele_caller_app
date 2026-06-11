import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/models/call_log_model.dart';
import 'data/models/deleted_log_model.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Cloud Database
  await Supabase.initialize(
    url: 'https://ffvvvpkdcorvpzeuuyye.supabase.co',
    anonKey: 'sb_publishable_el8E3VxIXjqZPzetNt9Smw_l_5m-lVS',
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await Hive.initFlutter();
  Hive.registerAdapter(CallLogModelAdapter());
  Hive.registerAdapter(DeletedLogModelAdapter());
  await Hive.openBox<CallLogModel>('call_logs');
  await Hive.openBox<DeletedLogModel>('deleted_logs');
  await Hive.openBox('settings');

  runApp(const ProviderScope(child: TelecallerApp()));
}
