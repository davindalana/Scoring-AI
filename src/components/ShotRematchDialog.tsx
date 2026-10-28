import React, { useState } from 'react';
import { ShotEvent } from '../types';

interface ShotRematchDialogProps {
  isOpen: boolean;
  shotEvent: ShotEvent | null;
  currentArrowNumber: number;
  onConfirmScore: (score: string, isX: boolean) => void;
  onDiscard: () => void;
}

export const ShotRematchDialog: React.FC<ShotRematchDialogProps> = ({
  isOpen,
  shotEvent,
  currentArrowNumber,
  onConfirmScore,
  onDiscard,
}) => {
  const [selectedScore, setSelectedScore] = useState<string>(shotEvent?.suggestedScore || '10');

  React.useEffect(() => {
    if (shotEvent?.suggestedScore) {
      setSelectedScore(shotEvent.suggestedScore);
    }
  }, [shotEvent]);

  if (!isOpen || !shotEvent) return null;

  const scoreOptions = ['X', '10', '9', '8', '7', '6', '5', '4', '3', '2', '1', 'M'];

  const handleConfirm = () => {
    const isX = selectedScore === 'X';
    onConfirmScore(selectedScore, isX);
  };

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" onClick={onDiscard}>
      <div className="modal-content modal-md" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
            <span style={{ fontSize: '1.6rem' }}>⌚</span>
            <div>
              <h3 className="modal-title" style={{ fontSize: '1.2rem' }}>
                Apple Watch Shot Detected!
              </h3>
              <span className="text-secondary text-sm">
                Recorded at {shotEvent.timestamp} • Arrow #{currentArrowNumber}
              </span>
            </div>
          </div>
          <button className="close-btn" onClick={onDiscard} title="Close">
            &times;
          </button>
        </div>

        {/* Biometrics & Motion Recoil telemetry */}
        <div
          style={{
            background: 'var(--bg-main)',
            border: '1px solid var(--border-glass)',
            borderRadius: 'var(--radius-md)',
            padding: '1rem',
            marginBottom: '1.25rem',
            display: 'grid',
            gridTemplateColumns: 'repeat(4, 1fr)',
            gap: '0.5rem',
            textAlign: 'center',
          }}
        >
          <div>
            <div className="metric-label" style={{ fontSize: '0.68rem' }}>Recoil</div>
            <div style={{ color: 'var(--ring-gold)', fontWeight: 800, fontSize: '1.15rem' }}>
              {shotEvent.peakG}G
            </div>
          </div>
          <div>
            <div className="metric-label" style={{ fontSize: '0.68rem' }}>Hold</div>
            <div style={{ fontWeight: 800, fontSize: '1.15rem' }}>
              {shotEvent.holdDurationSec}s
            </div>
          </div>
          <div>
            <div className="metric-label" style={{ fontSize: '0.68rem' }}>Heart Rate</div>
            <div style={{ color: '#f87171', fontWeight: 800, fontSize: '1.15rem' }}>
              {shotEvent.heartRateBpm} <span style={{ fontSize: '0.75rem', fontWeight: 400 }}>bpm</span>
            </div>
          </div>
          <div>
            <div className="metric-label" style={{ fontSize: '0.68rem' }}>Stability</div>
            <div style={{ color: 'var(--accent-emerald)', fontWeight: 800, fontSize: '1.15rem' }}>
              {shotEvent.stabilityScore}%
            </div>
          </div>
        </div>

        {/* Score adjustment section */}
        <div>
          <div style={{ marginBottom: '0.5rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>Confirm Arrow Score:</span>
            <span className="text-secondary text-sm">Tap below if rematch is required</span>
          </div>

          <div
            className="keypad-grid"
            style={{
              gridTemplateColumns: 'repeat(6, 1fr)',
              gap: '0.45rem',
              marginBottom: '1.5rem',
            }}
          >
            {scoreOptions.map(sc => {
              const isSelected = selectedScore === sc;
              return (
                <button
                  key={sc}
                  type="button"
                  className={`btn ${isSelected ? 'btn-primary' : 'btn-secondary'}`}
                  style={{
                    padding: '0.6rem 0.2rem',
                    fontWeight: 800,
                    fontSize: '1.1rem',
                    border: isSelected ? '2px solid #fff' : undefined,
                  }}
                  onClick={() => setSelectedScore(sc)}
                >
                  {sc}
                </button>
              );
            })}
          </div>

          <div style={{ display: 'flex', gap: '0.75rem' }}>
            <button
              type="button"
              className="btn btn-secondary flex-1"
              onClick={onDiscard}
            >
              Discard False Shot
            </button>
            <button
              type="button"
              className="btn btn-primary flex-1"
              onClick={handleConfirm}
            >
              Accept {selectedScore} Score ➔
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
