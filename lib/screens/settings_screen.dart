import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/filter_service.dart';
import '../services/history_store.dart';
import '../services/scheduler_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  final _include = TextEditingController();
  final _exclude = TextEditingController();
  final _boards = TextEditingController();
  bool _portraitOnly = true;
  bool _autoEnabled = true;
  double _hours = 24;
  double _maxEntries = 10;
  double _retention = 30;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        _prefs = p;
        final f = FilterService(p);
        _include.text = f.includeKeywords.join(', ');
        _exclude.text = f.excludeKeywords.join(', ');
        _portraitOnly = f.portraitOnly;
        _autoEnabled = SchedulerService.isEnabled(p);
        _hours = SchedulerService.intervalHours(p).toDouble();
        _maxEntries = (p.getInt('history_max_entries') ?? 10).toDouble();
        _retention = (p.getInt('history_retention_days') ?? 30).toDouble();
        _boards.text = p.getString('extra_boards') ?? '';
      });
    });
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await FilterService(p).save(
      include: _include.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      exclude: _exclude.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      portraitOnly: _portraitOnly,
    );
    // History config first: SchedulerService.save passes these to the native worker.
    final h = HistoryStore(p);
    await h.load();
    await h.setConfig(maxEntries: _maxEntries.round(), retentionDays: _retention.round());
    await p.setString('extra_boards', _boards.text);
    await SchedulerService.save(p, enabled: _autoEnabled, hours: _hours.round());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  Future<void> _testRunNow() async {
    final p = _prefs;
    if (p == null) return;
    await SchedulerService.runNow(p);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background change queued — check your wallpaper in a minute, then reopen History.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prefs == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _include, decoration: const InputDecoration(labelText: 'Include keywords (comma-separated)', hintText: 'e.g. neon city, mountains, anime wallpaper')),
          TextField(controller: _exclude, decoration: const InputDecoration(labelText: 'Exclude keywords', hintText: 'e.g. meme, quote')),
          SwitchListTile(title: const Text('Portrait only'), value: _portraitOnly, onChanged: (v) => setState(() => _portraitOnly = v)),
          const Divider(),
          TextField(controller: _boards, maxLines: 3, decoration: const InputDecoration(labelText: 'Extra public boards (one URL per line, optional)', hintText: 'https://www.pinterest.com/user/board-slug/')),
          const Divider(),
          SwitchListTile(title: const Text('Auto-change wallpaper'), value: _autoEnabled, onChanged: (v) => setState(() => _autoEnabled = v)),
          Text('Every ${_hours.round()}h (default 24h)'),
          Slider(min: 1, max: 168, divisions: 167, value: _hours, label: '${_hours.round()}h', onChanged: (v) => setState(() => _hours = v)),
          Text('Cache: ${_maxEntries.round()} images'),
          Slider(min: 1, max: 50, divisions: 49, value: _maxEntries, label: '${_maxEntries.round()}', onChanged: (v) => setState(() => _maxEntries = v)),
          Text('Keep cached for ${_retention.round()} days'),
          Slider(min: 1, max: 365, value: _retention, label: '${_retention.round()}d', onChanged: (v) => setState(() => _retention = v)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _testRunNow, child: const Text('Test auto-change now (background worker)')),
        ],
      ),
    );
  }
}
