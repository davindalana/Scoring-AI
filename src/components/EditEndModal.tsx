import React, { useState, useEffect } from 'react';
import { ScoringEnd, ArrowScore, ScoreValue } from '../types';

interface EditEndModalProps {
  isOpen: boolean;
  onClose: () => void;
  end: ScoringEnd | null;
  onSave: (endNumber: number, arrows: ArrowScore[]) => void;
}

export const EditEndModal: React.FC<EditEndModalProps> = ({
  isOpen,
  onClose,
  end,
  onSave,
}) => {
  const [arrows, setArrows] = useState<ArrowScore[]>(() =>
    end
      ? end.arrows.map((a, idx) => ({
          arrow_number: idx + 1,
          score: (a.score !== null ? (a.is_x ? 'X' : String(a.score)) : null) as ScoreValue,
          is_x: Boolean(a.is_x),
          source: a.source || 'manual',
        }))
      : []
  );
  const [activeSlotIndex, setActiveSlotIndex] = useState(0);

  useEffect(() => {
    if (end) {
      setArrows(
        end.arrows.map((a, idx) => ({
          arrow_number: idx + 1,
          score: (a.score !== null ? (a.is_x ? 'X' : String(a.score)) : null) as ScoreValue,
          is_x: Boolean(a.is_x),
          source: a.source || 'manual',
        }))
      );
      setActiveSlotIndex(0);
    }
  }, [end]);

  if (!isOpen || !end) return null;

  const handleKeyInput = (val: string) => {
    setArrows(prev =>
      prev.map((item, idx) =>
        idx === activeSlotIndex
          ? {
              ...item,
              score: (val === 'X' ? 'X' : val === 'M' ? 'M' : val) as ScoreValue,
              is_x: val === 'X',
            }
          : item
      )
    );

    if (activeSlotIndex < arrows.length - 1) {
      setActiveSlotIndex(activeSlotIndex + 1);
    }
  };

  const getScoreColorClass = (score: ScoreValue, isX: boolean) => {
    if (score === null) return '';
    const s = String(score).toUpperCase();
    if (isX || s === 'X') return 'score-x';
    if (s === '10' || s === '9') return 'score-10';
    if (s === '8' || s === '7') return 'score-8';
    if (s === '6' || s === '5') return 'score-6';
    if (s === '4' || s === '3') return 'score-4';
    if (s === '2' || s === '1') return 'score-2';
    if (s === 'M' || s === '0') return 'score-m';
    return '';
  };

  const handleSave = () => {
    onSave(end.end_number, arrows);
    onClose();
  };

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" onClick={onClose}>
      <div className="modal-content modal-md" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h3 className="modal-title">Edit End #{end.end_number} Scores</h3>
          <button className="close-btn" onClick={onClose} title="Close modal">
            &times;
          </button>
        </div>

        <div>
          <p className="text-secondary text-sm" style={{ marginBottom: '1rem' }}>
            Select an arrow slot below and tap the corrected score.
          </p>

          <div className="arrow-slots-list" style={{ marginBottom: '1.25rem' }}>
            {arrows.map((arr, idx) => {
              const isActive = idx === activeSlotIndex;
              const colorClass = getScoreColorClass(arr.score, arr.is_x);
              return (
                <div
                  key={idx}
                  className={`arrow-slot filled ${colorClass} ${isActive ? 'active' : ''}`}
                  onClick={() => setActiveSlotIndex(idx)}
                >
                  {arr.is_x ? 'X' : (arr.score || idx + 1)}
                </div>
              );
            })}
          </div>

          <div className="keypad-grid" style={{ gap: '0.5rem', marginBottom: '1.5rem' }}>
            <button type="button" className="keypad-btn key-x" onClick={() => handleKeyInput('X')}>X</button>
            <button type="button" className="keypad-btn key-10" onClick={() => handleKeyInput('10')}>10</button>
            <button type="button" className="keypad-btn key-9" onClick={() => handleKeyInput('9')}>9</button>
            <button type="button" className="keypad-btn key-m" onClick={() => handleKeyInput('M')}>M</button>

            <button type="button" className="keypad-btn key-8" onClick={() => handleKeyInput('8')}>8</button>
            <button type="button" className="keypad-btn key-7" onClick={() => handleKeyInput('7')}>7</button>
            <button type="button" className="keypad-btn key-6" onClick={() => handleKeyInput('6')}>6</button>
            <button type="button" className="keypad-btn key-5" onClick={() => handleKeyInput('5')}>5</button>

            <button type="button" className="keypad-btn key-4" onClick={() => handleKeyInput('4')}>4</button>
            <button type="button" className="keypad-btn key-3" onClick={() => handleKeyInput('3')}>3</button>
            <button type="button" className="keypad-btn key-2" onClick={() => handleKeyInput('2')}>2</button>
            <button type="button" className="keypad-btn key-1" onClick={() => handleKeyInput('1')}>1</button>
          </div>

          <div style={{ display: 'flex', gap: '0.75rem' }}>
            <button type="button" className="btn btn-secondary flex-1" onClick={onClose}>
              Cancel
            </button>
            <button type="button" className="btn btn-primary flex-1" onClick={handleSave}>
              Save Corrections
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
