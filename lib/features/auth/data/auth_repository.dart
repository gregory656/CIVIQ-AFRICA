import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final currentAuthUserIdProvider = StateProvider<String?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (email.contains('@')) {
      return _client.auth.signInWithPassword(email: email, password: password);
    }
    final response = await _client.functions.invoke(
      'sign-in-with-username',
      body: {'username': email, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = Map<String, dynamic>.from(data['session'] as Map);
    return _client.auth.setSession(session['refresh_token'] as String);
  }

  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'https://siviq.top/app/login',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    await _markOffline();
    await _client.auth.signOut();
  }

  Future<void> signOutOtherSessions() async {
    await _client.auth.signOut(scope: SignOutScope.others);
  }

  Future<void> signOutAllSessions() async {
    await _markOffline();
    await _client.auth.signOut(scope: SignOutScope.global);
  }

  Future<void> _markOffline() async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc(
        'update_profile_presence',
        params: {'online_now': false},
      );
    } catch (_) {
      // Presence is best-effort during logout; auth cleanup must still finish.
    }
  }
}
