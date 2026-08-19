import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../meta.dart';
import '../models.dart';
import '../widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<City> _cities = [];
  List<Task> _tasks = [];
  List<Assignment> _assignments = [];
  List<Activity> _activity = [];
  String _category = '';
  String _error = '';
  bool _loading = true;
  Timer? _timer;

  SessionUser? get me => Session.current;

  @override
  void initState() {
    super.initState();
    if (me == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      });
      return;
    }
    _load();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        sb.from('atfal_cities').select().eq('active', true).order('name', ascending: true),
        sb
            .from('atfal_tasks')
            .select()
            .eq('archived', false)
            .order('created_at', ascending: false),
        sb.from('atfal_assignments').select(),
        sb
            .from('atfal_activity')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
      ]);
      if (!mounted) return;
      setState(() {
        _cities = results[0].map(City.fromJson).toList();
        _tasks = results[1].map(Task.fromJson).toList();
        _assignments = results[2].map(Assignment.fromJson).toList();
        _activity = results[3].map(Activity.fromJson).toList();
        _error = '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errMsg(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = me;
    if (s == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/icon/icon.png', width: 26, height: 26, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            const Text('Atfal Taskboard'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(s.isAdmin ? '/admin' : '/city'),
            child: Text(s.isAdmin ? 'Admin Portal' : 'My Tasks',
                style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: logout,
          ),
        ],
      ),
      body: _loading
          ? const SkeletonList(cards: 4)
          : RefreshIndicator(
              onRefresh: _load,
              color: C.emerald700,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: _buildBody(),
              ),
            ),
    );
  }

  List<Widget> _buildBody() {
    final taskById = {for (final t in _tasks) t.id: t};
    final cityById = {for (final c in _cities) c.id: c};
    final asgById = {for (final a in _assignments) a.id: a};

    final visibleTasks = _category.isEmpty
        ? _tasks
        : _tasks.where((t) => t.category == _category).toList();
    final taskIds = visibleTasks.map((t) => t.id).toSet();
    final asg =
        _assignments.where((a) => taskIds.contains(a.taskId)).toList();

    final approved = asg.where((a) => a.status == 'approved').length;
    final submitted = asg.where((a) => a.status == 'submitted').length;
    final overdue = asg.where((a) {
      final t = taskById[a.taskId];
      return t != null && isOverdue(t, a.status);
    }).length;
    final pct = asg.isEmpty ? 0 : (approved / asg.length * 100).round();

    final board = _cities.map((c) {
      final mine = asg.where((a) => a.cityId == c.id).toList();
      final done = mine.where((a) => a.status == 'approved').length;
      final od = mine.where((a) {
        final t = taskById[a.taskId];
        return t != null && isOverdue(t, a.status);
      }).length;
      return (
        city: c,
        total: mine.length,
        done: done,
        od: od,
        pct: mine.isEmpty ? 0.0 : done / mine.length,
      );
    }).toList()
      ..sort((x, y) {
        final byPct = y.pct.compareTo(x.pct);
        if (byPct != 0) return byPct;
        final byOd = x.od.compareTo(y.od);
        if (byOd != 0) return byOd;
        return x.city.name.compareTo(y.city.name);
      });

    final byKey = {for (final a in asg) '${a.taskId}|${a.cityId}': a};

    return [
      if (_error.isNotEmpty)
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: C.red600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Failed to load: $_error',
                    style: const TextStyle(fontSize: 13, color: C.red600)),
              ),
            ],
          ),
        ),

      // stat tiles
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: [
          StatTile(icon: Icons.push_pin_outlined, big: '${visibleTasks.length}', cap: 'Active tasks'),
          StatTile(icon: Icons.trending_up_rounded, big: '$pct%', cap: 'Overall completion'),
          StatTile(icon: Icons.hourglass_top_rounded, big: '$submitted', cap: 'Awaiting review'),
          StatTile(
              icon: Icons.report_gmailerrorred_rounded,
              big: '$overdue',
              cap: 'Overdue',
              alert: overdue > 0),
        ],
      ),

      // leaderboard
      const SectionHeader(
        icon: Icons.emoji_events_outlined,
        title: 'City Leaderboard',
        subtitle: 'Completion = approved ÷ total assignments',
      ),
      AppCard(
        child: board.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('No cities yet.',
                    style: TextStyle(fontSize: 14, color: C.gray400)),
              )
            : Column(
                children: [
                  for (var i = 0; i < board.length; i++) ...[
                    if (i > 0) const Divider(),
                    _leaderboardRow(i + 1, board[i]),
                  ],
                ],
              ),
      ),

      // matrix
      SectionHeader(
        icon: Icons.grid_view_rounded,
        title: 'Task × City Matrix',
        trailing: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _category,
            borderRadius: BorderRadius.circular(12),
            items: [
              const DropdownMenuItem(value: '', child: Text('All')),
              for (final c in categories)
                DropdownMenuItem(value: c, child: Text(categoryLabel[c]!)),
            ],
            onChanged: (v) => setState(() => _category = v ?? ''),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 12,
          children: [
            _Legend(letter: 'P', label: 'Pending'),
            _Legend(letter: 'I', label: 'In Progress'),
            _Legend(letter: 'S', label: 'Submitted'),
            _Legend(letter: 'A', label: 'Approved'),
            _Legend(letter: 'R', label: 'Returned'),
          ],
        ),
      ),
      _matrix(visibleTasks, byKey),

      // activity
      const SectionHeader(icon: Icons.history_rounded, title: 'Recent Activity'),
      AppCard(
        child: _activity.isEmpty
            ? const Text('No activity yet.',
                style: TextStyle(fontSize: 14, color: C.gray400))
            : Column(
                children: [
                  for (var i = 0; i < _activity.length; i++) ...[
                    if (i > 0) const Divider(),
                    _activityRow(_activity[i], asgById, taskById, cityById),
                  ],
                ],
              ),
      ),
    ];
  }

  Widget _leaderboardRow(
      int rank,
      ({City city, int total, int done, int od, double pct}) r) {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 17))
                : Text('$rank',
                    style: const TextStyle(fontSize: 14, color: C.gray500)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.city.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: r.pct,
                    minHeight: 7,
                    backgroundColor: C.gray100,
                    color: C.emerald700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(r.pct * 100).round()}% · ${r.done}/${r.total}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (r.od > 0)
                Text('${r.od} overdue',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: C.red700,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matrix(List<Task> visibleTasks, Map<String, Assignment> byKey) {
    if (visibleTasks.isEmpty) {
      return const EmptyState(
          icon: Icons.grid_view_rounded, title: 'No tasks yet.');
    }
    const cellW = 34.0;
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.gray100),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Container(
                color: C.gray50,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 160,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Task',
                            style:
                                TextStyle(fontSize: 12, color: C.gray500)),
                      ),
                    ),
                    for (final c in _cities)
                      SizedBox(
                        width: cellW,
                        child: Tooltip(
                          message: c.name,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              c.name.length > 3
                                  ? c.name.substring(0, 3)
                                  : c.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: C.gray500),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (var i = 0; i < visibleTasks.length; i++)
                Container(
                  color: i.isOdd ? C.gray50.withValues(alpha: 0.5) : Colors.white,
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: C.gray100))),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(visibleTasks[i].title,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '${categoryLabel[visibleTasks[i].category]} · due ${fmtDate(visibleTasks[i].dueDate)}',
                                style: const TextStyle(
                                    fontSize: 11, color: C.gray400),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final c in _cities)
                        SizedBox(
                          width: cellW,
                          child: Center(child: _cell(visibleTasks[i], c, byKey)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(Task t, City c, Map<String, Assignment> byKey) {
    final a = byKey['${t.id}|${c.id}'];
    if (a == null) {
      return const Text('·', style: TextStyle(color: C.gray300));
    }
    final s = statusStyle[a.status]!;
    final od = isOverdue(t, a.status);
    return Tooltip(
      message:
          '${c.name} — ${statusLabel[a.status]}${od ? ' (overdue)' : ''}',
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
            color: s.bg, borderRadius: BorderRadius.circular(7)),
        child: Center(
          child: Text(s.letter,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: s.fg)),
        ),
      ),
    );
  }

  Widget _activityRow(Activity ev, Map<String, Assignment> asgById,
      Map<String, Task> taskById, Map<int, City> cityById) {
    final a = ev.assignmentId == null ? null : asgById[ev.assignmentId];
    final t = a == null ? null : taskById[a.taskId];
    final c = a == null ? null : cityById[a.cityId];
    final isStatus = ev.action.startsWith('status:');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(ev.actorName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                '· ${t?.title ?? ''} ${c != null ? '(${c.name})' : ''} →',
                style: const TextStyle(fontSize: 14),
              ),
              if (isStatus)
                StatusChip(status: ev.action.substring(7))
              else
                const Text('assigned', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${fmtTime(ev.createdAt)}${ev.detail != null ? ' · ${ev.detail}' : ''}',
            style: const TextStyle(fontSize: 12, color: C.gray400),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String letter;
  final String label;
  const _Legend({required this.letter, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$letter ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: C.gray600)),
        Text(label, style: const TextStyle(fontSize: 12, color: C.gray500)),
      ],
    );
  }
}
