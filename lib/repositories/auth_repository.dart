// lib/repositories/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class AuthRepository {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStream => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    // Registrar último acceso en UTC (el servidor siempre guarda en UTC)
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      await _client.from('usuarios').update({
        'ultimo_acceso': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    }
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String nombre,
    required String rolNombre,
  }) async {
    if (_client.auth.currentSession == null) throw Exception('Sin sesión activa');

    final response = await _client.functions.invoke(
      'create-user',
      body: {
        'email': email,
        'password': password,
        'nombre': nombre,
        'rolNombreNuevo': rolNombre,
      },
    );

    if (response.status != 200) {
      final msg = response.data?['error'] ?? 'Error al crear usuario';
      throw Exception(msg);
    }
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
