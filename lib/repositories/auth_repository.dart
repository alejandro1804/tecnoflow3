// lib/repositories/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class AuthRepository {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStream => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    String rol = 'tecnico',
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'nombre': nombre, 'rol': rol},
    );
  }

  Future<void> signOut() async => _client.auth.signOut();

  Future<Usuario?> getMyProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final data = await _client
        .from('usuarios')
        .select('*, roles(nombre)')
        .eq('id', uid)
        .maybeSingle();
    return data == null ? null : Usuario.fromMap(data);
  }
}
