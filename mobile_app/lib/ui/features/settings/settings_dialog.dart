import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/scoring_provider.dart';
import '../../core/theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ScoringProvider>();
    _urlController = TextEditingController(text: provider.apiService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScoringProvider>();

    return AlertDialog(
      backgroundColor: ArcheryColors.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.settings, color: ArcheryColors.gold),
          SizedBox(width: 8),
          Text('Server Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FastAPI Backend Server URL:',
            style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: ArcheryColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: ArcheryColors.bgPrimary,
              hintText: 'e.g. http://10.0.2.2:8000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ArcheryColors.borderColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Emulator (10.0.2.2)'),
                onPressed: () => _urlController.text = 'http://10.0.2.2:8000',
              ),
              ActionChip(
                label: const Text('Localhost'),
                onPressed: () => _urlController.text = 'http://localhost:8000',
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: ArcheryColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () async {
            await provider.apiService.setBaseUrl(_urlController.text);
            await provider.init();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Server URL set to ${_urlController.text}')),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
