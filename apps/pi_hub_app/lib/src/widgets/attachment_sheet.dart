import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../hub_client.dart';
import '../theme/hub_theme.dart';

class AttachmentSheet extends StatefulWidget {
  final HubClient client;
  final ValueChanged<List<AttachmentData>> onPick;

  const AttachmentSheet({
    super.key,
    required this.client,
    required this.onPick,
  });

  static void show(
    BuildContext context, {
    required HubClient client,
    required ValueChanged<List<AttachmentData>> onPick,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentSheet(client: client, onPick: onPick),
    );
  }

  @override
  State<AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<AttachmentSheet> {
  bool _picking = false;

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final attachments = <AttachmentData>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final name = file.name;
        final ext = name.split('.').last.toLowerCase();
        attachments.add(
          AttachmentData(
            name: name,
            mimeType: _mimeForExt(ext),
            data: base64Encode(bytes),
          ),
        );
      }
      if (attachments.isNotEmpty) widget.onPick(attachments);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pick failed: $e')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final attachments = <AttachmentData>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final name = file.name;
        final ext = name.split('.').last.toLowerCase();
        attachments.add(
          AttachmentData(
            name: name,
            mimeType: _mimeForExt(ext),
            data: base64Encode(bytes),
          ),
        );
      }
      if (attachments.isNotEmpty) widget.onPick(attachments);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pick failed: $e')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pasteClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final b64 = base64Encode(utf8.encode(data.text!));
        widget.onPick([
          AttachmentData(
            name: 'clipboard.txt',
            mimeType: 'text/plain',
            data: b64,
          ),
        ]);
        if (mounted) Navigator.pop(context);
        return;
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Clipboard failed: $e')));
    }
  }

  String _mimeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'json':
        return 'application/json';
      case 'txt':
      case 'md':
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'yaml':
      case 'yml':
      case 'xml':
      case 'html':
      case 'css':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HubTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: HubTheme.line)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add context',
            style: TextStyle(
              color: HubTheme.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _Item(
            icon: Icons.file_upload_outlined,
            label: 'Pick file',
            onTap: _picking ? null : _pickFile,
            loading: _picking,
          ),
          const SizedBox(height: 8),
          _Item(
            icon: Icons.image_outlined,
            label: 'Pick image',
            onTap: _picking ? null : _pickImage,
          ),
          const SizedBox(height: 8),
          _Item(
            icon: Icons.content_paste,
            label: 'Paste from clipboard',
            onTap: _pasteClipboard,
          ),
          const SizedBox(height: 8),
          _Item(
            icon: Icons.terminal,
            label: 'Attach latest log',
            onTap: () {
              widget.onPick([]);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          _Item(
            icon: Icons.account_tree,
            label: 'Attach diff',
            onTap: () {
              widget.onPick([]);
              Navigator.pop(context);
            },
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _Item({
    required this.icon,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HubTheme.card,
          border: Border.all(color: HubTheme.softLine),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HubTheme.panel2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HubTheme.blue,
                      ),
                    )
                  : Icon(icon, size: 18, color: HubTheme.blue),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: HubTheme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
