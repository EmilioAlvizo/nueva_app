// lib/core/supebase/supebase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

//final supabase = Supabase.instance.client;

/// Single point of access to the Supabase client.
SupabaseClient get supabase => Supabase.instance.client;