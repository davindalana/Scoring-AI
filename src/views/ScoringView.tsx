import React, { useState, useEffect, useCallback } from 'react';
import { SessionDetails, ArrowScore, ScoreValue, ScoringEnd, DetectedArrowPoint, ShotEvent } from '../types';
import { StorageService, parseArrowPoints } from '../services/storage';
import { watchService } from '../services/watchService';
import { TargetFace } from '../components/TargetFace';
import { Keypad } from '../components/Keypad';
import { EditEndModal } from '../components/EditEndModal';
import { AiScanModal } from '../components/AiScanModal';
import { ConfirmModal } from '../components/ConfirmModal';
import { ShotRematchDialog } from '../components/ShotRematchDialog';
import { useToast } from '../components/Toast';

interface ScoringViewProps {
  sessionId: number;
  onExitSession: () => void;
  onSessionCompleted: (details: SessionDetails) => void;
  onOpenWatchModal: () => void;
  initialPendingShot?: ShotEvent | null;
  onClearPendingShot?: () => void;
}

export const ScoringView: React.FC<ScoringViewProps> = ({
  sessionId,
  onExitSession,
  onSessionCompleted,
  onOpenWatchModal,
  initialPendingShot = null,
  onClearPendingShot,
}) => {
  const [details, setDetails] = useState<SessionDetails | null>(() =>
    StorageService.getSessionDetails(sessionId)
  );
  const [currentArrows, setCurrentArrows] = useState<ArrowScore[]>(() => {
    const initialData = StorageService.getSessionDetails(sessionId);
    const count = initialData?.session.arrows_per_end || 6;
    return Array.from({ length: count }, (_, idx) => ({
      arrow_number: idx + 1,
      score: null,
      is_x: false,
      source: 'manual',
    }));
  });
  const [activeSlotIndex, setActiveSlotIndex] = useState(0);
  const [showTarget, setShowTarget] = useState(true);
  const [activeHighlightRing, setActiveHighlightRing] = useState<string | null>(null);

  // Modals state
  const [editingEnd, setEditingEnd] = useState<ScoringEnd | null>(null);
  const [isAiScanOpen, setIsAiScanOpen] = useState(false);
  const [isExitConfirmOpen, setIsExitConfirmOpen] = useState(false);
  const [isIncompleteConfirmOpen, setIsIncompleteConfirmOpen] = useState(false);
  const [detectedShotEvent, setDetectedShotEvent] = useState<ShotEvent | null>(initialPendingShot);

  const { showToast } = useToast();

  useEffect(() => {
    if (initialPendingShot) {
      setDetectedShotEvent(initialPendingShot);
      if (onClearPendingShot) onClearPendingShot();
    }
  }, [initialPendingShot, onClearPendingShot]);

  const loadSession = useCallback(() => {
    const data = StorageService.getSessionDetails(sessionId);
    if (!data) return;
    setDetails(data);

    if (data.session.status === 'completed') {
      onSessionCompleted(data);
      return;
    }

    const slots: ArrowScore[] = [];
    for (let i = 1; i <= data.session.arrows_per_end; i++) {
      slots.push({
        arrow_number: i,
        score: null,
        is_x: false,
        source: 'manual',
      });
    }
    setCurrentArrows(slots);
    setActiveSlotIndex(0);
  }, [sessionId, onSessionCompleted]);

  useEffect(() => {
    loadSession();
  }, [loadSession]);

  const triggerHaptic = () => {
    if ('vibrate' in navigator) {
      try {
        navigator.vibrate(15);
      } catch (_) {}
    }
  };

  const handleInputScore = useCallback(
    (scoreVal: string, source: 'manual' | 'watch' | 'target_face' = 'manual') => {
      triggerHaptic();
      const maxSlots = details?.session.arrows_per_end || 6;

      setCurrentArrows(prev =>
        prev.map((item, idx) =>
          idx === activeSlotIndex
            ? {
                ...item,
                score: (scoreVal === 'X' ? 'X' : scoreVal === 'M' ? 'M' : scoreVal) as ScoreValue,
                is_x: scoreVal === 'X',
                source,
              }
            : item
        )
      );

      setActiveHighlightRing(scoreVal);
      setTimeout(() => setActiveHighlightRing(null), 300);

      if (activeSlotIndex < maxSlots - 1) {
        setActiveSlotIndex(activeSlotIndex + 1);
      }
    },
    [activeSlotIndex, details]
  );

  // Subscribe to Apple Watch shot events and wrist score inputs
  useEffect(() => {
    const unsubShots = watchService.subscribeShots((event: ShotEvent) => {
      setDetectedShotEvent(event);
    });
    const unsubWrist = watchService.subscribeWristScores((scoreVal: string) => {
      handleInputScore(scoreVal, 'watch');
    });
    return () => {
      unsubShots();
      unsubWrist();
    };
  }, [handleInputScore]);

  // Sync live scoring state to Apple Watch companion
  useEffect(() => {
    if (!details) return;
    const { session, athlete, summary } = details;
    const athleteName = athlete ? athlete.name : session.athlete_name || 'Athlete';

    let endScore = 0;
    currentArrows.forEach(a => {
      if (a.score !== null) {
        endScore += parseArrowPoints(a.score, a.is_x).points;
      }
    });

    watchService.syncLiveScoring({
      sessionId: session.id,
      athleteName,
      bowCategory: session.bow_category,
      distance: session.distance,
      currentEnd: session.current_end,
      totalEnds: session.total_ends,
      endScore,
      sessionTotal: (summary?.total_score || 0) + endScore,
      activeSlotIndex,
      arrowsPerEnd: session.arrows_per_end,
      currentArrows,
    });

    return () => {
      watchService.syncLiveScoring(null);
    };
  }, [details, currentArrows, activeSlotIndex]);

  const handleUndo = useCallback(() => {
    triggerHaptic();
    const currentSlot = currentArrows[activeSlotIndex];

    if (currentSlot && currentSlot.score !== null) {
      setCurrentArrows(prev =>
        prev.map((item, idx) =>
          idx === activeSlotIndex ? { ...item, score: null, is_x: false } : item
        )
      );
    } else if (activeSlotIndex > 0) {
      const prevIdx = activeSlotIndex - 1;
      setActiveSlotIndex(prevIdx);
      setCurrentArrows(prev =>
        prev.map((item, idx) =>
          idx === prevIdx ? { ...item, score: null, is_x: false } : item
        )
      );
    }
  }, [activeSlotIndex, currentArrows]);

  const executeSaveEnd = useCallback(
    (arrowsToSubmit: ArrowScore[]) => {
      if (!details) return;
      try {
        const result = StorageService.saveEnd(
          details.session.id,
          details.session.current_end,
          arrowsToSubmit
        );
        showToast(`End #${details.session.current_end} saved!`, 'success');

        const updatedDetails = StorageService.getSessionDetails(details.session.id)!;
        setDetails(updatedDetails);

        if (
          result.session.status === 'completed' ||
          details.session.current_end >= details.session.total_ends
        ) {
          onSessionCompleted(updatedDetails);
        } else {
          const slots: ArrowScore[] = [];
          for (let i = 1; i <= result.session.arrows_per_end; i++) {
            slots.push({
              arrow_number: i,
              score: null,
              is_x: false,
              source: 'manual',
            });
          }
          setCurrentArrows(slots);
          setActiveSlotIndex(0);
        }
      } catch {
        showToast('Failed to save end.', 'error');
      }
    },
    [details, onSessionCompleted, showToast]
  );

  const handleSubmitEnd = useCallback(() => {
    const unfilled = currentArrows.filter(a => a.score === null);
    if (unfilled.length > 0) {
      setIsIncompleteConfirmOpen(true);
      return;
    }
    executeSaveEnd(currentArrows);
  }, [currentArrows, executeSaveEnd]);

  // Keyboard shortcuts listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && ['input', 'select', 'textarea'].includes(target.tagName.toLowerCase())) {
        return;
      }

      if (
        editingEnd ||
        isAiScanOpen ||
        isExitConfirmOpen ||
        isIncompleteConfirmOpen ||
        detectedShotEvent
      ) {
        return;
      }

      const k = e.key.toUpperCase();
      if (k === 'X') {
        e.preventDefault();
        handleInputScore('X');
      } else if (k === 'M') {
        e.preventDefault();
        handleInputScore('M');
      } else if (k === '0') {
        e.preventDefault();
        handleInputScore('10');
      } else if (k >= '1' && k <= '9') {
        e.preventDefault();
        handleInputScore(k);
      } else if (e.key === 'Backspace' || e.key === 'Delete') {
        e.preventDefault();
        handleUndo();
      } else if (e.key === 'Enter') {
        e.preventDefault();
        handleSubmitEnd();
      } else if (e.key === 'ArrowLeft') {
        e.preventDefault();
        if (activeSlotIndex > 0) setActiveSlotIndex(activeSlotIndex - 1);
      } else if (e.key === 'ArrowRight') {
        e.preventDefault();
        if (details && activeSlotIndex < details.session.arrows_per_end - 1) {
          setActiveSlotIndex(activeSlotIndex + 1);
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [
    handleInputScore,
    handleUndo,
    handleSubmitEnd,
    activeSlotIndex,
    details,
    editingEnd,
    isAiScanOpen,
    isExitConfirmOpen,
    isIncompleteConfirmOpen,
    detectedShotEvent,
  ]);

  const handleApplyAiScores = (detected: DetectedArrowPoint[]) => {
    setCurrentArrows(prev =>
      prev.map((slot, idx) => {
        const match = detected.find(d => d.arrow_number === idx + 1);
        if (match) {
          return {
            ...slot,
            score: match.score as ScoreValue,
            is_x: match.is_x,
            source: 'ai',
          };
        }
        return slot;
      })
    );
    if (details && detected.length > 0) {
      setActiveSlotIndex(Math.min(detected.length - 1, details.session.arrows_per_end - 1));
    }
    showToast('AI detected scores applied to current end!', 'success');
  };

  const handleSaveEditedEnd = (endNumber: number, editedArrows: ArrowScore[]) => {
    if (!details) return;
    try {
      const updatedDetails = StorageService.updateEnd(details.session.id, endNumber, editedArrows);
      setDetails(updatedDetails);
      showToast(`End #${endNumber} updated successfully!`, 'success');
    } catch {
      showToast('Failed to update end scores.', 'error');
    }
  };

  const handleConfirmWatchShot = (score: string) => {
    handleInputScore(score, 'watch');
    showToast(`⌚ Shot confirmed: ${score} points!`, 'success');
    setDetectedShotEvent(null);
  };

  const handleDiscardWatchShot = () => {
    setDetectedShotEvent(null);
  };

  if (!details) return null;

  const { session, athlete, ends, summary } = details;
  const athleteName = athlete ? athlete.name : session.athlete_name || 'Athlete';
  const initials = athleteName
    .split(' ')
    .map(p => p[0])
    .join('')
    .substring(0, 2)
    .toUpperCase();

  let currentEndScore = 0;
  let currentEndX = 0;
  let filledCount = 0;
  currentArrows.forEach(a => {
    if (a.score !== null) {
      filledCount++;
      const { points, isX } = parseArrowPoints(a.score, a.is_x);
      currentEndScore += points;
      if (isX) currentEndX++;
    }
  });

  const allFilled = filledCount === currentArrows.length && currentArrows.length > 0;
  const totalSessionScoreLive = (summary?.total_score || 0) + currentEndScore;
  const totalArrowsSession = (summary?.total_arrows || 0) + filledCount;
  const runningAvg =
    totalArrowsSession > 0 ? (totalSessionScoreLive / totalArrowsSession).toFixed(2) : '0.0';

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

  return (
    <section className="view-section">
      {/* Session Info Bar */}
      <div className="session-info-bar card">
        <div className="session-info-left">
          <div className="athlete-display">
            <span className="athlete-avatar">{initials}</span>
            <div>
              <div className="athlete-title-wrap">
                <span className="athlete-name-text">{athleteName}</span>
                <span className="session-badge badge-recurve">{session.bow_category}</span>
              </div>
              <div className="session-meta-text">
                {session.distance} • {session.arrows_per_end} Arr/End •{' '}
                {session.session_type.toUpperCase()}
              </div>
            </div>
          </div>
        </div>

        <div className="session-info-actions">
          <button
            type="button"
            className="btn btn-sm btn-secondary"
            onClick={() => {
              const wState = watchService.getState();
              if (!wState.isConnected) {
                showToast('⌚ Apple Watch is offline. Reconnect in Watch panel.', 'warning');
                onOpenWatchModal();
                return;
              }
              watchService.triggerShotEvent();
            }}
            title="Simulate Apple Watch Bow Release Shot"
            style={{ color: 'var(--ring-gold)', borderColor: 'rgba(245, 158, 11, 0.4)' }}
          >
            <span>🏹 Watch Shot</span>
          </button>

          <button
            type="button"
            className="btn btn-sm btn-secondary"
            onClick={onOpenWatchModal}
            title="Open Apple Watch Companion"
            style={{ color: '#10b981', borderColor: 'rgba(16, 185, 129, 0.4)' }}
          >
            <span>⌚ iWatch</span>
          </button>

          <button
            type="button"
            className="btn btn-sm btn-secondary"
            onClick={() => setShowTarget(!showTarget)}
            title="Toggle Target Face View"
          >
            <span>🎯</span>
            <span>{showTarget ? 'Hide Target' : 'Show Target'}</span>
          </button>

          <button
            type="button"
            className="btn btn-sm btn-outline-danger"
            onClick={() => setIsExitConfirmOpen(true)}
            title="Exit session"
          >
            Exit
          </button>
        </div>
      </div>

      {/* Live Metrics Dashboard */}
      <div className="scoring-dashboard">
        <div className="metric-card gold-glow">
          <div className="metric-label">Current End</div>
          <div className="metric-value gold">
            End {session.current_end} / {session.total_ends}
          </div>
        </div>
        <div className="metric-card">
          <div className="metric-label">End Total</div>
          <div className="metric-value">{currentEndScore}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">End X</div>
          <div className="metric-value gold">{currentEndX}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Session Total</div>
          <div className="metric-value">{totalSessionScoreLive}</div>
        </div>
        <div className="metric-card live-stat-card">
          <div className="metric-label">Running Avg</div>
          <div className="metric-value">{runningAvg}</div>
        </div>
      </div>

      {/* Scoring Workspace */}
      <div
        className="scoring-workspace"
        style={{ gridTemplateColumns: showTarget ? undefined : '1fr' }}
      >
        {/* Interactive Olympic Target Face */}
        {showTarget && (
          <TargetFace
            onScoreSelect={val => handleInputScore(val, 'target_face')}
            activeRingHighlight={activeHighlightRing}
          />
        )}

        {/* Input Panel */}
        <div className="scoring-input-panel">
          {/* Arrow Slots */}
          <div className="arrows-slots-container card">
            <div className="slots-header">
              <span className="slots-header-title">Arrow Entries</span>
              <span className="slots-header-hint">Tap slot to edit • Keys 1-10, X, M</span>
            </div>

            <div className="arrow-slots-list">
              {currentArrows.map((arr, idx) => {
                const isActive = idx === activeSlotIndex;
                const isFilled = arr.score !== null;
                const colorClass = getScoreColorClass(arr.score, arr.is_x);

                return (
                  <div
                    key={idx}
                    className={`arrow-slot ${isFilled ? 'filled' : ''} ${colorClass} ${
                      isActive ? 'active' : ''
                    }`}
                    onClick={() => {
                      triggerHaptic();
                      setActiveSlotIndex(idx);
                    }}
                  >
                    {isFilled ? (arr.is_x ? 'X' : arr.score) : idx + 1}
                    {arr.source === 'watch' && (
                      <span
                        style={{
                          position: 'absolute',
                          bottom: '-4px',
                          right: '-4px',
                          fontSize: '0.65rem',
                          background: '#10b981',
                          borderRadius: '50%',
                          width: '16px',
                          height: '16px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                        }}
                        title="Recorded via Apple Watch"
                      >
                        ⌚
                      </span>
                    )}
                    {arr.source === 'ai' && (
                      <span
                        style={{
                          position: 'absolute',
                          bottom: '-4px',
                          right: '-4px',
                          fontSize: '0.65rem',
                          background: '#8b5cf6',
                          borderRadius: '50%',
                          width: '16px',
                          height: '16px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                        }}
                        title="Detected via AI Target Scan"
                      >
                        📸
                      </span>
                    )}
                  </div>
                );
              })}
            </div>

            {allFilled && (
              <div className="end-complete-banner">
                ✓ All arrows entered! Press <strong>Save End ➔</strong> or hit <strong>Enter</strong>
              </div>
            )}
          </div>

          {/* Tactile Keypad */}
          <Keypad
            onKeyPress={val => handleInputScore(val, 'manual')}
            onUndo={handleUndo}
            onTriggerAiScan={() => setIsAiScanOpen(true)}
            onSubmitEnd={handleSubmitEnd}
          />
        </div>
      </div>

      {/* Live Session Scorecard */}
      <div className="card scorecard-card">
        <div className="scorecard-header">
          <h3>Scorecard (Live Round)</h3>
          <span className="scorecard-sub">Tap "Edit" to adjust any arrow</span>
        </div>
        <div className="table-responsive">
          <table className="score-table">
            <thead>
              <tr>
                <th>End</th>
                <th>Arrows</th>
                <th>Score</th>
                <th>X</th>
                <th>Running Total</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {ends.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-muted">
                    No completed ends yet.
                  </td>
                </tr>
              ) : (
                (() => {
                  let running = 0;
                  return ends.map(end => {
                    running += end.total_score;
                    return (
                      <tr key={end.end_number}>
                        <td style={{ fontWeight: 700 }}>#{end.end_number}</td>
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
                        <td style={{ fontWeight: 800 }}>{running}</td>
                        <td>
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
                  });
                })()
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Apple Watch Shot Rematch Dialog */}
      <ShotRematchDialog
        isOpen={Boolean(detectedShotEvent)}
        shotEvent={detectedShotEvent}
        currentArrowNumber={activeSlotIndex + 1}
        onConfirmScore={handleConfirmWatchShot}
        onDiscard={handleDiscardWatchShot}
      />

      {/* Edit End Modal */}
      <EditEndModal
        isOpen={Boolean(editingEnd)}
        end={editingEnd}
        onClose={() => setEditingEnd(null)}
        onSave={handleSaveEditedEnd}
      />

      {/* AI Scan Modal */}
      <AiScanModal
        isOpen={isAiScanOpen}
        onClose={() => setIsAiScanOpen(false)}
        arrowCount={session.arrows_per_end}
        onApplyScores={handleApplyAiScores}
      />

      {/* Confirm Exit Modal */}
      <ConfirmModal
        isOpen={isExitConfirmOpen}
        title="Exit Session"
        message="Leave this scoring round? Your progress and completed ends are saved automatically."
        okText="Exit to Home"
        cancelText="Stay"
        onConfirm={onExitSession}
        onCancel={() => setIsExitConfirmOpen(false)}
      />

      {/* Confirm Incomplete Arrows Warning */}
      <ConfirmModal
        isOpen={isIncompleteConfirmOpen}
        title="Unfilled Arrows Warning"
        message={`You have unfilled arrow(s) in this end. Unfilled arrows will be recorded as Miss (M, 0 pts). Do you want to proceed?`}
        okText="Submit as Misses"
        cancelText="Keep Scoring"
        onConfirm={() => {
          setIsIncompleteConfirmOpen(false);
          const completedWithMisses = currentArrows.map(a => ({
            ...a,
            score: a.score === null ? ('M' as ScoreValue) : a.score,
            is_x: a.score === null ? false : a.is_x,
          }));
          setCurrentArrows(completedWithMisses);
          executeSaveEnd(completedWithMisses);
        }}
        onCancel={() => setIsIncompleteConfirmOpen(false)}
      />
    </section>
  );
};
