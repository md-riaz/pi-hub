import 'package:flutter/material.dart';
import '../hub_client.dart';
import '../theme/hub_theme.dart';

class RemotePathBrowser extends StatefulWidget {
  final HubClient client;
  final String initial;
  final bool canBrowse;

  const RemotePathBrowser({super.key, required this.client, this.initial = '/', this.canBrowse = true});

  static Future<String?> show(BuildContext context, {required HubClient client, String initial = '/', bool canBrowse = true}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RemotePathBrowser(client: client, initial: initial, canBrowse: canBrowse),
    );
  }

  @override
  State<RemotePathBrowser> createState() => _RemotePathBrowserState();
}

class _RemotePathBrowserState extends State<RemotePathBrowser> {
  late String _current;
  List<BrowseEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    if (widget.canBrowse) {
      _loadDirectory(_current);
    } else {
      _loading = false;
    }
  }

  Future<void> _loadDirectory(String dirPath) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.client.browseDirectory(dirPath);
      if (!mounted) return;
      setState(() {
        _current = result.path;
        _entries = result.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _entries = [];
      });
    }
  }

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
                      child: Container(width: 36, height: 36, decoration: BoxDecoration(color: HubTheme.card, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18, color: HubTheme.text2)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _NavBtn(icon: Icons.home, label: 'Home', onTap: () => widget.canBrowse ? _loadDirectory('/') : null),
                    if (_current != '/') ...[
                      const SizedBox(width: 8),
                      _NavBtn(label: 'Up', onTap: () => widget.canBrowse ? _loadDirectory(_entries.isNotEmpty ? _entries.first.path.substring(0, _entries.first.path.lastIndexOf('/')) : '/') : null),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: HubTheme.blue)))
          else if (_error != null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 32, color: HubTheme.red),
              const SizedBox(height: 8),
              Text(_error!, style: HubTheme.caption, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _loadDirectory(_current),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: HubTheme.blue, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Retry', style: TextStyle(color: Color(0xFF06111F), fontSize: 12, fontWeight: FontWeight.w600))),
              ),
            ])))
          else
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text('Empty directory', style: TextStyle(color: HubTheme.text3)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return GestureDetector(
                          onTap: entry.isDirectory ? () => _loadDirectory(entry.path) : null,
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
                                  child: Icon(entry.isDirectory ? Icons.folder_open : Icons.description_outlined, size: 18, color: entry.isDirectory ? HubTheme.blue : HubTheme.text3),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.name, style: const TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
                                      Text(entry.path, style: HubTheme.monoSmall, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (entry.isDirectory) const Icon(Icons.chevron_right, size: 18, color: HubTheme.text3),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: HubTheme.softLine))),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: HubTheme.panel, border: Border.all(color: HubTheme.softLine), borderRadius: BorderRadius.circular(16)),
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
  final VoidCallback? onTap;
  const _NavBtn({this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: HubTheme.panel, border: Border.all(color: HubTheme.softLine), borderRadius: BorderRadius.circular(999)),
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
