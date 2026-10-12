import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/categories.dart';
import '../services/filter_service.dart';
import '../services/history_store.dart';
import '../services/pinterest_session.dart';
import '../services/scheduler_service.dart';

class SettingsScreen extends StatefulWidget {
  final PinterestSession session;
  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  final _include = TextEditingController();
  final _exclude = TextEditingController();
  final _boards = TextEditingController();
  final _whQuery = TextEditingController();
  final _whKey = TextEditingController();
  final _kcTags = TextEditingController();
  final Set<String> _categories = {};
  bool _portraitOnly = true;
  bool _whEnabled = true;
  String _whPurity = '100';
  String _whCategories = '111';
  String _whSorting = 'random';
  bool _kcEnabled = false;
  bool _kcSafe = true;
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
        _whEnabled = p.getBool('wallhaven_enabled') ?? true;
        _whQuery.text = p.getString('wallhaven_query') ?? '';
        _whKey.text = p.getString('wallhaven_apikey') ?? '';
        _whPurity = p.getString('wallhaven_purity') ?? '100';
        _whCategories = p.getString('wallhaven_categories') ?? '111';
        _whSorting = p.getString('wallhaven_sorting') ?? 'random';
        _kcEnabled = p.getBool('konachan_enabled') ?? false;
        _kcSafe = p.getBool('konachan_safe') ?? true;
        _kcTags.text = p.getString('konachan_tags') ?? '';
        _categories
          ..clear()
          ..addAll(selectedCategoryNames(p));
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
    await p.setBool('wallhaven_enabled', _whEnabled);
    await p.setString('wallhaven_query', _whQuery.text);
    await p.setString('wallhaven_apikey', _whKey.text.trim());
    await p.setString('wallhaven_purity', _whPurity);
    await p.setString('wallhaven_categories', _whCategories);
    await p.setString('wallhaven_sorting', _whSorting);
    await p.setBool('konachan_enabled', _kcEnabled);
    await p.setString('konachan_tags', _kcTags.text);
    await p.setBool('konachan_safe', _kcSafe);
    await p.setString(kCategoriesKey, _categories.join(', '));
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
          Text('Pinterest account', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              widget.session.isLoggedIn ? Icons.check_circle : Icons.error_outline,
              color: widget.session.isLoggedIn ? Colors.green : Colors.orange,
            ),
            title: Text(widget.session.isLoggedIn ? 'Signed in as ${widget.session.username ?? 'your account'}' : 'Not signed in'),
            subtitle: const Text('WallPin reuses this WebView session — your password is never stored'),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/login');
                    if (mounted) setState(() {});
                  },
                  child: Text(widget.session.isLoggedIn ? 'Manage / switch account' : 'Log in to Pinterest'),
                ),
              ),
              if (widget.session.isLoggedIn) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await CookieManager.instance().deleteAllCookies();
                      await widget.session.logout();
                      if (mounted) setState(() {});
                    },
                    child: const Text('Log out'),
                  ),
                ),
              ],
            ],
          ),
          const Divider(),
          TextField(controller: _include, decoration: const InputDecoration(labelText: 'Include keywords (comma-separated)', hintText: 'e.g. neon city, mountains, anime wallpaper')),
          TextField(controller: _exclude, decoration: const InputDecoration(labelText: 'Exclude keywords', hintText: 'e.g. meme, quote')),
          SwitchListTile(title: const Text('Portrait only'), value: _portraitOnly, onChanged: (v) => setState(() => _portraitOnly = v)),
          const Divider(),
          Text('Categories', style: Theme.of(context).textTheme.titleMedium),
          Text('Pick the vibes you want — each roll picks one at random and scopes every source to it. None selected = your own tags below.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in kCategories)
                FilterChip(
                  label: Text(c.name),
                  selected: _categories.contains(c.name),
                  onSelected: (sel) => setState(() => sel ? _categories.add(c.name) : _categories.remove(c.name)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          TextField(controller: _boards, maxLines: 3, decoration: const InputDecoration(labelText: 'Extra public boards (one URL per line, optional)', hintText: 'https://www.pinterest.com/user/board-slug/')),
          const Divider(),
          SwitchListTile(title: const Text('Wallhaven source'), subtitle: const Text('Public API — works without login/key (SFW)'), value: _whEnabled, onChanged: (v) => setState(() => _whEnabled = v)),
          TextField(controller: _whQuery, decoration: const InputDecoration(labelText: 'Wallhaven tags', hintText: 'e.g. anime nature city')),
          DropdownButtonFormField<String>(
            initialValue: _whPurity,
            decoration: const InputDecoration(labelText: 'Purity (needs API key for non-SFW)'),
            items: const [
              DropdownMenuItem(value: '100', child: Text('SFW')),
              DropdownMenuItem(value: '110', child: Text('SFW + Sketchy')),
              DropdownMenuItem(value: '010', child: Text('Sketchy')),
              DropdownMenuItem(value: '111', child: Text('All')),
            ],
            onChanged: (v) => setState(() => _whPurity = v ?? '100'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _whCategories,
            decoration: const InputDecoration(labelText: 'Categories'),
            items: const [
              DropdownMenuItem(value: '111', child: Text('General + Anime + People')),
              DropdownMenuItem(value: '100', child: Text('General')),
              DropdownMenuItem(value: '010', child: Text('Anime')),
              DropdownMenuItem(value: '001', child: Text('People')),
            ],
            onChanged: (v) => setState(() => _whCategories = v ?? '111'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _whSorting,
            decoration: const InputDecoration(labelText: 'Sorting'),
            items: const [
              DropdownMenuItem(value: 'random', child: Text('Random')),
              DropdownMenuItem(value: 'toplist', child: Text('Toplist')),
              DropdownMenuItem(value: 'favorites', child: Text('Most favorited')),
              DropdownMenuItem(value: 'views', child: Text('Most viewed')),
              DropdownMenuItem(value: 'date_added', child: Text('Newest')),
            ],
            onChanged: (v) => setState(() => _whSorting = v ?? 'random'),
          ),
          TextField(controller: _whKey, decoration: const InputDecoration(labelText: 'Wallhaven API key (optional)', hintText: 'unlocks sketchy/NSFW + higher rate limits')),
          const Divider(),
          SwitchListTile(title: const Text('Konachan source'), subtitle: const Text('Anime wallpapers — keyless Moebooru API'), value: _kcEnabled, onChanged: (v) => setState(() => _kcEnabled = v)),
          TextField(controller: _kcTags, decoration: const InputDecoration(labelText: 'Konachan tags', hintText: 'e.g. scenery landscape city')),
          SwitchListTile(title: const Text('Safe only (konachan.net)'), subtitle: const Text('Off uses konachan.com and may include NSFW'), value: _kcSafe, onChanged: (v) => setState(() => _kcSafe = v)),
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
