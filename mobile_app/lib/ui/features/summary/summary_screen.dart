import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/scoring_provider.dart';
import '../../../data/models/session_summary.dart';
import '../../core/theme.dart';
import '../session/create_session_sheet.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScoringProvider>();
    final session = provider.currentSession;
    final summary = provider.currentSessionSummary;
    final athlete = provider.currentSessionAthlete;
    final ends = provider.completedEnds;

    if (session == null || summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Summary')),
        body: const Center(child: Text('No session data found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Summary'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Celebration Card
            Card(
              color: ArcheryColors.gold.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: ArcheryColors.gold),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      const Text(
                        'Session Completed! 🎯',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${athlete?.name ?? session.athleteName ?? "Athlete"} • ${session.bowCategory} • ${session.distance} • ${session.sessionType.toUpperCase()}',
                        style: const TextStyle(color: ArcheryColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Key Metrics
            Row(
              children: [
                _buildMetricCard('Final Score', '${summary.totalScore}', color: ArcheryColors.gold),
                const SizedBox(width: 8),
                _buildMetricCard('Total X', '${summary.totalX}', color: ArcheryColors.gold),
                const SizedBox(width: 8),
                _buildMetricCard('Avg / Arrow', summary.averageScorePerArrow.toStringAsFixed(2)),
                const SizedBox(width: 8),
                _buildMetricCard('Avg / End', summary.averageScorePerEnd.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 16),

            // Highlights Row
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Highest End', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          summary.highestScoringEnd != null
                              ? '${summary.highestScoringEnd!.score} pts (End ${summary.highestScoringEnd!.endNumber})'
                              : '--',
                          style: const TextStyle(color: ArcheryColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: ArcheryColors.borderColor),
                    Column(
                      children: [
                        const Text('Lowest End', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          summary.lowestScoringEnd != null
                              ? '${summary.lowestScoringEnd!.score} pts (End ${summary.lowestScoringEnd!.endNumber})'
                              : '--',
                          style: const TextStyle(color: ArcheryColors.red, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: ArcheryColors.borderColor),
                    Column(
                      children: [
                        const Text('Total Arrows', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.totalArrows}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Score Progression Chart
            if (summary.endsSummary.isNotEmpty) ...[
              const Text('Score Progression', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16, right: 20, left: 10),
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx > 0 && idx <= summary.endsSummary.length) {
                                  return Text('E$idx', style: const TextStyle(color: ArcheryColors.textMuted, fontSize: 10));
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: summary.endsSummary.asMap().entries.map((entry) {
                              return FlSpot((entry.key + 1).toDouble(), entry.value.cumulativeScore.toDouble());
                            }).toList(),
                            isCurved: true,
                            color: ArcheryColors.gold,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: ArcheryColors.gold.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // End-by-End Scorecard Table
            const Text('Official Scorecard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 14,
                  headingRowColor: WidgetStateProperty.all(ArcheryColors.bgSecondary),
                  columns: const [
                    DataColumn(label: Text('End', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Arrows', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('X', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: ends.map((end) {
                    final sumItem = summary.endsSummary.firstWhere(
                      (e) => e.endNumber == end.endNumber,
                      orElse: () => EndSummaryItem(
                        endNumber: end.endNumber,
                        totalScore: end.totalScore,
                        xCount: end.xCount,
                        arrowCount: end.arrows.length,
                        cumulativeScore: end.totalScore,
                      ),
                    );

                    return DataRow(
                      cells: [
                        DataCell(Text('#${end.endNumber}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: end.arrows.map((a) {
                              final bg = ArcheryColors.getColorForScore(a.score, isX: a.isX);
                              final fg = ArcheryColors.getTextColorForScore(a.score, isX: a.isX);
                              return Container(
                                margin: const EdgeInsets.only(right: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                                child: Text(a.isX ? 'X' : a.score, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          ),
                        ),
                        DataCell(Text('${end.totalScore}', style: const TextStyle(color: ArcheryColors.gold, fontWeight: FontWeight.bold))),
                        DataCell(Text('${end.xCount}')),
                        DataCell(Text('${sumItem.cumulativeScore}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('Back to Home'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const CreateSessionSheet(),
                      );
                    },
                    child: const Text('New Session ➔'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, {Color? color}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: ArcheryColors.textSecondary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? ArcheryColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
