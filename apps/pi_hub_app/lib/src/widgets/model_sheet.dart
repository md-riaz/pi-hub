import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class ModelSheet extends StatelessWidget {
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
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ModelSheet(models: models, selected: selected, onSelect: onSelect),
    );
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
            'Switch model',
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
              itemCount: models.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final model = models[index];
                final selectedModel =
                    model.id == selected || model.name == selected;
                return GestureDetector(
                  onTap: () {
                    onSelect(model.id);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selectedModel
                          ? HubTheme.blue.withValues(alpha: 0.1)
                          : HubTheme.card,
                      border: Border.all(
                        color: selectedModel
                            ? HubTheme.blue.withValues(alpha: 0.4)
                            : HubTheme.softLine,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: HubTheme.blue,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Image capable',
                                      style: TextStyle(
                                        color: HubTheme.blue,
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
                            color: HubTheme.blue,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
