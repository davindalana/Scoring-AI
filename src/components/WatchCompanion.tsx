import React, { useState, useEffect } from 'react';
import { WatchState, ShotEvent, SessionDetails } from '../types';
import { watchService } from '../services/watchService';
import { useToast } from './Toast';

interface WatchCompanionProps {
  currentSessionDetails: SessionDetails | null;
  onWatchScoreInput?: (score: string) => void;
  onOpenShotDialog?: (event: ShotEvent) => void;
  isOpen: boolean;
  onClose: () => void;
}

export const WatchCompanion: React.FC<WatchCompanionProps> = ({
  currentSessionDetails,
  onWatchScoreInput,
  onOpenShotDialog,
  isOpen,
  onClose,
}) => {
  const [watchState, setWatchState] = useState<WatchState>(watchService.getState());
  const [currentTime, setCurrentTime] = useState<string>(() =>
    new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })
  );
  const { showToast } = useToast();

  useEffect(() => {
    const unsub = watchService.subscribeState(setWatchState);
    const timeInterval = setInterval(() => {
      const now = new Date();
      setCurrentTime(
        now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })
      );
    }, 1000);

    return () => {
      unsub();
      clearInterval(timeInterval);
    };
  }, []);

  if (!isOpen) return null;

  const live = watchState.liveScoring;
  const currentEnd = live ? live.currentEnd : currentSessionDetails?.session.current_end || 1;
  const totalEnds = live ? live.totalEnds : currentSessionDetails?.session.total_ends || 10;
  const sessionTotal = live ? live.sessionTotal : currentSessionDetails?.summary.total_score || 0;
  const endScore = live ? live.endScore : 0;
  const athleteName = live
    ? live.athleteName
    : currentSessionDetails?.athlete?.name || currentSessionDetails?.session.athlete_name || 'Ready to Shoot';

  const handleSimulateRelease = () => {
    if (!watchState.isConnected) {
      showToast('⌚ Apple Watch is disconnected. Tap "Connect Watch" first.', 'warning');
      return;
    }
    const event = watchService.triggerShotEvent();
    showToast(`⌚ Shot detected! ${event.suggestedScore} (${event.peakG}G recoil)`, 'info');
    if (onOpenShotDialog) {
      onOpenShotDialog(event);
    }
    onClose();
  };

  const handleScoreTap = (val: string) => {
    if (!watchState.isConnected) {
      showToast('⌚ Apple Watch is disconnected. Tap "Connect Watch" first.', 'warning');
      return;
    }
    const handledByLiveView = watchService.sendWristScore(val);
    if (!handledByLiveView && onWatchScoreInput) {
      onWatchScoreInput(val);
    }
    showToast(`⌚ Score ${val} synced from Apple Watch!`, 'success');
  };

  const getWatchButtonBg = (val: string) => {
    if (val === 'X' || val === '10') return '#f59e0b';
    if (val === '9') return '#fbbf24';
    if (val === '8' || val === '7') return '#ef4444';
    if (val === '6' || val === '5') return '#0284c7';
    if (val === '4' || val === '3') return '#1e293b';
    if (val === '2' || val === '1') return '#e2e8f0';
    return '#334155';
  };

  const getWatchButtonColor = (val: string) => {
    if (val === 'X' || val === '10' || val === '9' || val === '2' || val === '1') {
      return '#090d16';
    }
    return '#ffffff';
  };

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" onClick={onClose}>
      <div
        className="modal-content modal-lg"
        onClick={e => e.stopPropagation()}
        style={{ maxWidth: '720px' }}
      >
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
            <span style={{ fontSize: '1.6rem' }}>⌚</span>
            <div>
              <h3 className="modal-title">Apple Watch (iWatch) Companion & Sync</h3>
              <span className="text-secondary text-sm">
                Real-time WatchConnectivity • Archery release recoil sensor
              </span>
            </div>
          </div>
          <button className="close-btn" onClick={onClose} title="Close modal">
            &times;
          </button>
        </div>

        <div className="watch-companion-grid">
          {/* Apple Watch Device Frame Simulation */}
          <div className="watch-frame-wrapper">
            <div className="watch-bezel">
              {/* Digital Crown indicator */}
              <div className="watch-digital-crown" />
              <div className="watch-side-button" />

              {/* Watch Status Bar */}
              <div className="watch-status-bar">
                <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span
                    style={{
                      width: '7px',
                      height: '7px',
                      borderRadius: '50%',
                      background: watchState.isConnected ? '#10b981' : '#f87171',
                      display: 'inline-block',
                    }}
                  />
                  <span style={{ fontWeight: 700, fontSize: '0.68rem' }}>
                    {watchState.isConnected ? 'SYNCED' : 'OFFLINE'}
                  </span>
                </div>
                <div style={{ fontWeight: 800, color: '#f8fafc', fontSize: '0.8rem' }}>
                  {currentTime}
                </div>
                <div style={{ fontSize: '0.7rem' }}>{watchState.batteryLevel}% 🔋</div>
              </div>

              {/* Watch OLED Screen Content */}
              <div className="watch-oled-screen">
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ color: '#f59e0b', fontSize: '0.72rem', fontWeight: 700, textTransform: 'uppercase' }}>
                      End {currentEnd}/{totalEnds}
                    </span>
                    <span style={{ color: '#f87171', fontSize: '0.72rem', fontWeight: 700 }}>
                      ❤️ {watchState.heartRate} bpm
                    </span>
                  </div>

                  <div style={{ fontSize: '0.68rem', color: '#94a3b8', marginTop: '2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {athleteName}
                  </div>

                  <div
                    style={{
                      display: 'grid',
                      gridTemplateColumns: '1fr 1fr',
                      gap: '6px',
                      margin: '0.45rem 0',
                      background: 'rgba(255,255,255,0.04)',
                      borderRadius: '10px',
                      padding: '6px',
                    }}
                  >
                    <div style={{ textAlign: 'center' }}>
                      <div style={{ fontSize: '0.6rem', color: '#94a3b8', textTransform: 'uppercase' }}>End Pts</div>
                      <div style={{ fontSize: '1.35rem', fontWeight: 900, color: '#f8fafc', lineHeight: 1.1 }}>
                        {endScore}
                      </div>
                    </div>
                    <div style={{ textAlign: 'center', borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
                      <div style={{ fontSize: '0.6rem', color: '#94a3b8', textTransform: 'uppercase' }}>Total</div>
                      <div style={{ fontSize: '1.35rem', fontWeight: 900, color: '#f59e0b', lineHeight: 1.1 }}>
                        {sessionTotal}
                      </div>
                    </div>
                  </div>

                  {/* Mini Arrow Slots on Watch */}
                  {live && live.currentArrows.length > 0 && (
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'center',
                        gap: '4px',
                        marginBottom: '6px',
                      }}
                    >
                      {live.currentArrows.map((arr, idx) => {
                        const isCurrent = idx === live.activeSlotIndex;
                        const filled = arr.score !== null;
                        return (
                          <span
                            key={idx}
                            style={{
                              width: '24px',
                              height: '24px',
                              borderRadius: '50%',
                              fontSize: '0.7rem',
                              fontWeight: 800,
                              display: 'inline-flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              background: filled ? '#f59e0b' : '#111625',
                              color: filled ? '#090d16' : '#64748b',
                              border: isCurrent ? '1.5px solid #fbbf24' : '1px solid #334155',
                            }}
                          >
                            {filled ? (arr.is_x ? 'X' : arr.score) : idx + 1}
                          </span>
                        );
                      })}
                    </div>
                  )}
                </div>

                {/* Wrist scoring buttons (Full 12-button World Archery grid) */}
                <div>
                  <div style={{ fontSize: '0.62rem', color: '#64748b', marginBottom: '4px', textAlign: 'center' }}>
                    Tap Wrist Keypad to Score Arrow
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '4px' }}>
                    {['X', '10', '9', 'M', '8', '7', '6', '5', '4', '3', '2', '1'].map(val => (
                      <button
                        key={val}
                        type="button"
                        style={{
                          background: getWatchButtonBg(val),
                          color: getWatchButtonColor(val),
                          border: val === '4' || val === '3' ? '1px solid #475569' : 'none',
                          borderRadius: '6px',
                          padding: '5px 0',
                          fontSize: '0.8rem',
                          fontWeight: 800,
                          cursor: 'pointer',
                        }}
                        onClick={() => handleScoreTap(val)}
                      >
                        {val}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Controls & Shot Detection Telemetry */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div
              style={{
                background: 'var(--bg-card)',
                border: '1px solid var(--border-glass)',
                borderRadius: 'var(--radius-md)',
                padding: '1.1rem',
              }}
            >
              <h4 style={{ fontSize: '1rem', marginBottom: '0.4rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <span>🏹</span> Shot Recoil Simulator (CoreMotion)
              </h4>
              <p className="text-secondary text-sm" style={{ marginBottom: '0.9rem' }}>
                Simulates Apple Watch accelerometer & gyroscope recoil spike upon bowstring release and opens the Shot Rematch verification dialog.
              </p>

              <button
                type="button"
                className="btn btn-primary w-100"
                style={{ padding: '0.8rem 1rem', fontSize: '0.95rem' }}
                onClick={handleSimulateRelease}
              >
                <span>🏹 Simulate Bowstring Release (Shot)</span>
              </button>
            </div>

            {/* Sensitivity & Connection Toggle */}
            <div
              style={{
                background: 'var(--bg-card)',
                border: '1px solid var(--border-glass)',
                borderRadius: 'var(--radius-md)',
                padding: '1.1rem',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.65rem' }}>
                <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>Recoil Trigger Sensitivity:</span>
                <span style={{ fontWeight: 800, color: 'var(--ring-gold)' }}>{watchState.sensitivityG} G</span>
              </div>
              <input
                type="range"
                min="1.8"
                max="4.5"
                step="0.1"
                value={watchState.sensitivityG}
                onChange={e => watchService.setSensitivity(Number(e.target.value))}
                style={{ width: '100%', accentColor: 'var(--ring-gold)', cursor: 'pointer' }}
              />
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.72rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                <span>Sensitive (1.8G)</span>
                <span>Heavy Recoil (4.5G)</span>
              </div>

              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '1rem', flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className={`btn btn-sm ${watchState.isConnected ? 'btn-secondary' : 'btn-primary'} flex-1`}
                  onClick={() => {
                    const next = !watchState.isConnected;
                    watchService.setConnected(next);
                    showToast(next ? 'Watch connected!' : 'Watch disconnected.', next ? 'success' : 'warning');
                  }}
                >
                  {watchState.isConnected ? 'Disconnect Watch' : 'Connect Watch'}
                </button>
                <button
                  type="button"
                  className={`btn btn-sm ${watchState.isDetecting ? 'btn-secondary' : 'btn-primary'} flex-1`}
                  onClick={() => {
                    const next = !watchState.isDetecting;
                    watchService.setDetecting(next);
                    showToast(next ? 'Motion detection armed!' : 'Motion detection paused.', 'info');
                  }}
                >
                  {watchState.isDetecting ? 'Pause Sensor' : 'Arm Sensor'}
                </button>
              </div>
            </div>

            {/* Recent Shot Logs */}
            <div
              style={{
                background: 'var(--bg-card)',
                border: '1px solid var(--border-glass)',
                borderRadius: 'var(--radius-md)',
                padding: '1rem',
                maxHeight: '150px',
                overflowY: 'auto',
              }}
            >
              <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: '0.5rem', color: 'var(--text-secondary)' }}>
                Recent Watch Shot Events ({watchState.shotHistory.length})
              </div>
              {watchState.shotHistory.length === 0 ? (
                <div className="text-muted text-sm text-center p-2">
                  No shots detected yet. Tap "Simulate Bowstring Release" above to test.
                </div>
              ) : (
                watchState.shotHistory.slice(0, 6).map(sh => (
                  <div
                    key={sh.id}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      fontSize: '0.8rem',
                      padding: '4px 0',
                      borderBottom: '1px solid var(--border-glass)',
                    }}
                  >
                    <span>
                      {sh.timestamp} • {sh.peakG}G • Hold {sh.holdDurationSec}s
                    </span>
                    <span style={{ fontWeight: 800, color: 'var(--ring-gold)' }}>
                      Score: {sh.suggestedScore}
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
