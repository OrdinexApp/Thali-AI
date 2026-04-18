import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/api_config.dart';

class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: ApiConfig.supabaseUrl,
      anonKey: ApiConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
