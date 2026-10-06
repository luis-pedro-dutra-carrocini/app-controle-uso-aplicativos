// lib/screens/password_screen.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasswordScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const PasswordScreen({super.key, required this.onAuthenticated});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _isFirstTime = true;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkIfPasswordExists();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _checkIfPasswordExists() async {
    final saved = await _storage.read(key: 'password_hash');
    if (!mounted) return;
    setState(() {
      _isFirstTime = saved == null;
      _isLoading = false;
    });
  }

  /// Gera hash da senha + salt
  /// Nota: Em produção, considere usar PBKDF2 ou bcrypt, não SHA-256 puro
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  Future<void> _createPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 4) {
      setState(() => _errorMessage = 'A senha deve ter pelo menos 4 caracteres');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'As senhas não coincidem');
      return;
    }

    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = _hashPassword(password, salt);

    await _storage.write(key: 'password_hash', value: hash);
    await _storage.write(key: 'password_salt', value: salt);

    if (!mounted) return;
    widget.onAuthenticated();
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Digite sua senha');
      return;
    }

    final savedHash = await _storage.read(key: 'password_hash');
    final salt = await _storage.read(key: 'password_salt');
    if (savedHash == null || salt == null) {
      setState(() => _errorMessage = 'Erro interno');
      return;
    }

    final inputHash = _hashPassword(password, salt);
    if (inputHash == savedHash) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _errorMessage = 'Senha incorreta';
        _passwordController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // Deixa o Scaffold redimensionar quando o teclado abre
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // Permite scroll quando o teclado ocupa espaço
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                // Garante altura mínima = altura visível da tela
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        _isFirstTime ? Icons.lock_outline : Icons.lock,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isFirstTime ? 'Crie sua senha' : 'Digite sua senha',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: _isFirstTime
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isFirstTime) _verifyPassword();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_isFirstTime) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _createPassword(),
                          decoration: const InputDecoration(
                            labelText: 'Confirmar senha',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _isFirstTime ? _createPassword : _verifyPassword,
                          child: Text(_isFirstTime ? 'Continuar' : 'Entrar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}