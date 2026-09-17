import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/scoring_provider.dart';
import '../../../data/models/athlete.dart';
import '../../core/theme.dart';
import 'athlete_dialog.dart';
import '../scoring/scoring_screen.dart';

class CreateSessionSheet extends StatefulWidget {
  final String initialSessionType;

  const CreateSessionSheet({
    super.key,
    this.initialSessionType = 'training',
  });

  @override
  State<CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<CreateSessionSheet> {
  late String _sessionType;
  String _bowCategory = 'Recurve';
  String _distance = '70m';
  int _arrowsPerEnd = 6;
  int _totalEnds = 10;
  Athlete? _selectedAthlete;

  final List<String> _bowCategories = [
    'Recurve',
    'Compound',
    'Barebow',
    'Standard Bow / National',
  ];

  final List<String> _distances = ['70m', '50m', '30m', '18m', 'Custom'];
  final _customDistanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sessionType = widget.initialSessionType;
    final provider = context.read<ScoringProvider>();
    if (provider.athletes.isNotEmpty) {
      _selectedAthlete = provider.selectedAthlete ?? provider.athletes.first;
    }
  }

  @override
  void dispose() {
    _customDistanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScoringProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: ArcheryColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _sessionType == 'competition'
                      ? 'New Competition Round'
                      : 'New Training Session',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ArcheryColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: ArcheryColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: ArcheryColors.borderColor),
            const SizedBox(height: 12),

            // Athlete Selector
            const Text('Athlete', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: ArcheryColors.bgPrimary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ArcheryColors.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Athlete>(
                        value: _selectedAthlete,
                        isExpanded: true,
                        dropdownColor: ArcheryColors.bgCard,
                        hint: const Text('Select an athlete...'),
                        items: provider.athletes.map((ath) {
                          return DropdownMenuItem<Athlete>(
                            value: ath,
                            child: Text('${ath.name} ${ath.athleteCode != null ? "(${ath.athleteCode})" : ""}'),
                          );
                        }).toList(),
                        onChanged: (ath) {
                          setState(() => _selectedAthlete = ath);
                          provider.setSelectedAthlete(ath);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.person_add),
                  onPressed: () async {
                    final created = await showDialog<Athlete>(
                      context: context,
                      builder: (_) => const AthleteDialog(),
                    );
                    if (created != null) {
                      setState(() => _selectedAthlete = created);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bow Category (Recurve, Compound, Barebow, Standard Bow)
            const Text('Bow Category', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: ArcheryColors.bgPrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArcheryColors.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _bowCategory,
                  isExpanded: true,
                  dropdownColor: ArcheryColors.bgCard,
                  items: _bowCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _bowCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Distance
            const Text('Distance', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _distances.map((d) {
                final isSelected = _distance == d;
                return ChoiceChip(
                  label: Text(d),
                  selected: isSelected,
                  selectedColor: ArcheryColors.gold,
                  onSelected: (sel) {
                    if (sel) setState(() => _distance = d);
                  },
                );
              }).toList(),
            ),
            if (_distance == 'Custom') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customDistanceController,
                decoration: InputDecoration(
                  hintText: 'Enter custom distance (e.g. 40m)',
                  filled: true,
                  fillColor: ArcheryColors.bgPrimary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Arrows per End & Total Ends
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Arrows / End', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 3, label: Text('3')),
                          ButtonSegment(value: 6, label: Text('6')),
                        ],
                        selected: {_arrowsPerEnd},
                        onSelectionChanged: (set) => setState(() => _arrowsPerEnd = set.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Number of Ends', style: TextStyle(color: ArcheryColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _totalEnds,
                        dropdownColor: ArcheryColors.bgCard,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: ArcheryColors.bgPrimary,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [2, 5, 6, 10, 12, 20].map((e) => DropdownMenuItem(value: e, child: Text('$e Ends'))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _totalEnds = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        if (_selectedAthlete == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select or create an athlete')),
                          );
                          return;
                        }

                        final effectiveDistance = _distance == 'Custom'
                            ? _customDistanceController.text.trim()
                            : _distance;

                        try {
                          await provider.createSession(
                            athleteId: _selectedAthlete!.id,
                            bowCategory: _bowCategory,
                            sessionType: _sessionType,
                            distance: effectiveDistance.isEmpty ? '18m' : effectiveDistance,
                            arrowsPerEnd: _arrowsPerEnd,
                            totalEnds: _totalEnds,
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // Close sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScoringScreen()),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: provider.isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Start Scoring Session ➔', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
