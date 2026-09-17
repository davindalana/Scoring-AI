import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/scoring_provider.dart';
import '../../../data/models/end_score.dart';
import '../../core/theme.dart';
import 'ai_scan_dialog.dart';
import '../summary/summary_screen.dart';

class ScoringScreen extends StatelessWidget {
  const ScoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScoringProvider>();
    final session = provider.currentSession;
    final athlete = provider.currentSessionAthlete;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scoring Session')),
        body: const Center(child: Text('No active session.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              athlete?.name ?? session.athleteName ?? 'Athlete',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${session.bowCategory} • ${session.distance} • ${session.arrowsPerEnd} arr/end',
              style: const TextStyle(fontSize: 11, color: ArcheryColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ArcheryColors.bgCard,
                  title: const Text('Exit Session?'),
                  content: const Text('Progress is saved automatically on the server.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Top Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Metric Cards
                    Row(
                      children: [
                        _buildMetricCard(
                          'Current End',
                          'End ${provider.currentEndNumber} / ${session.totalEnds}',
                          color: ArcheryColors.gold,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricCard('End Total', '${provider.currentEndTotal}'),
                        const SizedBox(width: 8),
                        _buildMetricCard('End X', '${provider.currentEndXCount}', color: ArcheryColors.gold),
                        const SizedBox(width: 8),
                        _buildMetricCard(
                          'Session Total',
                          '${(provider.currentSessionSummary?.totalScore ?? 0) + provider.currentEndTotal}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Arrow Slots Container
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Arrow Entries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Tap circle to edit', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: provider.currentEndArrows.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final arrow = entry.value;
                                final isActive = idx == provider.activeSlotIndex;
                                final isFilled = arrow.score.isNotEmpty;
                                final bg = ArcheryColors.getColorForScore(arrow.score, isX: arrow.isX);
                                final fg = ArcheryColors.getTextColorForScore(arrow.score, isX: arrow.isX);

                                return GestureDetector(
                                  onTap: () => provider.setActiveSlotIndex(idx),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFilled ? bg : ArcheryColors.bgPrimary,
                                      border: Border.all(
                                        color: isActive
                                            ? ArcheryColors.gold
                                            : (isFilled ? bg : ArcheryColors.borderColor),
                                        width: isActive ? 2.5 : 1.5,
                                      ),
                                      boxShadow: isActive
                                          ? [BoxShadow(color: ArcheryColors.gold.withValues(alpha: 0.4), blurRadius: 8)]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      isFilled ? (arrow.isX ? 'X' : arrow.score) : '${idx + 1}',
                                      style: TextStyle(
                                        color: isFilled ? fg : ArcheryColors.textMuted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Previous Completed Ends in Current Session
                    if (provider.completedEnds.isNotEmpty) ...[
                      const Text('Session Scorecard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.completedEnds.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: ArcheryColors.borderColor),
                          itemBuilder: (ctx, i) {
                            final end = provider.completedEnds[i];
                            return ListTile(
                              dense: true,
                              title: Row(
                                children: [
                                  Text('#${end.endNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4,
                                      children: end.arrows.map((a) {
                                        final bg = ArcheryColors.getColorForScore(a.score, isX: a.isX);
                                        final fg = ArcheryColors.getTextColorForScore(a.score, isX: a.isX);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                                          child: Text(
                                            a.isX ? 'X' : a.score,
                                            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  Text(
                                    '${end.totalScore} pts',
                                    style: const TextStyle(color: ArcheryColors.gold, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16, color: ArcheryColors.textSecondary),
                                    onPressed: () => _showEditEndDialog(context, provider, end),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Fixed Bottom Keypad & Actions
            Container(
              decoration: const BoxDecoration(
                color: ArcheryColors.bgSecondary,
                border: Border(top: BorderSide(color: ArcheryColors.borderColor)),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Keypad Grid
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.6,
                    children: [
                      _buildKeypadButton(provider, 'X', ArcheryColors.gold, Colors.black, isBold: true),
                      _buildKeypadButton(provider, '10', ArcheryColors.gold, Colors.black),
                      _buildKeypadButton(provider, '9', ArcheryColors.gold, Colors.black),
                      _buildKeypadButton(provider, 'M', ArcheryColors.miss, Colors.white70),

                      _buildKeypadButton(provider, '8', ArcheryColors.red, Colors.white),
                      _buildKeypadButton(provider, '7', ArcheryColors.red, Colors.white),
                      _buildKeypadButton(provider, '6', ArcheryColors.blue, Colors.white),
                      _buildKeypadButton(provider, '5', ArcheryColors.blue, Colors.white),

                      _buildKeypadButton(provider, '4', ArcheryColors.black, Colors.white),
                      _buildKeypadButton(provider, '3', ArcheryColors.black, Colors.white),
                      _buildKeypadButton(provider, '2', ArcheryColors.white, Colors.black),
                      _buildKeypadButton(provider, '1', ArcheryColors.white, Colors.black),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      // Undo Button
                      IconButton.filledTonal(
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: provider.undoScore,
                      ),
                      const SizedBox(width: 8),
                      // AI Scan Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ArcheryColors.accentPurple),
                            foregroundColor: ArcheryColors.accentPurple,
                          ),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('AI Scan'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const AiScanDialog(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Save End Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  await provider.submitEnd();
                                  if (context.mounted) {
                                    if (provider.currentSession?.isCompleted == true ||
                                        provider.currentEndNumber > session.totalEnds) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SummaryScreen()),
                                      );
                                    }
                                  }
                                },
                          child: provider.isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save End ➔'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(
    ScoringProvider provider,
    String label,
    Color bg,
    Color fg, {
    bool isBold = false,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => provider.enterScore(label),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: isBold ? 20 : 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, {Color? color}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: ArcheryColors.textSecondary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? ArcheryColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditEndDialog(BuildContext context, ScoringProvider provider, ScoringEnd end) async {
    final controller = TextEditingController(
      text: end.arrows.map((a) => a.isX ? '10X' : (a.score == '0' ? 'M' : a.score)).join(', '),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArcheryColors.bgCard,
        title: Text('Edit End #${end.endNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter arrow scores comma-separated (e.g. 10X, 10, 9, 8, 7, M):',
              style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final parts = result.split(',').map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
      final updatedArrows = parts.asMap().entries.map((e) {
        final isX = e.value == 'X' || e.value == '10X';
        return ArrowScore(
          arrowNumber: e.key + 1,
          score: isX ? '10X' : e.value,
          isX: isX,
          source: 'manual',
        );
      }).toList();

      await provider.editPreviousEnd(end.endNumber, updatedArrows);
    }
  }
}
