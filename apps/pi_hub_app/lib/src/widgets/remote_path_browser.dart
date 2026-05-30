import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class RemotePathBrowser extends StatefulWidget {
  final String initial;
  const RemotePathBrowser({super.key, required this.initial});

  static Future<String?> show(BuildContext context, {String initial = '/'}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RemotePathBrowser(initial: initial),
    );
  }

  @override
  State<RemotePathBrowser> createState() => _RemotePathBrowserState();
}

class _RemotePathBrowserState extends State<RemotePathBrowser> {
  late String _current;

  static const _tree = {
    '/': ['home'],
    '/home': ['user'],
    '/home/user': ['projects', 'apps', 'work', 'labs', 'Downloads'],
    '/home/user/projects': ['api-server', 'notify-service', 'theme-kit'],
    '/home/user/apps': ['pi-hub', 'flutter-starter'],
    '/home/user/work': ['ipbx-sms', 'fusionpbx-tools'],
    '/home/user/labs': ['theme-kit', 'imagick-transformer'],
    '/home/user/projects/api-server': ['src', 'tests', 'package.json', 'README.md'],
    '/home/user/apps/pi-hub': ['lib', 'android', 'ios', 'pubspec.yaml'],
  };

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  List<String> get _entries => _tree[_current] ?? [];
  String get _parent => _current.split('/').length > 2
      ? _current.substring(0, _current.lastIndexOf('/'))
      : '/';
  bool _isFolder(String name) => _tree['$_current/$name'] != null || !name.contains('.');

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: const BoxDecoration(
        color: HubTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: HubTheme.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Remote Workspace', style: TextStyle(color: HubTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(_current, style: HubTheme.monoSmall),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: HubTheme.card, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 18, color: HubTheme.text2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _NavBtn(icon: Icons.home, label: 'Home', onTap: () => setState(() => _current = '/home/user')),
                    if (_current != '/home/user') ...[
                      const SizedBox(width: 8),
                      _NavBtn(label: 'Up', onTap: () => setState(() => _current = _parent)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final name = _entries[index];
                final full = '$_current/$name';
                final folder = _isFolder(name);
                return GestureDetector(
                  onTap: folder ? () => setState(() => _current = full) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HubTheme.panel,
                      border: Border.all(color: HubTheme.softLine),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: HubTheme.card, borderRadius: BorderRadius.circular(12)),
                          child: Icon(folder ? Icons.folder_open : Icons.description_outlined, size: 18, color: folder ? HubTheme.blue : HubTheme.text3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(full, style: HubTheme.monoSmall, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (folder) const Icon(Icons.chevron_right, size: 18, color: HubTheme.text3),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: HubTheme.softLine)),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HubTheme.panel,
                    border: Border.all(color: HubTheme.softLine),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_current, style: HubTheme.mono.copyWith(color: HubTheme.text2)),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context, _current),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: HubTheme.green, borderRadius: BorderRadius.circular(16)),
                    child: const Text('Select this directory', style: TextStyle(color: Color(0xFF06110B), fontSize: 14, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  const _NavBtn({this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: HubTheme.panel,
          border: Border.all(color: HubTheme.softLine),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: HubTheme.text2), const SizedBox(width: 4)],
            Text(label, style: const TextStyle(color: HubTheme.text2, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
