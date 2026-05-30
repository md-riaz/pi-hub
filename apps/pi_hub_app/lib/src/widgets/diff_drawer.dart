import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class DiffDrawer extends StatelessWidget {
  final String file;
  final int added;
  final int removed;
  final List<String> lines;

  const DiffDrawer({
    super.key,
    required this.file,
    required this.added,
    required this.removed,
    this.lines = const [],
  });

  static void show(BuildContext context, {required String file, required int added, required int removed, List<String> lines = const []}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiffDrawer(file: file, added: added, removed: removed, lines: lines),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.76,
      decoration: const BoxDecoration(
        color: HubTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: HubTheme.line)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: HubTheme.softLine))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 36, height: 36, decoration: BoxDecoration(color: HubTheme.card, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18, color: HubTheme.text2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file, style: const TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '+$added', style: const TextStyle(color: HubTheme.green, fontSize: 12, fontFamily: 'monospace')),
                        const TextSpan(text: ' '),
                        TextSpan(text: '-$removed', style: const TextStyle(color: HubTheme.red, fontSize: 12, fontFamily: 'monospace')),
                      ])),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: HubTheme.card, borderRadius: BorderRadius.circular(999)),
                    child: const Icon(Icons.copy, size: 13, color: HubTheme.text2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF05070A),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: lines.isEmpty ? _sampleDiff.length : lines.length,
                itemBuilder: (context, index) {
                  final line = lines.isEmpty ? _sampleDiff[index] : lines[index];
                  final isAdd = line.startsWith('+');
                  final isDel = line.startsWith('-');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    color: isAdd
                        ? HubTheme.green.withOpacity(0.1)
                        : isDel
                            ? HubTheme.red.withOpacity(0.1)
                            : Colors.transparent,
                    child: Text(line, style: TextStyle(
                      color: isAdd ? HubTheme.green : isDel ? HubTheme.red : HubTheme.text2,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 2,
                    )),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _sampleDiff = [
    '  import jwt from \'jsonwebtoken\';',
    '+ import { refreshTokenStore } from \'./token-store\';',
    '- const token = req.headers.authorization?.split(\' \')[1];',
    '+ const accessToken = req.headers.authorization?.split(\' \')[1];',
    '+ if (!accessToken) return res.status(401).json({ error: \'No token\' });',
    '- const decoded = jwt.verify(token, AUTH_SECRET);',
    '+ const decoded = jwt.verify(accessToken, AUTH_SECRET, { ignoreExpiration: false });',
    '+ await refreshTokenStore.assertVersion(decoded.userId, decoded.tokenVersion);',
  ];
}
