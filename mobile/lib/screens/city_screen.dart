import 'package:flutter/material.dart';

import '../api.dart';
import '../meta.dart';
import '../models.dart';
import '../widgets.dart';

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  Map<String, Task> _tasks = {};
  List<Assignment> _assignments = [];
  bool _loading = true;
  int _tab = 0;

  SessionUser? get me => Session.current;

  @override
  void initState() {
    super.initState();
    if (me == null || !me!.isCityHead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      });
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final cityId = me?.cityId;
    if (cityId == null) return;
    try {
      final results = await Future.wait([
        sb.from('atfal_tasks').select().eq('archived', false),
        sb.from('atfal_assignments').select().eq('city_id', cityId),
      ]);
      final byId = {
        for (final t in results[0].map(Task.fromJson)) t.id: t
      };
      if (!mounted) return;
      setState(() {
        _tasks = byId;
        _assignments = results[1]
            .map(Assignment.fromJson)
            .where((a) => byId.containsKey(a.taskId))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Failed to load: ${errMsg(e)}', error: true);
    }
  }

  final _busyId = ValueNotifier<String?>(null);

  Future<void> _setStatus(String id, String status,
      {String? note, String? proof}) async {
    final s = me;
    if (s == null) return;
    _busyId.value = id;
    try {
      await rpc('atfal_update_status', {
        'p_token': s.token,
        'p_assignment_id': id,
        'p_status': status,
        'p_note': note,
        'p_proof_url': proof,
      });
      await _load();
      if (mounted) {
        showSnack(context,
            status == 'submitted' ? 'Task submitted for review.' : 'Marked as in progress.');
      }
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _busyId.value = null;
  }

  void _openSubmitSheet(Assignment a) {
    final noteCtrl = TextEditingController(text: a.note ?? '');
    final proofCtrl = TextEditingController(text: a.proofUrl ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: C.gray200, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Text('Submit — ${_tasks[a.taskId]?.title ?? ''}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const FieldLabel('Note (optional — Urdu is fine)'),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: inputDecoration(),
            ),
            const FieldLabel(
                'Proof link (Google Sheet / Drive photo — optional)'),
            TextField(
              controller: proofCtrl,
              keyboardType: TextInputType.url,
              decoration: inputDecoration(hint: 'https://...', icon: Icons.link_rounded),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _setStatus(a.id, 'submitted',
                          note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                          proof:
                              proofCtrl.text.isEmpty ? null : proofCtrl.text);
                    },
                    child: const Text('✅ Confirm submit'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = me;
    if (s == null) return const SizedBox.shrink();

    const order = {'returned': 0, 'pending': 1, 'in_progress': 2};
    final todo = _assignments
        .where((a) => order.containsKey(a.status))
        .toList()
      ..sort((x, y) {
        final byStatus = order[x.status]!.compareTo(order[y.status]!);
        if (byStatus != 0) return byStatus;
        return (_tasks[x.taskId]?.dueDate ?? '9999')
            .compareTo(_tasks[y.taskId]?.dueDate ?? '9999');
      });
    final done = _assignments
        .where((a) => a.status == 'submitted' || a.status == 'approved')
        .toList()
      ..sort((x, y) =>
          (y.submittedAt ?? '').compareTo(x.submittedAt ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: Text('📍 ${s.cityName ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed('/'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: logout,
          ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : IndexedStack(
              index: _tab,
              children: [
                _taskList(todo, editable: true,
                    emptyIcon: Icons.celebration_outlined,
                    empty: 'Nothing pending — all caught up!'),
                _taskList(done,
                    emptyIcon: Icons.inbox_outlined,
                    empty: 'Nothing submitted yet.'),
                _AccountTab(me: s, onProfileSaved: () => setState(() {})),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: todo.isEmpty
                ? const Icon(Icons.checklist_outlined)
                : Badge(
                    label: Text('${todo.length}'),
                    child: const Icon(Icons.checklist_outlined)),
            selectedIcon: const Icon(Icons.checklist_rounded),
            label: 'To Do',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: (s.email == null || s.contactNo == null)
                ? const Badge(child: Icon(Icons.person_outline_rounded))
                : const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Widget _taskList(List<Assignment> list,
      {bool editable = false, required IconData emptyIcon, required String empty}) {
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: list.isEmpty
            ? [EmptyState(icon: emptyIcon, title: empty)]
            : [
                for (final a in list) _taskCard(a, editable: editable),
              ],
      ),
    );
  }

  Widget _taskCard(Assignment a, {bool editable = false}) {
    final t = _tasks[a.taskId];
    if (t == null) return const SizedBox.shrink();
    final od = isOverdue(t, a.status);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      leftBorder: od ? C.red500 : C.gray200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CategoryChip(category: t.category),
              StatusChip(status: a.status),
              if (od) const OverdueChip(),
              Text('Due: ${fmtDate(t.dueDate)}',
                  style: const TextStyle(fontSize: 12, color: C.gray400)),
            ],
          ),
          if (t.description != null && t.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.description!,
                style: const TextStyle(fontSize: 14, color: C.gray600)),
          ],
          if (t.attachmentUrl != null && t.attachmentUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => openUrl(t.attachmentUrl!),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_file_rounded, size: 15, color: C.brand700),
                    SizedBox(width: 4),
                    Text('Task attachment / form',
                        style: TextStyle(
                            fontSize: 13.5,
                            color: C.brand700,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          if (a.status == 'returned' &&
              a.reviewNote != null &&
              a.reviewNote!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.red50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: C.red700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Returned by admin: ${a.reviewNote}',
                        style: const TextStyle(fontSize: 13, color: C.red700)),
                  ),
                ],
              ),
            ),
          if (a.proofUrl != null && a.proofUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => openUrl(a.proofUrl!),
                child: Text('Your proof: ${a.proofUrl}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        color: C.gray400,
                        decoration: TextDecoration.underline)),
              ),
            ),
          if (a.note != null && a.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Your note: ${a.note}',
                  style: const TextStyle(fontSize: 12, color: C.gray400)),
            ),
          if (editable) ...[
            const SizedBox(height: 12),
            ValueListenableBuilder<String?>(
              valueListenable: _busyId,
              builder: (context, busyId, _) {
                final busy = busyId == a.id;
                return Wrap(
                  spacing: 8,
                  children: [
                    if (a.status == 'pending')
                      FilledButton.icon(
                        onPressed: busy ? null : () => _setStatus(a.id, 'in_progress'),
                        icon: busy
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Start'),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.amber600),
                      onPressed: busy ? null : () => _openSubmitSheet(a),
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: Text(
                          'Submit${a.status == 'returned' ? ' again' : ''}'),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountTab extends StatelessWidget {
  final SessionUser me;
  final VoidCallback onProfileSaved;
  const _AccountTab({required this.me, required this.onProfileSaved});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: C.heroGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(me.displayName.isNotEmpty ? me.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${me.cityName ?? ''} · City Head',
                        style: const TextStyle(fontSize: 12, color: C.gray500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _ProfileSection(me: me, onSaved: onProfileSaved),
        const SizedBox(height: 12),
        _ChangePassword(token: me.token),
      ],
    );
  }
}

class _ProfileSection extends StatefulWidget {
  final SessionUser me;
  final VoidCallback onSaved;
  const _ProfileSection({required this.me, required this.onSaved});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  late final _email = TextEditingController(text: widget.me.email ?? '');
  late final _contactNo = TextEditingController(text: widget.me.contactNo ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _contactNo.dispose();
    super.dispose();
  }

  bool get _incomplete => widget.me.email == null || widget.me.contactNo == null;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final data = await rpc('atfal_update_profile', {
        'p_token': widget.me.token,
        'p_email': _email.text,
        'p_contact_no': _contactNo.text,
      });
      final j = Map<String, dynamic>.from(data as Map);
      await Session.set(widget.me.copyWith(
          email: j['email'] as String?, contactNo: j['contact_no'] as String?));
      widget.onSaved();
      if (mounted) showSnack(context, 'Profile updated.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_incomplete ? Icons.warning_amber_rounded : Icons.badge_outlined,
                  size: 18, color: _incomplete ? C.amber600 : C.brand700),
              const SizedBox(width: 8),
              Text(_incomplete ? 'Complete your profile' : 'Your profile',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          if (_incomplete)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Add your email and masool number so the markaz can reach you directly.',
                style: TextStyle(fontSize: 12.5, color: C.gray500),
              ),
            ),
          const FieldLabel('Email'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: inputDecoration(hint: 'you@example.com', icon: Icons.mail_outline_rounded),
          ),
          const FieldLabel('Masool number'),
          TextField(
            controller: _contactNo,
            keyboardType: TextInputType.phone,
            decoration: inputDecoration(hint: '03xx-xxxxxxx', icon: Icons.call_outlined),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save profile'),
          ),
        ],
      ),
    );
  }
}

class _ChangePassword extends StatefulWidget {
  final String token;
  const _ChangePassword({required this.token});

  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  String? _msg;
  bool _ok = false;
  bool _busy = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_new.text.length < 6) {
      setState(() {
        _ok = false;
        _msg = 'Password must be at least 6 characters';
      });
      return;
    }
    setState(() {
      _msg = null;
      _busy = true;
    });
    try {
      await rpc('atfal_change_password', {
        'p_token': widget.token,
        'p_old': _old.text,
        'p_new': _new.text,
      });
      setState(() {
        _ok = true;
        _msg = 'Password updated ✔';
      });
      _old.clear();
      _new.clear();
    } catch (e) {
      setState(() {
        _ok = false;
        _msg = errMsg(e);
      });
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_reset_rounded, size: 18, color: C.brand700),
              SizedBox(width: 8),
              Text('Change password',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const FieldLabel('Current password'),
          TextField(
              controller: _old,
              obscureText: true,
              decoration: inputDecoration(icon: Icons.lock_outline_rounded)),
          const FieldLabel('New password (min 6 characters)'),
          TextField(
              controller: _new,
              obscureText: true,
              decoration: inputDecoration(icon: Icons.key_outlined)),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_msg!,
                  style: TextStyle(
                      fontSize: 14,
                      color: _ok ? C.brand700 : C.red600)),
            ),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update password')),
        ],
      ),
    );
  }
}
