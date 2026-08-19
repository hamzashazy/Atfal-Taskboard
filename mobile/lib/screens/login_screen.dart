import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../meta.dart';
import '../models.dart';
import '../push.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _obscure = ValueNotifier<bool>(true);
  String _error = '';
  bool _busy = false;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _obscure.dispose();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final data = await rpc('atfal_login', {
        'p_username': _username.text.trim(),
        'p_password': _password.text,
      });
      final user = SessionUser.fromJson(Map<String, dynamic>.from(data as Map));
      await Session.set(user);
      unawaited(Push.registerForCurrentUser());
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
          user.isAdmin ? '/admin' : '/city', (route) => false);
    } catch (e) {
      setState(() {
        _error = errMsg(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // gradient hero backdrop
          Container(
            height: 260,
            decoration: const BoxDecoration(gradient: C.heroGradient),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
                    const Text('Atfal Taskboard',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('one platform, every city',
                        style: TextStyle(
                            fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sign in',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            const Text(
                              'City heads and admins only.',
                              style: TextStyle(fontSize: 13, color: C.gray500),
                            ),
                            const FieldLabel('Username'),
                            TextField(
                              controller: _username,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              autofillHints: const [AutofillHints.username],
                              decoration:
                                  inputDecoration(icon: Icons.person_outline_rounded),
                              textInputAction: TextInputAction.next,
                            ),
                            const FieldLabel('Password'),
                            ValueListenableBuilder<bool>(
                              valueListenable: _obscure,
                              builder: (context, obscure, _) => TextField(
                                controller: _password,
                                obscureText: obscure,
                                autofillHints: const [AutofillHints.password],
                                decoration: inputDecoration(icon: Icons.lock_outline_rounded)
                                    .copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: C.gray400),
                                    onPressed: () => _obscure.value = !obscure,
                                  ),
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              child: _error.isEmpty
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded,
                                              size: 16, color: C.red600),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(_error,
                                                style: const TextStyle(
                                                    fontSize: 13, color: C.red600)),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Login'),
                              ),
                            ),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pushNamed('/signup'),
                                child: const Text.rich(TextSpan(
                                  text: 'New city head? ',
                                  style: TextStyle(fontSize: 13, color: C.gray500),
                                  children: [
                                    TextSpan(
                                        text: 'Request access',
                                        style: TextStyle(
                                            color: C.emerald700, fontWeight: FontWeight.w600)),
                                  ],
                                )),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Atfal Taskboard · one platform, every city',
                        style: TextStyle(fontSize: 11, color: C.gray400)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
