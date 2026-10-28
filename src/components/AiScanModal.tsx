import React, { useState, useEffect } from 'react';
import { DetectedArrowPoint } from '../types';
import { detectArrowsFromImage, generateSampleTargetScan } from '../services/targetDetector';
import { useToast } from './Toast';

interface AiScanModalProps {
  isOpen: boolean;
  onClose: () => void;
  arrowCount: number;
  onApplyScores: (detected: DetectedArrowPoint[]) => void;
}

export const AiScanModal: React.FC<AiScanModalProps> = ({
  isOpen,
  onClose,
  arrowCount,
  onApplyScores,
}) => {
  const [isLoading, setIsLoading] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [detectedArrows, setDetectedArrows] = useState<DetectedArrowPoint[]>([]);
  const { showToast } = useToast();

  useEffect(() => {
    if (!isOpen) {
      setIsLoading(false);
      setPreviewUrl(null);
      setDetectedArrows([]);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setIsLoading(true);
    setDetectedArrows([]);

    try {
      const result = await detectArrowsFromImage(file, arrowCount);
      setPreviewUrl(result.previewUrl);
      setDetectedArrows(result.detectedArrows);
      showToast('AI analysis completed! Review detected scores.', 'success');
    } catch (err: any) {
      showToast('AI Detection error: ' + (err.message || 'Failed to detect target'), 'error');
    } finally {
      setIsLoading(false);
      e.target.value = '';
    }
  };

  const handleSampleScan = async () => {
    setIsLoading(true);
    setDetectedArrows([]);

    try {
      const result = await generateSampleTargetScan(arrowCount);
      setPreviewUrl(result.previewUrl);
      setDetectedArrows(result.detectedArrows);
      showToast('Sample target analyzed! Tap any score chip to adjust.', 'success');
    } catch (err: any) {
      showToast('Sample scan error: ' + (err.message || 'Failed to generate scan'), 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCycleScore = (index: number) => {
    const options = ['X', '10', '9', '8', '7', '6', '5', '4', '3', '2', '1', 'M'];
    const currentScore = detectedArrows[index].score;
    const currentIdx = options.indexOf(currentScore);
    const nextIdx = (currentIdx + 1) % options.length;
    const nextScore = options[nextIdx];

    setDetectedArrows(prev =>
      prev.map((item, idx) =>
        idx === index
          ? {
              ...item,
              score: nextScore,
              is_x: nextScore === 'X',
            }
          : item
      )
    );
  };

  const handleConfirmApply = () => {
    if (detectedArrows.length === 0) return;
    onApplyScores(detectedArrows);
    onClose();
  };

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" onClick={onClose}>
      <div className="modal-content modal-lg" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h3 className="modal-title">AI Target & Arrow Detection</h3>
          <button className="close-btn" onClick={onClose} title="Close modal">
            &times;
          </button>
        </div>

        <div>
          <p className="text-secondary text-sm" style={{ marginBottom: '1rem' }}>
            Upload or photograph your target face. The computer vision engine calculates arrow impact
            positions and candidate ring scores. Review and correct each score before confirming.
          </p>

          <div className="file-dropzone">
            <input
              type="file"
              accept="image/*"
              className="file-input-hidden"
              onChange={handleFileChange}
            />
            <div className="dropzone-inner">
              <span className="dropzone-icon">📷</span>
              <div className="dropzone-text">Click or drag & drop target photo here</div>
              <div className="dropzone-sub">Supports JPEG, PNG, WEBP • Camera capture supported</div>
            </div>
          </div>

          <div style={{ marginTop: '0.75rem', textAlign: 'center' }}>
            <button
              type="button"
              className="btn btn-sm btn-secondary w-100"
              onClick={handleSampleScan}
              disabled={isLoading}
            >
              <span>🎯 Try Demo Target Scan (Sample Olympic Target)</span>
            </button>
          </div>

          {isLoading && (
            <div className="loading-ai-box">
              <div className="spinner"></div>
              <div className="loading-ai-text">Detecting target rings & arrow impacts...</div>
            </div>
          )}

          {detectedArrows.length > 0 && !isLoading && (
            <div style={{ marginTop: '1.25rem' }}>
              <div className="ai-results-header">
                <h4>Candidate Scores ({detectedArrows.length} arrows)</h4>
                <span className="text-sm text-secondary">Tap any score chip to cycle/correct</span>
              </div>

              {previewUrl && (
                <div
                  style={{
                    position: 'relative',
                    maxHeight: '220px',
                    borderRadius: 'var(--radius-md)',
                    overflow: 'hidden',
                    marginBottom: '1rem',
                    textAlign: 'center',
                    backgroundColor: '#0a0e17',
                    border: '1px solid var(--border-glass)',
                  }}
                >
                  <img
                    src={previewUrl}
                    alt="Target scan preview"
                    style={{ maxHeight: '220px', objectFit: 'contain', width: '100%' }}
                  />
                </div>
              )}

              <div className="ai-chips-list">
                {detectedArrows.map((arr, idx) => (
                  <button
                    key={idx}
                    type="button"
                    className="btn btn-secondary"
                    style={{ padding: '0.55rem 0.9rem', fontWeight: 700 }}
                    onClick={() => handleCycleScore(idx)}
                    title="Click to cycle score"
                  >
                    <span>Arrow #{arr.arrow_number}:</span>
                    <span style={{ color: 'var(--ring-gold)', fontSize: '1.1rem', marginLeft: '6px' }}>
                      {arr.score}
                    </span>
                    <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)', marginLeft: '4px' }}>
                      ({Math.round(arr.confidence * 100)}%)
                    </span>
                  </button>
                ))}
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', marginTop: '1.5rem' }}>
                <button
                  type="button"
                  className="btn btn-secondary flex-1"
                  onClick={() => {
                    setDetectedArrows([]);
                    setPreviewUrl(null);
                  }}
                >
                  Discard
                </button>
                <button
                  type="button"
                  className="btn btn-primary flex-1"
                  onClick={handleConfirmApply}
                >
                  Confirm & Apply Scores
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
