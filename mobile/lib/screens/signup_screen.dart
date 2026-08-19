import 'package:flutter/material.dart';

import '../api.dart';
import '../meta.dart';
import '../models.dart';
import '../widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _contactNo = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  List<City> _cities = [];
  int? _cityId;
  String _error = '';
  bool _busy = false;
  bool _loadingCities = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final data = await sb.from('atfal_cities').select().eq('active', true).order('name');
      if (!mounted) return;
      setState(() {
        _cities = (data as List).map((j) => City.fromJson(Map<String, dynamic>.from(j as Map))).toList();
        _loadingCities = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _contactNo.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    if (_cityId == null) {
      setState(() => _error = 'Select your city.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }
    setState(() => _busy = true);
    try {
      await rpc('atfal_signup', {
        'p_full_name': _fullName.text,
        'p_email': _email.text,
        'p_contact_no': _contactNo.text,
        'p_city_id': _cityId,
        'p_password': _password.text,
      });
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = errMsg(e));
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request access')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _done ? _doneCard() : _formCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doneCard() {
    return AppCard(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.emerald50, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.check_circle_rounded, color: C.emerald700, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('Request submitted',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            "An admin will review your request. You'll get an email once it's approved — "
            'then you can sign in with the email and password you just chose.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.gray500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false),
              child: const Text('Back to sign in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('For city heads without an account yet.',
              style: TextStyle(fontSize: 13, color: C.gray500)),
          const Text('An admin reviews every request before it becomes active.',
              style: TextStyle(fontSize: 13, color: C.gray500)),
          const FieldLabel('Full name'),
          TextField(
            controller: _fullName,
            decoration: inputDecoration(icon: Icons.badge_outlined),
            textInputAction: TextInputAction.next,
          ),
          const FieldLabel('Email'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            autofillHints: const [AutofillHints.email],
            decoration: inputDecoration(icon: Icons.mail_outline_rounded),
            textInputAction: TextInputAction.next,
          ),
          const FieldLabel('Contact number'),
          TextField(
            controller: _contactNo,
            keyboardType: TextInputType.phone,
            decoration: inputDecoration(icon: Icons.call_outlined),
            textInputAction: TextInputAction.next,
          ),
          const FieldLabel('City'),
          _loadingCities
              ? const SkeletonBox(height: 48, radius: BorderRadius.all(Radius.circular(12)))
              : DropdownButtonFormField<int>(
                  initialValue: _cityId,
                  decoration: inputDecoration(icon: Icons.location_city_outlined),
                  hint: const Text('Select your city…'),
                  items: [
                    for (final c in _cities) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _cityId = v),
                ),
          const FieldLabel('Password'),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: inputDecoration(icon: Icons.lock_outline_rounded),
            textInputAction: TextInputAction.next,
          ),
          const FieldLabel('Confirm password'),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: inputDecoration(icon: Icons.lock_outline_rounded),
            onSubmitted: (_) => _submit(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: _error.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: C.red600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_error, style: const TextStyle(fontSize: 13, color: C.red600)),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Request access'),
            ),
          ),
        ],
      ),
    );
  }
}
