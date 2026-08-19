import 'package:flutter/material.dart';

import '../api.dart';
import '../meta.dart';
import '../models.dart';
import '../widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<City> _cities = [];
  List<Task> _tasks = [];
  List<Assignment> _assignments = [];
  List<UserRow> _users = [];
  List<SignupRequest> _signups = [];
  bool _loading = true;
  int _tab = 0;

  SessionUser? get me => Session.current;

  @override
  void initState() {
    super.initState();
    if (me == null || !me!.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      });
    } else {
      _load();
      _loadUsers();
      _loadSignups();
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        sb.from('atfal_cities').select().order('name', ascending: true),
        sb
            .from('atfal_tasks')
            .select()
            .order('created_at', ascending: false),
        sb.from('atfal_assignments').select(),
      ]);
      if (!mounted) return;
      setState(() {
        _cities = results[0].map(City.fromJson).toList();
        _tasks = results[1].map(Task.fromJson).toList();
        _assignments = results[2].map(Assignment.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Failed to load: ${errMsg(e)}', error: true);
    }
  }

  Future<void> _loadUsers() async {
    final s = me;
    if (s == null) return;
    try {
      final data = await rpc('atfal_list_users', {'p_token': s.token});
      if (!mounted) return;
      setState(() => _users = (data as List)
          .map((j) => UserRow.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList());
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
  }

  Future<void> _loadSignups() async {
    final s = me;
    if (s == null) return;
    try {
      final data = await rpc(
          'atfal_list_signup_requests', {'p_token': s.token, 'p_status': 'pending'});
      if (!mounted) return;
      setState(() => _signups = (data as List)
          .map((j) => SignupRequest.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList());
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = me;
    if (s == null) return const SizedBox.shrink();

    final reviewQueue = _assignments
        .where((a) => a.status == 'submitted')
        .toList()
      ..sort((x, y) =>
          (x.submittedAt ?? '').compareTo(y.submittedAt ?? ''));

    const titles = ['New Task', 'Review', 'All Tasks', 'Cities', 'Users', 'Signups'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/'),
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
                _NewTaskTab(me: s, cities: _cities, onCreated: _load),
                _reviewTab(s, reviewQueue),
                _allTasksTab(s),
                _citiesTab(s),
                _usersTab(s),
                _signupsTab(s),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'New',
          ),
          NavigationDestination(
            icon: reviewQueue.isEmpty
                ? const Icon(Icons.fact_check_outlined)
                : Badge(
                    label: Text('${reviewQueue.length}'),
                    child: const Icon(Icons.fact_check_outlined)),
            selectedIcon: const Icon(Icons.fact_check_rounded),
            label: 'Review',
          ),
          const NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.location_city_outlined),
            selectedIcon: Icon(Icons.location_city_rounded),
            label: 'Cities',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          NavigationDestination(
            icon: _signups.isEmpty
                ? const Icon(Icons.person_add_alt_outlined)
                : Badge(
                    label: Text('${_signups.length}'),
                    child: const Icon(Icons.person_add_alt_outlined)),
            selectedIcon: const Icon(Icons.person_add_rounded),
            label: 'Signups',
          ),
        ],
      ),
    );
  }

  /* ---------- Review ---------- */

  final _reviewNotes = <String, TextEditingController>{};
  final _reviewBusyId = ValueNotifier<String?>(null);

  TextEditingController _noteCtrl(String id) =>
      _reviewNotes.putIfAbsent(id, TextEditingController.new);

  Future<void> _review(SessionUser s, String id, String status) async {
    final note = _noteCtrl(id).text;
    if (status == 'returned' && note.isEmpty) {
      showSnack(context, 'Add a review note so the city knows what to fix.',
          error: true);
      return;
    }
    _reviewBusyId.value = id;
    try {
      await rpc('atfal_update_status', {
        'p_token': s.token,
        'p_assignment_id': id,
        'p_status': status,
        'p_review_note': note.isEmpty ? null : note,
      });
      _reviewNotes.remove(id)?.dispose();
      await _load();
      if (mounted) {
        showSnack(context,
            status == 'approved' ? 'Submission approved.' : 'Sent back to city.');
      }
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _reviewBusyId.value = null;
  }

  Widget _reviewTab(SessionUser s, List<Assignment> queue) {
    final taskById = {for (final t in _tasks) t.id: t};
    final cityById = {for (final c in _cities) c.id: c};
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: queue.isEmpty
            ? [
                const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No submissions waiting for review.'),
              ]
            : [
                for (final a in queue)
                  _reviewCard(s, a, taskById[a.taskId], cityById[a.cityId]),
              ],
      ),
    );
  }

  Widget _reviewCard(SessionUser s, Assignment a, Task? t, City? c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: '${t?.title ?? '?'} — ',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            children: [
              TextSpan(
                  text: c?.name ?? '?',
                  style: const TextStyle(color: C.brand700)),
            ],
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (t != null) CategoryChip(category: t.category),
              StatusChip(status: a.status),
              Text(
                'Submitted: ${a.submittedAt != null ? fmtTime(a.submittedAt!) : '—'}',
                style: const TextStyle(fontSize: 12, color: C.gray400),
              ),
            ],
          ),
          if (a.note != null && a.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Note: ${a.note}',
                  style: const TextStyle(fontSize: 14, color: C.gray600)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: a.proofUrl != null && a.proofUrl!.isNotEmpty
                ? InkWell(
                    onTap: () => openUrl(a.proofUrl!),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, size: 15, color: C.brand700),
                        SizedBox(width: 4),
                        Text('Open proof',
                            style: TextStyle(
                                fontSize: 13.5,
                                color: C.brand700,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : const Text('No proof link attached.',
                    style: TextStyle(fontSize: 12, color: C.gray400)),
          ),
          const FieldLabel('Review note (required if returning)'),
          TextField(
            controller: _noteCtrl(a.id),
            decoration:
                inputDecoration(hint: 'Feedback for the city head…'),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String?>(
            valueListenable: _reviewBusyId,
            builder: (context, busyId, _) {
              final busy = busyId == a.id;
              return Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => _review(s, a.id, 'approved'),
                    icon: busy
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD03B3B)),
                    onPressed: busy ? null : () => _review(s, a.id, 'returned'),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Return'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /* ---------- All Tasks ---------- */

  final _taskBusyId = ValueNotifier<String?>(null);

  Future<void> _archive(SessionUser s, String id, bool archived) async {
    _taskBusyId.value = id;
    try {
      await rpc('atfal_archive_task',
          {'p_token': s.token, 'p_task_id': id, 'p_archived': archived});
      await _load();
      if (mounted) showSnack(context, archived ? 'Task archived.' : 'Task unarchived.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _taskBusyId.value = null;
  }

  Future<void> _delete(SessionUser s, Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
            'Delete "${t.title}" for ALL cities? This cannot be undone. '
            '(Archiving is usually better.)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child:
                  const Text('Delete', style: TextStyle(color: C.red600))),
        ],
      ),
    );
    if (ok != true) return;
    _taskBusyId.value = t.id;
    try {
      await rpc('atfal_delete_task', {'p_token': s.token, 'p_task_id': t.id});
      await _load();
      if (mounted) showSnack(context, 'Task deleted.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _taskBusyId.value = null;
  }

  Widget _allTasksTab(SessionUser s) {
    final counts = <String, ({int total, int approved, int submitted})>{};
    for (final a in _assignments) {
      final c = counts[a.taskId] ?? (total: 0, approved: 0, submitted: 0);
      counts[a.taskId] = (
        total: c.total + 1,
        approved: c.approved + (a.status == 'approved' ? 1 : 0),
        submitted: c.submitted + (a.status == 'submitted' ? 1 : 0),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: _tasks.isEmpty
            ? [const EmptyState(icon: Icons.checklist_outlined, title: 'No tasks yet.')]
            : [
                for (final t in _tasks)
                  Opacity(
                    opacity: t.archived ? 0.55 : 1,
                    child: AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.title}${t.archived ? ' (archived)' : ''}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              CategoryChip(category: t.category),
                              Text('Due: ${fmtDate(t.dueDate)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: C.gray400)),
                              Text(
                                '${counts[t.id]?.approved ?? 0}/${counts[t.id]?.total ?? 0} approved',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              if ((counts[t.id]?.submitted ?? 0) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: C.amber50,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '${counts[t.id]!.submitted} to review',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: C.amber700),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<String?>(
                            valueListenable: _taskBusyId,
                            builder: (context, busyId, _) {
                              final busy = busyId == t.id;
                              return Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: busy ? null : () => _archive(s, t.id, !t.archived),
                                    child: Text(
                                        t.archived ? 'Unarchive' : 'Archive'),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: C.red600),
                                    onPressed: busy ? null : () => _delete(s, t),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
      ),
    );
  }

  /* ---------- Cities ---------- */

  final _cityName = TextEditingController();
  final _cityRegion = TextEditingController();
  bool _cityBusy = false;

  Future<void> _addCity(SessionUser s) async {
    if (_cityName.text.trim().isEmpty) return;
    setState(() => _cityBusy = true);
    try {
      await rpc('atfal_create_city', {
        'p_token': s.token,
        'p_name': _cityName.text,
        'p_region': _cityRegion.text.isEmpty ? null : _cityRegion.text,
      });
      final name = _cityName.text;
      _cityName.clear();
      _cityRegion.clear();
      await _load();
      if (mounted) showSnack(context, 'City "$name" added.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    setState(() => _cityBusy = false);
  }

  Future<void> _setCityActive(SessionUser s, int id, bool active) async {
    try {
      await rpc('atfal_set_city_active',
          {'p_token': s.token, 'p_city_id': id, 'p_active': active});
      await _load();
      if (mounted) showSnack(context, active ? 'City activated.' : 'City deactivated.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
  }

  Widget _citiesTab(SessionUser s) {
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('New city name'),
                TextField(
                    controller: _cityName,
                    decoration: inputDecoration(icon: Icons.location_city_outlined)),
                const FieldLabel('Region'),
                TextField(
                    controller: _cityRegion,
                    decoration: inputDecoration(hint: 'Punjab')),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: _cityBusy ? null : () => _addCity(s),
                    icon: _cityBusy
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add')),
              ],
            ),
          ),
          for (final c in _cities)
            Opacity(
              opacity: c.active ? 1 : 0.55,
              child: AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.active ? C.brand50 : C.gray100,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.location_city_rounded,
                          size: 18, color: c.active ? C.brand700 : C.gray400),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                            '${c.region ?? '—'} · ${c.active ? 'Active' : 'Inactive'}',
                            style: const TextStyle(
                                fontSize: 12, color: C.gray500),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _setCityActive(s, c.id, !c.active),
                      child: Text(c.active ? 'Deactivate' : 'Activate'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /* ---------- Users ---------- */

  final _uUsername = TextEditingController();
  final _uDisplay = TextEditingController();
  final _uPassword = TextEditingController();
  String _uRole = 'city_head';
  int? _uCityId;
  String _uError = '';
  bool _uBusy = false;
  final _userRowBusyId = ValueNotifier<String?>(null);

  Future<void> _addUser(SessionUser s) async {
    setState(() => _uError = '');
    if (_uRole == 'city_head' && _uCityId == null) {
      setState(() => _uError = 'City heads need a city.');
      return;
    }
    setState(() => _uBusy = true);
    try {
      await rpc('atfal_create_user', {
        'p_token': s.token,
        'p_username': _uUsername.text,
        'p_password': _uPassword.text,
        'p_display_name': _uDisplay.text,
        'p_role': _uRole,
        'p_city_id': _uCityId,
      });
      _uUsername.clear();
      _uDisplay.clear();
      _uPassword.clear();
      setState(() => _uCityId = null);
      await _loadUsers();
      if (mounted) showSnack(context, 'User created.');
    } catch (e) {
      setState(() => _uError = errMsg(e));
    }
    setState(() => _uBusy = false);
  }

  Future<void> _resetPw(SessionUser s, UserRow u) async {
    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New password for "${u.username}"'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: inputDecoration(hint: 'min 6 chars'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Update')),
        ],
      ),
    );
    if (pw == null || pw.isEmpty) return;
    _userRowBusyId.value = u.id;
    try {
      await rpc('atfal_reset_password',
          {'p_token': s.token, 'p_user_id': u.id, 'p_new_password': pw});
      if (mounted) showSnack(context, 'Password updated for ${u.username}.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _userRowBusyId.value = null;
  }

  Future<void> _setUserActive(SessionUser s, String id, bool active) async {
    _userRowBusyId.value = id;
    try {
      await rpc('atfal_set_user_active',
          {'p_token': s.token, 'p_user_id': id, 'p_active': active});
      await _loadUsers();
      if (mounted) showSnack(context, active ? 'User enabled.' : 'User disabled.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _userRowBusyId.value = null;
  }

  Widget _usersTab(SessionUser s) {
    final activeCities = _cities.where((c) => c.active).toList();
    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadUsers();
      },
      color: C.brand700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Username'),
                TextField(
                  controller: _uUsername,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: inputDecoration(icon: Icons.person_outline_rounded),
                ),
                const FieldLabel('Display name'),
                TextField(
                    controller: _uDisplay, decoration: inputDecoration()),
                const FieldLabel('Role'),
                DropdownButtonFormField<String>(
                  initialValue: _uRole,
                  decoration: inputDecoration(),
                  items: const [
                    DropdownMenuItem(
                        value: 'city_head', child: Text('City Head')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) =>
                      setState(() => _uRole = v ?? 'city_head'),
                ),
                const FieldLabel('City (for city heads)'),
                DropdownButtonFormField<int?>(
                  initialValue: _uCityId,
                  decoration: inputDecoration(),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('—')),
                    for (final c in activeCities)
                      DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _uCityId = v),
                ),
                const FieldLabel('Password (min 6 chars)'),
                TextField(
                    controller: _uPassword,
                    decoration: inputDecoration(icon: Icons.key_outlined)),
                if (_uError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_uError,
                        style: const TextStyle(
                            fontSize: 14, color: C.red600)),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: _uBusy ? null : () => _addUser(s),
                    icon: _uBusy
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Create user')),
              ],
            ),
          ),
          for (final u in _users)
            Opacity(
              opacity: u.active ? 1 : 0.55,
              child: AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: u.role == 'admin' ? C.brand50 : C.blue50,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                              u.displayName.isNotEmpty
                                  ? u.displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: u.role == 'admin' ? C.brand700 : C.blue700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${u.displayName} (${u.username})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(
                                '${u.role == 'admin' ? 'Admin' : 'City Head'} · '
                                '${u.cityName ?? '—'} · '
                                '${u.active ? 'Active' : 'Disabled'}',
                                style: const TextStyle(
                                    fontSize: 12, color: C.gray500),
                              ),
                              if (u.contactNo != null && u.contactNo!.isNotEmpty)
                                Text(u.contactNo!,
                                    style: const TextStyle(fontSize: 12, color: C.gray400)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<String?>(
                      valueListenable: _userRowBusyId,
                      builder: (context, busyId, _) {
                        final busy = busyId == u.id;
                        return Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: busy ? null : () => _resetPw(s, u),
                              child: const Text('Reset password'),
                            ),
                            OutlinedButton(
                              onPressed: busy ? null : () => _setUserActive(s, u.id, !u.active),
                              child: Text(u.active ? 'Disable' : 'Enable'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /* ---------- Signups ---------- */

  final _signupNotes = <String, TextEditingController>{};
  final _signupBusyId = ValueNotifier<String?>(null);

  TextEditingController _signupNoteCtrl(String id) =>
      _signupNotes.putIfAbsent(id, TextEditingController.new);

  Future<void> _approveSignup(SessionUser s, SignupRequest r) async {
    _signupBusyId.value = r.id;
    try {
      await rpc('atfal_approve_signup', {'p_token': s.token, 'p_request_id': r.id});
      await _loadSignups();
      if (mounted) showSnack(context, '${r.fullName} approved — an email is on its way.');
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _signupBusyId.value = null;
  }

  Future<void> _rejectSignup(SessionUser s, SignupRequest r) async {
    _signupBusyId.value = r.id;
    try {
      await rpc('atfal_reject_signup', {
        'p_token': s.token,
        'p_request_id': r.id,
        'p_review_note': _signupNoteCtrl(r.id).text.isEmpty ? null : _signupNoteCtrl(r.id).text,
      });
      _signupNotes.remove(r.id)?.dispose();
      await _loadSignups();
      if (mounted) showSnack(context, "${r.fullName}'s request was rejected.");
    } catch (e) {
      if (mounted) showSnack(context, errMsg(e), error: true);
    }
    _signupBusyId.value = null;
  }

  Widget _signupsTab(SessionUser s) {
    return RefreshIndicator(
      onRefresh: _loadSignups,
      color: C.brand700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: _signups.isEmpty
            ? [
                const EmptyState(
                    icon: Icons.person_add_alt_outlined,
                    title: 'No signup requests waiting for review.'),
              ]
            : [
                for (final r in _signups) _signupCard(s, r),
              ],
      ),
    );
  }

  Widget _signupCard(SessionUser s, SignupRequest r) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: '${r.fullName} — ',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: r.cityName, style: const TextStyle(color: C.brand700)),
            ],
          )),
          const SizedBox(height: 6),
          Text('${r.email} · ${r.contactNo}',
              style: const TextStyle(fontSize: 13, color: C.gray600)),
          const SizedBox(height: 2),
          Text('Requested ${fmtTime(r.createdAt)}',
              style: const TextStyle(fontSize: 12, color: C.gray400)),
          const FieldLabel('Rejection note (optional)'),
          TextField(
            controller: _signupNoteCtrl(r.id),
            decoration: inputDecoration(hint: 'Reason, if rejecting…'),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String?>(
            valueListenable: _signupBusyId,
            builder: (context, busyId, _) {
              final busy = busyId == r.id;
              return Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => _approveSignup(s, r),
                    icon: busy
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD03B3B)),
                    onPressed: busy ? null : () => _rejectSignup(s, r),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _reviewNotes.values) {
      c.dispose();
    }
    for (final c in _signupNotes.values) {
      c.dispose();
    }
    _cityName.dispose();
    _cityRegion.dispose();
    _uUsername.dispose();
    _uDisplay.dispose();
    _uPassword.dispose();
    _reviewBusyId.dispose();
    _taskBusyId.dispose();
    _userRowBusyId.dispose();
    _signupBusyId.dispose();
    super.dispose();
  }
}

/* ---------- New Task tab ---------- */

class _NewTaskTab extends StatefulWidget {
  final SessionUser me;
  final List<City> cities;
  final VoidCallback onCreated;
  const _NewTaskTab(
      {required this.me, required this.cities, required this.onCreated});

  @override
  State<_NewTaskTab> createState() => _NewTaskTabState();
}

class _NewTaskTabState extends State<_NewTaskTab> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _url = TextEditingController();
  String _category = 'attendance';
  DateTime? _due;
  final _selected = <int>{};
  String _error = '';
  String _doneMsg = '';
  String _waText = '';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  String? get _dueStr => _due == null
      ? null
      : '${_due!.year.toString().padLeft(4, '0')}-'
          '${_due!.month.toString().padLeft(2, '0')}-'
          '${_due!.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() => _error = '');
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one city.');
      return;
    }
    setState(() => _busy = true);
    try {
      await rpc('atfal_create_task', {
        'p_token': widget.me.token,
        'p_title': _title.text,
        'p_description': _desc.text.isEmpty ? null : _desc.text,
        'p_category': _category,
        'p_due_date': _dueStr,
        'p_attachment_url': _url.text,
        'p_city_ids': _selected.toList(),
      });
      final active = widget.cities.where((c) => c.active).toList();
      final names = active
          .where((c) => _selected.contains(c.id))
          .map((c) => c.name)
          .toList();
      final cityTxt =
          names.length > 5 ? '${names.length} cities' : names.join(', ');
      final wa = StringBuffer('📋 *New Atfal Task*\n${_title.text}\n'
          'Category: ${categoryLabel[_category]}');
      if (_dueStr != null) wa.write('\nDue: ${fmtDate(_dueStr)}');
      wa.write('\nCities: $cityTxt\n\nUpdate status here: $siteUrl/city');
      setState(() {
        _doneMsg = 'Task created and assigned to $cityTxt.';
        _waText = wa.toString();
        _due = null;
        _selected.clear();
      });
      _title.clear();
      _desc.clear();
      _url.clear();
      widget.onCreated();
    } catch (e) {
      setState(() => _error = errMsg(e));
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.cities.where((c) => c.active).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Title *'),
              TextField(
                controller: _title,
                decoration: inputDecoration(
                    hint: 'e.g. Submit August attendance sheet'),
              ),
              const FieldLabel('Description (Urdu is fine)'),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: inputDecoration(hint: 'Details, instructions…'),
              ),
              const FieldLabel('Category *'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: inputDecoration(icon: categoryIcon[_category]),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c, child: Text(categoryLabel[c]!)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'other'),
              ),
              const FieldLabel('Due date'),
              OutlinedButton.icon(
                onPressed: _pickDue,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_due == null ? 'Pick a date' : fmtDate(_dueStr)),
              ),
              const FieldLabel('Attachment link (Google Sheet / Form / Doc)'),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: inputDecoration(
                    hint: 'https://docs.google.com/...', icon: Icons.link_rounded),
              ),
              Row(
                children: [
                  const FieldLabel('Assign to cities *'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selected.length < active.length) {
                        _selected
                          ..clear()
                          ..addAll(active.map((c) => c.id));
                      } else {
                        _selected.clear();
                      }
                    }),
                    child: const Text('Select all / none',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in active)
                    FilterChip(
                      label: Text(c.name),
                      selected: _selected.contains(c.id),
                      showCheckmark: false,
                      avatar: _selected.contains(c.id)
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                      labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selected.contains(c.id) ? Colors.white : C.gray600),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selected.add(c.id);
                        } else {
                          _selected.remove(c.id);
                        }
                      }),
                    ),
                ],
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style:
                          const TextStyle(fontSize: 14, color: C.red600)),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_busy ? 'Creating…' : 'Create & assign task'),
              ),
              if (_doneMsg.isNotEmpty) ...[
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: C.brand700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_doneMsg,
                          style: const TextStyle(fontSize: 14, color: C.brand700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366)),
                  onPressed: () => shareToWhatsApp(_waText),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share to WhatsApp'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
