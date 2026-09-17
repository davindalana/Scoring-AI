import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/scoring_provider.dart';
import '../../core/theme.dart';

class AthleteDialog extends StatefulWidget {
  const AthleteDialog({super.key});

  @override
  State<AthleteDialog> createState() => _AthleteDialogState();
}

class _AthleteDialogState extends State<AthleteDialog> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
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
          Icon(Icons.person_add, color: ArcheryColors.gold),
          SizedBox(width: 8),
          Text('Register Athlete', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: ArcheryColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Full Name *',
                labelStyle: const TextStyle(color: ArcheryColors.textSecondary),
                filled: true,
                fillColor: ArcheryColors.bgPrimary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter athlete name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeController,
              style: const TextStyle(color: ArcheryColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Athlete ID / Code (Optional)',
                labelStyle: const TextStyle(color: ArcheryColors.textSecondary),
                filled: true,
                fillColor: ArcheryColors.bgPrimary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: ArcheryColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: provider.isLoading
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      final athlete = await provider.addAthlete(
                        _nameController.text.trim(),
                        _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context, athlete);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Athlete "${athlete.name}" registered!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
          child: provider.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Register'),
        ),
      ],
    );
  }
}
