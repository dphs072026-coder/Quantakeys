import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_sync_service.dart';
import '../config/supabase_config.dart';
import '../providers/custom_layout_provider.dart';
import '../providers/settings_provider.dart';
import 'settings_page.dart';

class SignInPage extends StatefulWidget {
  final bool initialIsSignUp;
  const SignInPage({super.key, this.initialIsSignUp = false});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final CloudSyncService _cloudSync = CloudSyncService();
  bool _isLoading = false;
  bool _isSignUpMode = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isSignUpMode = widget.initialIsSignUp;
    _checkWebSession();

    // Listen to real-time auth state changes (e.g., Google OAuth deep-link callback)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session?.user != null && mounted) {
        _handleSuccessfulAuth(data.session!.user.email ?? 'User');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWebSession();
    }
  }

  Future<void> _checkWebSession() async {
    try {
      await _cloudSync.ensureSession();
      if (_cloudSync.isSignedIn) {
        if (!mounted) return;
        _handleSuccessfulAuth(_cloudSync.currentUser?.email ?? 'User');
      }
    } catch (_) {}
  }

  Future<void> _handleSuccessfulAuth(String email) async {
    if (!mounted) return;
    try {
      await _cloudSync.linkDeviceToUser(email);
      if (!mounted) return;

      // Save session tokens to SharedPreferences for cross-process IME persistence
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('supabase_session_json', json.encode({
            'access_token': session.accessToken,
            'refresh_token': session.refreshToken,
          }));
          await prefs.setString('supabase_access_token', session.accessToken);
          await prefs.setString('supabase_refresh_token', session.refreshToken ?? '');
        }
      } catch (_) {}

      try {
        const MethodChannel('com.quantakeys/ime').invokeMethod('notifySettingsChanged');
      } catch (_) {}

      final customProvider = context.read<CustomLayoutProvider>();
      await customProvider.syncWithCloud();
      if (!mounted) return;
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.loadSettings();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully signed in as $email! Layouts & AI synced.'))
      );
    } catch (e) {
      debugPrint("Auth success sync error: $e");
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final launched = await _cloudSync.signInWithGoogle();
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Sign-In. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete sign in in the browser. You will be logged in automatically!'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openSignUpWeb() async {
    try {
      final deviceId = await _cloudSync.getPermanentDeviceId();
      final uri = Uri.parse('https://quantakeys.edgeone.dev/quantakeys-login-supabase.html?device_id=$deviceId#signup');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open sign up page: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      if (_isSignUpMode) {
        if (email.isEmpty || password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter both email and password.'), backgroundColor: Colors.orange),
          );
          setState(() => _isLoading = false);
          return;
        }
        final user = await _cloudSync.signUpWithEmail(email, password);
        if (!mounted) return;
        if (user != null) {
          await _cloudSync.linkDeviceToUser(email);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please check your email inbox to confirm your account (or sign in if already confirmed).'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
          setState(() => _isSignUpMode = false);
        }
      } else {
        // SIGN IN MODE: Check Supabase to see if this device has registered their email
        final registeredEmail = await _cloudSync.getRegisteredEmailForDevice();
        if (!mounted) return;

        if (registeredEmail != null && registeredEmail.isNotEmpty) {
          if (email.isEmpty) {
            _emailController.text = registeredEmail;
          }
          final targetEmail = _emailController.text.trim();

          if (password.isEmpty) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registered account found ($registeredEmail). Please enter your password to sign in.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }

          final user = await _cloudSync.signInWithEmail(targetEmail, password);
          if (!mounted) return;
          if (user != null) {
            await _cloudSync.linkDeviceToUser(targetEmail);
            await _handleSuccessfulAuth(user.email ?? targetEmail);
          }
        } else {
          // Device has NOT registered their email in Supabase -> Prompt to sign up!
          setState(() => _isLoading = false);
          if (!mounted) return;

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Account Not Registered on Device'),
              content: const Text('No registered account was found in Supabase for this device. Please sign up on our website first!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openSignUpWeb();
                  },
                  child: const Text('Sign Up on Website'),
                ),
              ],
            ),
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
      String errorMsg = 'Auth Error: $cleanMsg';
      if (cleanMsg.toLowerCase().contains('invalid login credentials')) {
        errorMsg = 'Invalid email or password. If you signed up on our website with Google, please use "Sign In with Google".';
      } else if (cleanMsg.toLowerCase().contains('email not confirmed')) {
        errorMsg = 'Email not confirmed. Please check your email inbox for the confirmation link from Supabase.';
      } else if (cleanMsg.toLowerCase().contains('user already registered')) {
        errorMsg = 'An account with this email already exists. Please switch to "Sign In" mode.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 4))
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUpMode ? 'Sign Up for QuantaKeys' : 'Sign In to QuantaKeys'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  _isSignUpMode ? 'Create Your QuantaKeys Account' : 'Connect Your QuantaKeys Account', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), 
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 1. Website Sign Up Option Card
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Prefer Web Registration?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text('Sign up securely on our website with Google, GitHub, or Email.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Sign Up on Website'),
                            onPressed: _openSignUpWeb,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Sign In with Google Option
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                    label: const Text('Sign In with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        _isSignUpMode ? 'OR SIGN UP WITH EMAIL' : 'OR SIGN IN WITH EMAIL', 
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Email & Password Form
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _submitEmailAuth(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitEmailAuth,
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isSignUpMode ? 'Sign Up with Email' : 'Sign In with Email', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isSignUpMode = !_isSignUpMode),
                  child: Text(
                    _isSignUpMode 
                        ? 'Already have an account? Sign In' 
                        : 'Don\'t have an account? Sign Up',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
