import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/key_layout.dart';
import '../config/supabase_config.dart';

class CloudSyncService {
  bool get isSignedIn {
    try {
      final auth = Supabase.instance.client.auth;
      return auth.currentSession != null || auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  User? get currentUser {
    try {
      final auth = Supabase.instance.client.auth;
      return auth.currentUser ?? auth.currentSession?.user;
    } catch (_) {
      return null;
    }
  }

  Future<void> ensureSession() async {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null && auth.currentUser == null) {
        await auth.refreshSession();
      }
    } catch (_) {}
  }

  /// Sign in with Google (Direct Supabase authorize URL with external application launch)
  Future<bool> signInWithGoogle() async {
    try {
      final authUrl = '${SupabaseConfig.url}/auth/v1/authorize?provider=google&redirect_to=io.supabase.quantakeys://login-callback';
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint("Supabase Google Sign-In Error: $e");
      return false;
    }
  }

  /// Sign in with Email and Password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return res.user;
    } catch (e) {
      debugPrint("Supabase Email Sign-In Error: $e");
      rethrow;
    }
  }

  /// Sign up with Email and Password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return res.user;
    } catch (e) {
      debugPrint("Supabase Email Sign-Up Error: $e");
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint("Supabase Sign-Out Error: $e");
    }
  }

  /// Delete a single custom layout from Supabase when explicitly removed by user
  Future<void> deleteCloudLayout(String layoutName) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final client = Supabase.instance.client;
      await client
          .from('user_layouts')
          .delete()
          .eq('user_id', user.id)
          .eq('layout_name', layoutName);
      debugPrint("Deleted custom layout '$layoutName' from cloud.");
    } catch (e) {
      debugPrint("Error deleting layout from cloud: $e");
    }
  }

  /// Sync custom layouts to Supabase PostgreSQL (upserting local layouts)
  Future<void> uploadLayouts(List<KeyLayout> layouts) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final client = Supabase.instance.client;
      // Upsert current local layouts without blindly wiping cloud layouts
      for (var layout in layouts) {
        await client.from('user_layouts').upsert({
          'user_id': user.id,
          'layout_name': layout.name,
          'layout_data': layout.toJson(),
        }, onConflict: 'user_id,layout_name');
      }
      debugPrint("Layouts successfully uploaded and synced to Supabase.");
    } catch (e) {
      debugPrint("Supabase Layout Upload Error: $e");
    }
  }

  /// Fetch custom layouts from Supabase PostgreSQL
  Future<List<KeyLayout>> downloadLayouts() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('user_layouts')
          .select('layout_data')
          .eq('user_id', user.id);

      List<KeyLayout> cloudLayouts = [];
      for (var row in response) {
        try {
          final data = row['layout_data'];
          if (data != null) {
            cloudLayouts.add(KeyLayout.fromJson(data is String ? jsonDecode(data) : data));
          }
        } catch (_) {}
      }
      return cloudLayouts;
    } catch (e) {
      debugPrint("Supabase Layout Download Error: $e");
      return [];
    }
  }

  Future<String> _getPermanentHardwareDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.id.isNotEmpty) {
          return 'hw_android_${androidInfo.id}';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        if (iosInfo.identifierForVendor != null) {
          return 'hw_ios_${iosInfo.identifierForVendor}';
        }
      }
    } catch (_) {}
    return 'hw_fallback_device';
  }

  Future<String> getPermanentDeviceId() async {
    return _getPermanentHardwareDeviceId();
  }

  /// Check in Supabase if the respective device has registered their email
  Future<String?> getRegisteredEmailForDevice() async {
    try {
      final deviceId = await _getPermanentHardwareDeviceId();
      final client = Supabase.instance.client;
      final res = await client
          .from('device_registrations')
          .select('email')
          .eq('device_id', deviceId)
          .maybeSingle();
      if (res != null && res['email'] != null) {
        return res['email'].toString();
      }
    } catch (e) {
      debugPrint("Error checking device registration: $e");
    }
    return null;
  }

  /// Link current device ID to user email in Supabase device_registrations table
  Future<void> linkDeviceToUser(String email) async {
    try {
      final deviceId = await _getPermanentHardwareDeviceId();
      final user = currentUser;
      final client = Supabase.instance.client;
      await client.from('device_registrations').upsert({
        'device_id': deviceId,
        'email': email.trim(),
        'user_id': user?.id,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'device_id');
      debugPrint("Device $deviceId successfully linked to email $email in Supabase.");
    } catch (e) {
      debugPrint("Error linking device to user: $e");
    }
  }

  /// Get daily AI usage count and purchased credits from Supabase
  /// (Purchased credits are strictly tied to user email; Daily free limit is also backed by permanent hardware ID for guests)
  Future<Map<String, int>> getCloudUsageAndCredits() async {
    final user = currentUser;
    final today = DateTime.now().toIso8601String().split('T')[0];
    int usageCount = 0;
    int purchasedCredits = 0;
    final client = Supabase.instance.client;

    try {
      // 1. If signed in, get user account usage & purchased credits
      if (user != null) {
        final res = await client
            .from('user_usage')
            .select('usage_count, purchased_credits, last_reset_date')
            .eq('user_id', user.id)
            .maybeSingle();
        if (res != null) {
          if (res['last_reset_date'] == today) {
            usageCount = max(usageCount, res['usage_count'] ?? 0);
          }
          purchasedCredits = max(purchasedCredits, res['purchased_credits'] ?? 0);
        }
      }

      // 2. Always check permanent hardware device for daily usage (prevents guest clear data bypass)
      final deviceId = await _getPermanentHardwareDeviceId();
      final resDev = await client
          .from('device_usage')
          .select('usage_count, last_reset_date')
          .eq('device_id', deviceId)
          .maybeSingle();
      if (resDev != null && resDev['last_reset_date'] == today) {
        usageCount = max(usageCount, resDev['usage_count'] ?? 0);
      }
    } catch (e) {
      debugPrint("Supabase Usage/Credits Fetch Error: $e");
    }

    return {
      'usageCount': usageCount,
      'purchasedCredits': purchasedCredits,
    };
  }

  Future<int> getCloudUsageCount() async {
    final data = await getCloudUsageAndCredits();
    return data['usageCount'] ?? 0;
  }

  /// Update daily AI usage count and persistent purchased credits in Supabase
  Future<void> updateUsageAndCredits(int usageCount, int purchasedCredits) async {
    final user = currentUser;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final client = Supabase.instance.client;

    try {
      // If signed in, update user account (tied to email for purchased credits)
      if (user != null) {
        await client.from('user_usage').upsert({
          'user_id': user.id,
          'usage_count': usageCount,
          'purchased_credits': purchasedCredits,
          'last_reset_date': today,
        }, onConflict: 'user_id');
      }

      // Always update permanent hardware device usage (protects guests against clear data bypass)
      final deviceId = await _getPermanentHardwareDeviceId();
      await client.from('device_usage').upsert({
        'device_id': deviceId,
        'usage_count': usageCount,
        'last_reset_date': today,
      }, onConflict: 'device_id');
    } catch (e) {
      debugPrint("Supabase Usage & Credits Update Error: $e");
    }
  }

  Future<void> incrementCloudUsageCount(int newCount) async {
    await updateUsageAndCredits(newCount, 0);
  }
}
