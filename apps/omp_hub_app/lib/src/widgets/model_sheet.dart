import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class ModelSheet extends StatefulWidget {
  final List<HubModel> models;
  final String selected;
  final ValueChanged<String> onSelect;

  const ModelSheet({
    super.key,
    required this.models,
    required this.selected,
    required this.onSelect,
  });

  static void show(
    BuildContext context, {
    required List<HubModel> models,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ModelSheet(models: models, selected: selected, onSelect: onSelect),
    );
  }

  @override
  State<ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<ModelSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HubModel> get _sortedModels {
    final models = [...widget.models];
    models.sort((a, b) => _sortLabel(a).compareTo(_sortLabel(b)));
    return models;
  }

  List<HubModel> get _filteredModels {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _sortedModels;
    return _sortedModels.where((model) {
      final searchable = [
        model.id,
        model.name,
        model.provider ?? '',
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  String _sortLabel(HubModel model) {
    final name = model.name.trim();
    return (name.isNotEmpty ? name : model.id).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final filteredModels = _filteredModels;
    return Container(
      decoration: const BoxDecoration(
        color: HubTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: HubTheme.softLine)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HubTheme.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Switch model',
                style: TextStyle(
                  color: HubTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: widget.models.length > 8,
                style: const TextStyle(color: HubTheme.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search models',
                  hintStyle: const TextStyle(color: HubTheme.text3),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: HubTheme.text3,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: HubTheme.text3,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: HubTheme.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: HubTheme.softLine),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: HubTheme.accent),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: filteredModels.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No models found',
                          style: TextStyle(color: HubTheme.text3),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredModels.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final model = filteredModels[index];
                          final selectedModel =
                              model.id == widget.selected ||
                              model.name == widget.selected;
                          return GestureDetector(
                            onTap: () {
                              widget.onSelect(model.id);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: selectedModel
                                    ? HubTheme.accentSoft
                                    : HubTheme.card,
                                border: Border.all(
                                  color: selectedModel
                                      ? HubTheme.accent
                                      : HubTheme.softLine,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          model.id,
                                          style: const TextStyle(
                                            color: HubTheme.text,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (model.supportsImages) ...[
                                          const SizedBox(height: 4),
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.image_outlined,
                                                size: 13,
                                                color: HubTheme.accent,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Image capable',
                                                style: TextStyle(
                                                  color: HubTheme.accent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (selectedModel)
                                    const Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: HubTheme.accent,
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
  }
}
