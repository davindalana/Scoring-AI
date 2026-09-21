import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/scoring_provider.dart';
import '../../core/theme.dart';
import '../session/create_session_sheet.dart';
import '../session/athlete_dialog.dart';
import '../settings/settings_dialog.dart';
import '../scoring/scoring_screen.dart';
import '../summary/summary_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScoringProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ArcheryColors.gold,
                    ArcheryColors.red,
                    ArcheryColors.blue,
                    ArcheryColors.black,
                  ],
                  stops: [0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Archery Score Pro'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              provider.isOfflineMode ? Icons.cloud_off : Icons.cloud_done,
              color: provider.isOfflineMode ? ArcheryColors.gold : ArcheryColors.accentGreen,
            ),
            tooltip: provider.isOfflineMode
                ? 'Offline Mode Active (Tap to switch online)'
                : 'Online Mode Active (Tap to switch offline)',
            onPressed: () => provider.toggleOfflineMode(),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add Athlete',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AthleteDialog(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadSessions();
          await provider.loadAthletes();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Offline Status Banner
            if (provider.isOfflineMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: ArcheryColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ArcheryColors.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: ArcheryColors.gold, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Offline Mode Active — Scores are saved locally on this device.',
                        style: TextStyle(color: ArcheryColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => provider.toggleOfflineMode(false),
                      child: const Text('Try Online', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],

            // Active Athlete Banner
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: ArcheryColors.gold,
                      foregroundColor: Colors.black,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Athlete', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 11)),
                          Text(
                            provider.selectedAthlete?.name ?? 'No Athlete Selected',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showSelectAthleteDialog(context, provider),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Cards: Training vs Competition
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    title: 'Training',
                    subtitle: 'Practice ends & groupings',
                    icon: Icons.track_changes,
                    iconColor: ArcheryColors.gold,
                    onTap: () => _openCreateSessionSheet(context, 'training'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    title: 'Competition',
                    subtitle: 'Official tournament rounds',
                    icon: Icons.emoji_events_outlined,
                    iconColor: ArcheryColors.red,
                    onTap: () => _openCreateSessionSheet(context, 'competition'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Sessions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${provider.sessions.length} recorded', style: const TextStyle(color: ArcheryColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),

            if (provider.isLoading && provider.sessions.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (provider.sessions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(Icons.sports_score, size: 48, color: ArcheryColors.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'No scoring sessions yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Training" or "Competition" above to record your first ends.',
                        style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.sessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final s = provider.sessions[i];
                  final isComplete = s.isCompleted;

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        s.athleteName ?? 'Athlete',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        '${s.bowCategory} • ${s.distance} • ${s.arrowsPerEnd} arr/end',
                        style: const TextStyle(color: ArcheryColors.textSecondary, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? ArcheryColors.accentGreen.withValues(alpha: 0.15)
                                  : ArcheryColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isComplete ? 'Finished' : 'End ${s.currentEnd}/${s.totalEnds}',
                              style: TextStyle(
                                color: isComplete ? ArcheryColors.accentGreen : ArcheryColors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, color: ArcheryColors.textSecondary),
                        ],
                      ),
                      onTap: () async {
                        await provider.openSession(s.id);
                        if (context.mounted) {
                          if (isComplete) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SummaryScreen()),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScoringScreen()),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: ArcheryColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateSessionSheet(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateSessionSheet(initialSessionType: type),
    );
  }

  void _showSelectAthleteDialog(BuildContext context, ScoringProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArcheryColors.bgCard,
        title: const Text('Select Active Athlete'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.athletes.length,
            itemBuilder: (c, idx) {
              final a = provider.athletes[idx];
              final isSel = provider.selectedAthlete?.id == a.id;
              return ListTile(
                title: Text(a.name, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                subtitle: a.athleteCode != null ? Text(a.athleteCode!) : null,
                trailing: isSel ? const Icon(Icons.check, color: ArcheryColors.gold) : null,
                onTap: () {
                  provider.setSelectedAthlete(a);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(context: context, builder: (_) => const AthleteDialog());
            },
            child: const Text('+ New Athlete'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }
}
