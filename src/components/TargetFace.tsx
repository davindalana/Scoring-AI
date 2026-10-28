import React, { useState } from 'react';

interface TargetFaceProps {
  onScoreSelect: (score: string) => void;
  activeRingHighlight?: string | null;
}

export const TargetFace: React.FC<TargetFaceProps> = ({ onScoreSelect, activeRingHighlight }) => {
  const [litRing, setLitRing] = useState<string | null>(null);

  const handleRingClick = (val: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setLitRing(val);
    onScoreSelect(val);
    setTimeout(() => {
      setLitRing(null);
    }, 350);
  };

  const isLit = (val: string) => litRing === val || activeRingHighlight === val;

  return (
    <div className="target-face-card card" id="targetFaceWrapper">
      <div className="target-header">
        <span className="target-card-title">Olympic Target Face</span>
        <span className="target-hint">Tap any ring to score</span>
      </div>
      <div className="svg-target-container">
        <svg viewBox="-130 -130 260 260" className="interactive-target">
          {/* Rings from outer to inner */}
          {/* Ring 1 (White) */}
          <circle
            r="120"
            className={`target-ring ring-1 ${isLit('1') ? 'lit' : ''}`}
            onClick={e => handleRingClick('1', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 2 (White) */}
          <circle
            r="108"
            className={`target-ring ring-2 ${isLit('2') ? 'lit' : ''}`}
            onClick={e => handleRingClick('2', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 3 (Black) */}
          <circle
            r="96"
            className={`target-ring ring-3 ${isLit('3') ? 'lit' : ''}`}
            onClick={e => handleRingClick('3', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 4 (Black) */}
          <circle
            r="84"
            className={`target-ring ring-4 ${isLit('4') ? 'lit' : ''}`}
            onClick={e => handleRingClick('4', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 5 (Blue) */}
          <circle
            r="72"
            className={`target-ring ring-5 ${isLit('5') ? 'lit' : ''}`}
            onClick={e => handleRingClick('5', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 6 (Blue) */}
          <circle
            r="60"
            className={`target-ring ring-6 ${isLit('6') ? 'lit' : ''}`}
            onClick={e => handleRingClick('6', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 7 (Red) */}
          <circle
            r="48"
            className={`target-ring ring-7 ${isLit('7') ? 'lit' : ''}`}
            onClick={e => handleRingClick('7', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 8 (Red) */}
          <circle
            r="36"
            className={`target-ring ring-8 ${isLit('8') ? 'lit' : ''}`}
            onClick={e => handleRingClick('8', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 9 (Gold) */}
          <circle
            r="24"
            className={`target-ring ring-9 ${isLit('9') ? 'lit' : ''}`}
            onClick={e => handleRingClick('9', e)}
            cx="0"
            cy="0"
          />
          {/* Ring 10 (Gold) */}
          <circle
            r="12"
            className={`target-ring ring-10 ${isLit('10') ? 'lit' : ''}`}
            onClick={e => handleRingClick('10', e)}
            cx="0"
            cy="0"
          />
          {/* Inner X ring (Gold Bullseye) */}
          <circle
            r="6"
            className={`target-ring ring-x ${isLit('X') ? 'lit' : ''}`}
            onClick={e => handleRingClick('X', e)}
            cx="0"
            cy="0"
          />
          {/* Crosshairs */}
          <line x1="-5" y1="0" x2="5" y2="0" stroke="#000" strokeWidth="0.8" opacity="0.7" pointerEvents="none" />
          <line x1="0" y1="-5" x2="0" y2="5" stroke="#000" strokeWidth="0.8" opacity="0.7" pointerEvents="none" />
        </svg>
      </div>
      <div className="target-legend">
        <span className="legend-chip gold-chip">Gold (X, 10, 9)</span>
        <span className="legend-chip red-chip">Red (8, 7)</span>
        <span className="legend-chip blue-chip">Blue (6, 5)</span>
        <span className="legend-chip black-chip">Black (4, 3)</span>
        <span className="legend-chip white-chip">White (2, 1)</span>
      </div>
    </div>
  );
};
