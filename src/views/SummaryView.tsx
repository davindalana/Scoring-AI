import React, { useState, useEffect } from 'react';
import { SessionDetails, ScoringEnd, ArrowScore } from '../types';
import { StorageService } from '../services/storage';
import { ProgressionChart } from '../components/ProgressionChart';
import { EditEndModal } from '../components/EditEndModal';
import { useToast } from '../components/Toast';

interface SummaryViewProps {
  details: SessionDetails;
  onBackHome: () => void;
  onNewSession: () => void;
}

export const SummaryView: React.FC<SummaryViewProps> = ({
  details: initialDetails,
  onBackHome,
  onNewSession,
}) => {
  const [details, setDetails] = useState<SessionDetails>(initialDetails);
  const [editingEnd, setEditingEnd] = useState<ScoringEnd | null>(null);
  const { showToast } = useToast();

  useEffect(() => {
    setDetails(initialDetails);
  }, [initialDetails]);

  const { session, athlete, ends, summary } = details;
  const athleteName = athlete ? athlete.name : session.athlete_name || 'Athlete';

  let goldCount = 0;
  ends.forEach(end => {
    end.arrows.forEach(arr => {
      const s = String(arr.score).toUpperCase();
      if (arr.is_x || s === 'X' || s === '10') {
        goldCount++;
      }
    });
  });

  const goldPercent =
    summary.total_arrows > 0
      ? `${Math.round((goldCount / summary.total_arrows) * 100)}%`
      : '0%';

  const handlePrint = () => {
    window.print();
  };

  const handleSaveEditedEnd = (endNumber: number, editedArrows: ArrowScore[]) => {
    try {
      const updated = StorageService.updateEnd(session.id, endNumber, editedArrows);
      setDetails(updated);
      showToast(`End #${endNumber} updated in official scorecard!`, 'success');
    } catch {
      showToast('Failed to update end scores.', 'error');
    }
  };

  return (
    <section className="view-section">
      {/* Hero Banner */}
      <div className="summary-hero card">
        <div className="summary-badge">Round Finished</div>
        <h2>Session Complete! 🎉</h2>
        <p className="summary-meta">
          {athleteName} • {session.bow_category} • {session.distance} •{' '}
          {session.session_type.toUpperCase()}
        </p>
      </div>

      {/* Metrics Dashboard */}
      <div className="scoring-dashboard">
        <div className="metric-card gold-glow">
          <div className="metric-label">Final Score</div>
          <div className="metric-value gold">{summary.total_score}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Total X</div>
          <div className="metric-value gold">{summary.total_x}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Average / Arrow</div>
          <div className="metric-value">{summary.average_score_per_arrow.toFixed(2)}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Average / End</div>
          <div className="metric-value">{summary.average_score_per_end.toFixed(1)}</div>
        </div>
      </div>

      {/* Highlights Card */}
      <div className="card highlights-card">
        <div className="highlight-item">
          <div className="highlight-label">Highest End</div>
          <div className="highlight-val green-text">
            {summary.highest_scoring_end
              ? `${summary.highest_scoring_end.score} pts (End ${summary.highest_scoring_end.end_number})`
              : '--'}
          </div>
        </div>
        <div className="highlight-divider"></div>
        <div className="highlight-item">
          <div className="highlight-label">Lowest End</div>
          <div className="highlight-val red-text">
            {summary.lowest_scoring_end
              ? `${summary.lowest_scoring_end.score} pts (End ${summary.lowest_scoring_end.end_number})`
              : '--'}
          </div>
        </div>
        <div className="highlight-divider"></div>
        <div className="highlight-item">
          <div className="highlight-label">Total Arrows</div>
          <div className="highlight-val">{summary.total_arrows}</div>
        </div>
        <div className="highlight-divider"></div>
        <div className="highlight-item">
          <div className="highlight-label">Gold % (10+X)</div>
          <div className="highlight-val gold">{goldPercent}</div>
        </div>
      </div>

      {/* Score Progression & End Breakdown Chart */}
      <div className="card chart-card no-print">
        <div className="chart-header">
          <h3>Score Progression & End Breakdown</h3>
          <span className="text-secondary text-sm">
            Line: Cumulative Total • Bars: End Score
          </span>
        </div>
        <div className="chart-container" style={{ height: 'auto' }}>
          <ProgressionChart endsSummary={summary.ends_summary} />
        </div>
      </div>

      {/* Printable Official Scorecard */}
      <div className="card scorecard-card" id="printableScorecardArea">
        <div className="printable-header">
          <div>
            <h3>Official Scorecard</h3>
            <p className="text-secondary text-sm">
              World Archery Target Round • {athleteName} ({session.bow_category},{' '}
              {session.distance})
            </p>
          </div>
          <button
            type="button"
            className="btn btn-secondary no-print"
            onClick={handlePrint}
            title="Print or export to PDF"
          >
            <span>🖨️ Print / Save PDF</span>
          </button>
        </div>
        <div className="table-responsive">
          <table className="score-table printable-table">
            <thead>
              <tr>
                <th>End</th>
                <th>Arrows</th>
                <th>End Total</th>
                <th>X</th>
                <th>Cumulative</th>
                <th className="no-print">Action</th>
              </tr>
            </thead>
            <tbody>
              {ends.map(end => {
                const summItem = summary.ends_summary.find(
                  e => e.end_number === end.end_number
                );
                const cumulativeVal = summItem
                  ? summItem.cumulative_score
                  : end.total_score;

                return (
                  <tr key={end.end_number}>
                    <td style={{ fontWeight: 700 }}>End {end.end_number}</td>
                    <td>
                      {end.arrows.map((a, i) => (
                        <span key={i} className="arrow-chip-display">
                          {a.is_x
                            ? 'X'
                            : String(a.score) === '0' || a.score === 'M'
                            ? 'M'
                            : a.score}
                        </span>
                      ))}
                    </td>
                    <td style={{ fontWeight: 700, color: 'var(--ring-gold)' }}>
                      {end.total_score}
                    </td>
                    <td>{end.x_count}</td>
                    <td style={{ fontWeight: 800 }}>{cumulativeVal}</td>
                    <td className="no-print">
                      <button
                        type="button"
                        className="btn btn-sm btn-secondary"
                        onClick={() => setEditingEnd(end)}
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Navigation Actions */}
      <div className="summary-actions no-print">
        <button
          type="button"
          className="btn btn-secondary flex-1"
          onClick={onBackHome}
        >
          Back to Home
        </button>
        <button
          type="button"
          className="btn btn-primary flex-1"
          onClick={onNewSession}
        >
          Start Another Session
        </button>
      </div>

      {/* Edit End Modal for Post-Round Corrections */}
      <EditEndModal
        isOpen={Boolean(editingEnd)}
        end={editingEnd}
        onClose={() => setEditingEnd(null)}
        onSave={handleSaveEditedEnd}
      />
    </section>
  );
};
