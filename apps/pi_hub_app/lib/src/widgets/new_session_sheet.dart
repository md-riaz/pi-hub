import 'package:flutter/material.dart';
import '../hub_client.dart';
import '../theme/hub_theme.dart';
import 'remote_path_browser.dart';

class NewSessionResult {
  final String path;
  final String prompt;
  final String model;
  NewSessionResult({
    required this.path,
    required this.prompt,
    required this.model,
  });
}

class NewSessionSheet extends StatefulWidget {
  final ValueChanged<NewSessionResult> onStart;
  final HubClient? client;
  final List<String> availableModels;
  final String? selectedModel;

  const NewSessionSheet({
    super.key,
    required this.onStart,
    this.client,
    this.availableModels = const [],
    this.selectedModel,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<NewSessionResult> onStart,
    HubClient? client,
    List<String> availableModels = const [],
    String? selectedModel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewSessionSheet(
        onStart: onStart,
        client: client,
        availableModels: availableModels,
        selectedModel: selectedModel,
      ),
    );
  }

  @override
  State<NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<NewSessionSheet> {
  final _pathController = TextEditingController(text: '');
  final _promptController = TextEditingController();
  late String _selectedModel;

  List<String> get _models =>
      widget.availableModels.isEmpty ? ['default'] : widget.availableModels;

  @override
  void initState() {
    super.initState();
    _selectedModel =
        widget.selectedModel != null && _models.contains(widget.selectedModel)
        ? widget.selectedModel!
        : _models.first;
  }

  @override
  void dispose() {
    _pathController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _showModelPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HubTheme.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Handle(),
              const SizedBox(height: 16),
              const Text(
                'Select model',
                style: TextStyle(
                  color: HubTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _models.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, model),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: model == _selectedModel
                              ? HubTheme.green.withOpacity(0.1)
                              : HubTheme.card,
                          border: Border.all(
                            color: model == _selectedModel
                                ? HubTheme.green.withOpacity(0.4)
                                : HubTheme.softLine,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                model,
                                style: const TextStyle(
                                  color: HubTheme.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (model == _selectedModel)
                              const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: HubTheme.green,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _selectedModel = selected);
  }

  @override
  Widget build(BuildContext context) {
    final canStart =
        _pathController.text.trim().isNotEmpty &&
        _promptController.text.trim().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: HubTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: HubTheme.line)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Handle(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start New Pi Session',
                      style: TextStyle(
                        color: HubTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a remote directory, then send the first prompt',
                      style: HubTheme.caption,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: HubTheme.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: HubTheme.text2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Working directory',
            style: HubTheme.bodySmall.copyWith(color: HubTheme.text2),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HubTheme.card,
                    border: Border.all(color: HubTheme.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _pathController.text,
                    style: const TextStyle(
                      color: HubTheme.text,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.client != null
                    ? () async {
                        final path = await RemotePathBrowser.show(
                          context,
                          client: widget.client!,
                          initial: _pathController.text,
                        );
                        if (path != null)
                          setState(() => _pathController.text = path);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: HubTheme.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Browse',
                    style: TextStyle(
                      color: Color(0xFF06111F),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Initial prompt',
            style: HubTheme.bodySmall.copyWith(color: HubTheme.text2),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _promptController,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(color: HubTheme.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tell Pi what to do in this directory...',
              hintStyle: const TextStyle(color: HubTheme.text3),
              filled: true,
              fillColor: HubTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: HubTheme.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: HubTheme.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: HubTheme.blue),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            'Model',
            style: HubTheme.bodySmall.copyWith(color: HubTheme.text2),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _showModelPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: HubTheme.card,
                border: Border.all(color: HubTheme.softLine),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedModel,
                      style: const TextStyle(
                        color: HubTheme.text2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    size: 14,
                    color: HubTheme.text2,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: canStart
                ? () {
                    widget.onStart(
                      NewSessionResult(
                        path: _pathController.text.trim(),
                        prompt: _promptController.text.trim(),
                        model: _selectedModel,
                      ),
                    );
                    Navigator.pop(context);
                  }
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: canStart ? HubTheme.green : HubTheme.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: 17,
                    color: canStart ? const Color(0xFF06110B) : HubTheme.text3,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Start Pi Session',
                    style: TextStyle(
                      color: canStart
                          ? const Color(0xFF06110B)
                          : HubTheme.text3,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
