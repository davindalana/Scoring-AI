import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/scoring_provider.dart';
import '../../../data/models/end_score.dart';
import '../../core/theme.dart';

class AiScanDialog extends StatefulWidget {
  const AiScanDialog({super.key});

  @override
  State<AiScanDialog> createState() => _AiScanDialogState();
}

class _AiScanDialogState extends State<AiScanDialog> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isAnalyzing = false;
  List<ArrowScore> _detectedArrows = [];
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _errorMessage = null;
        });
        await _analyzeTarget();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick image: $e');
    }
  }

  Future<void> _analyzeTarget() async {
    if (_selectedImage == null) return;
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    final provider = context.read<ScoringProvider>();
    try {
      final result = await provider.scanTargetImage(_selectedImage!);
      final rawList = result['detected_arrows'] as List<dynamic>? ?? [];

      setState(() {
        _detectedArrows = rawList.map((item) {
          final s = (item['score'] ?? 'M').toString().toUpperCase();
          final isX = item['is_x'] == true || s == 'X' || s == '10X';
          return ArrowScore(
            arrowNumber: item['arrow_number'] as int,
            score: isX ? '10X' : s,
            isX: isX,
            source: 'ai',
          );
        }).toList();
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _editArrowScore(int index) async {
    final current = _detectedArrows[index];
    final controller = TextEditingController(text: current.isX ? '10X' : current.score);

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArcheryColors.bgCard,
        title: Text('Edit Arrow #${current.arrowNumber}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Enter X, 10, 9..1, or M',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty) {
      final isX = updated == 'X' || updated == '10X';
      setState(() {
        _detectedArrows[index] = ArrowScore(
          arrowNumber: current.arrowNumber,
          score: isX ? '10X' : updated,
          isX: isX,
          source: 'ai',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ArcheryColors.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt, color: ArcheryColors.accentPurple),
                      SizedBox(width: 8),
                      Text('AI Target Detection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: ArcheryColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a photo of your target face. The AI detects concentric rings and arrow positions. You can confirm or correct scores before applying.',
                style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Image capture buttons
              if (_selectedImage == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: ArcheryColors.bgCard),
                        icon: const Icon(Icons.camera, color: ArcheryColors.gold),
                        label: const Text('Camera', style: TextStyle(color: Colors.white)),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library, color: ArcheryColors.blue),
                        label: const Text('Gallery'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.file(_selectedImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
                      if (_isAnalyzing)
                        Container(
                          color: Colors.black54,
                          height: 160,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: ArcheryColors.gold),
                                SizedBox(height: 8),
                                Text('Analyzing rings & arrows...', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retake Photo'),
                  onPressed: () => setState(() {
                    _selectedImage = null;
                    _detectedArrows.clear();
                  }),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],

              if (_detectedArrows.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Detected Scores (Tap chip to edit):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _detectedArrows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final arr = entry.value;
                    final color = ArcheryColors.getColorForScore(arr.score, isX: arr.isX);
                    final textColor = ArcheryColors.getTextColorForScore(arr.score, isX: arr.isX);

                    return InkWell(
                      onTap: () => _editArrowScore(idx),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ArcheryColors.borderColor),
                        ),
                        child: Text(
                          '#${arr.arrowNumber}: ${arr.isX ? "X" : arr.score}',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ArcheryColors.accentPurple),
                    onPressed: () {
                      context.read<ScoringProvider>().applyAiScores(_detectedArrows);
                      Navigator.pop(context);
                    },
                    child: const Text('Confirm & Apply Scores ➔', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
