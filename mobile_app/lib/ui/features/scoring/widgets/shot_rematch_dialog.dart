import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/shot_event.dart';
import '../../../../providers/scoring_provider.dart';
import '../../../core/theme.dart';

class ShotRematchSheet extends StatelessWidget {
  final int endNumber;

  const ShotRematchSheet({
    super.key,
    required this.endNumber,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScoringProvider>();
    final session = provider.currentSession;
    final arrowsPerEnd = session?.arrowsPerEnd ?? 6;

    final allShots = provider.sessionShots;
    final endShots = allShots.where((s) => s.matchedEndNumber == endNumber && !s.isIgnored).toList();
    final unmatchedShots = provider.getUnmatchedShots();
    final ignoredShots = allShots.where((s) => s.isIgnored).toList();

    final timeFormatter = DateFormat('HH:mm:ss');

    return Container(
      decoration: const BoxDecoration(
        color: ArcheryColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.watch_outlined, color: ArcheryColors.gold, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'iWatch Shots — End $endNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Kelola pencocokan sensor gerak pergelangan dengan anak panah pada End ini.',
              style: TextStyle(fontSize: 12, color: ArcheryColors.textSecondary),
            ),
            const SizedBox(height: 12),

            // Action toolbar: Auto-Align, Manual Shot, Simulate Shot
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ArcheryColors.gold,
                    side: const BorderSide(color: ArcheryColors.gold, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 14),
                  label: const Text('Auto-Align End', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    await provider.autoAlignShotsForEnd(endNumber);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tembakan otomatis diselaraskan secara sekuensial.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Tandai Manual', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    await provider.recordManualShotForActiveSlot();
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ArcheryColors.accentGreen,
                    side: const BorderSide(color: ArcheryColors.accentGreen, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.sensors, size: 14),
                  label: const Text('Simulasi Sensor', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    await provider.simulateShot();
                  },
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.white12),

            // Shots List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: allShots.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.watch_off_outlined, size: 40, color: Colors.white38),
                            const SizedBox(height: 8),
                            const Text(
                              'Belum ada kandidat tembakan terdeteksi.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gunakan tombol "Simulasi Sensor" di atas atau rekam via Apple Watch.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (endShots.isNotEmpty) ...[
                          _buildSectionTitle('Tembakan Terpasang di End $endNumber (${endShots.length})'),
                          ...endShots.map((shot) => _buildShotTile(context, provider, shot, arrowsPerEnd, timeFormatter)),
                        ],
                        if (unmatchedShots.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildSectionTitle('Kandidat Belum Terpasang (${unmatchedShots.length})'),
                          ...unmatchedShots.map((shot) => _buildShotTile(context, provider, shot, arrowsPerEnd, timeFormatter)),
                        ],
                        if (ignoredShots.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildSectionTitle('Tembakan Diabaikan / False Positive (${ignoredShots.length})'),
                          ...ignoredShots.map((shot) => _buildShotTile(context, provider, shot, arrowsPerEnd, timeFormatter)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: ArcheryColors.gold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildShotTile(
    BuildContext context,
    ScoringProvider provider,
    ShotEvent shot,
    int arrowsPerEnd,
    DateFormat timeFormatter,
  ) {
    final isMatchedThisEnd = shot.matchedEndNumber == endNumber && !shot.isIgnored;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMatchedThisEnd
            ? ArcheryColors.gold.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMatchedThisEnd
              ? ArcheryColors.gold.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          // Matched arrow badge or unassigned icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMatchedThisEnd ? ArcheryColors.gold : Colors.white12,
            ),
            child: Center(
              child: Text(
                shot.isMatched ? 'A${shot.matchedArrowNumber}' : '?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMatchedThisEnd ? Colors.black : Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Telemetry details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      timeFormatter.format(shot.timestamp),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: (shot.confidence >= 0.8 ? ArcheryColors.accentGreen : ArcheryColors.gold).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(shot.confidence * 100).toInt()}% conf',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: shot.confidence >= 0.8 ? ArcheryColors.accentGreen : ArcheryColors.gold,
                        ),
                      ),
                    ),
                    if (shot.isManual) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '(Manual)',
                        style: TextStyle(fontSize: 9, color: Colors.white54),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Peak: ${shot.peakAcceleration.toStringAsFixed(1)}G • Hold: ${(shot.drawDurationMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(fontSize: 10, color: ArcheryColors.textSecondary),
                ),
              ],
            ),
          ),

          // Slot assignment popup menu
          PopupMenuButton<int?>(
            icon: const Icon(Icons.more_vert, size: 18, color: Colors.white70),
            tooltip: 'Atur Penautan',
            onSelected: (arrowNum) async {
              if (arrowNum == null) {
                // Ignore
                await provider.ignoreShot(shot.id);
              } else if (arrowNum == 0) {
                // Unlink
                await provider.unlinkShot(shot.id);
              } else {
                // Link to arrowNum
                await provider.linkShotToArrow(shot.id, endNumber, arrowNum);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem<int?>(
                enabled: false,
                child: Text('Tautkan ke Anak Panah:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              ...List.generate(
                arrowsPerEnd,
                (i) => PopupMenuItem<int?>(
                  value: i + 1,
                  child: Row(
                    children: [
                      Icon(
                        shot.matchedArrowNumber == (i + 1) && shot.matchedEndNumber == endNumber
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: ArcheryColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Text('Anak Panah ${i + 1}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              if (shot.isMatched)
                const PopupMenuItem<int?>(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(Icons.link_off, size: 14, color: Colors.amber),
                      SizedBox(width: 6),
                      Text('Lepas Tautan', style: TextStyle(fontSize: 12, color: Colors.amber)),
                    ],
                  ),
                ),
              PopupMenuItem<int?>(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      shot.isIgnored ? Icons.undo : Icons.delete_outline,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shot.isIgnored ? 'Pulihkan Tembakan' : 'Abaikan (False Positive)',
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
