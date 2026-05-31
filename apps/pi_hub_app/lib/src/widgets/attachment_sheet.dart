import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';

import '../hub_client.dart';

class AttachmentSheet {
  const AttachmentSheet._();

  static Future<void> show(
    BuildContext context, {
    required HubClient client,
    required ValueChanged<List<AttachmentData>> onPick,
  }) {
    return pickImages(context, onPick: onPick);
  }

  static Future<void> pickImages(
    BuildContext context, {
    required ValueChanged<List<AttachmentData>> onPick,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final attachments = <AttachmentData>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        attachments.add(
          AttachmentData(
            name: file.name,
            mimeType: _mimeForName(file.name),
            data: base64Encode(bytes),
          ),
        );
      }
      if (attachments.isNotEmpty) onPick(attachments);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image pick failed: $error')));
    }
  }

  static Future<AttachmentData?> readClipboardImage() async {
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    return AttachmentData(
      name: 'clipboard-image.png',
      mimeType: 'image/png',
      data: base64Encode(bytes),
    );
  }

  static String _mimeForName(String name) {
    final ext = name.split('.').last.toLowerCase();
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
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/*';
    }
  }
}
