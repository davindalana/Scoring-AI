import React, { useState, useEffect } from 'react';
import { watchService } from '../services/watchService';
import { WatchState } from '../types';

interface NavbarProps {
  onGoHome: () => void;
  onOpenAthletes: () => void;
  onNewSession: () => void;
  onOpenWatch: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  onGoHome,
  onOpenAthletes,
  onNewSession,
  onOpenWatch,
}) => {
  const [watchState, setWatchState] = useState<WatchState>(watchService.getState());

  useEffect(() => {
    return watchService.subscribeState(setWatchState);
  }, []);

  return (
    <header className="navbar">
      <div className="brand" onClick={onGoHome} role="button" tabIndex={0} title="Return to Home">
        <span className="target-icon"></span>
        <span className="brand-text">
          Archery Score <span className="gold-text">Pro</span>
        </span>
      </div>

      <div className="nav-actions no-print">
        {/* Apple Watch status pill */}
        <button
          type="button"
          className="btn btn-secondary watch-pill-btn"
          onClick={onOpenWatch}
          title="Apple Watch Companion & Recoil Sensor"
          style={{
            borderColor: watchState.isConnected ? 'rgba(16, 185, 129, 0.4)' : 'rgba(239, 68, 68, 0.4)',
            background: watchState.isConnected ? 'rgba(16, 185, 129, 0.08)' : 'rgba(239, 68, 68, 0.08)',
          }}
        >
          <span style={{ fontSize: '1rem' }}>⌚</span>
          <span className="watch-status-label" style={{ fontSize: '0.82rem', fontWeight: 700 }}>
            {watchState.isConnected ? 'Watch Paired' : 'Watch Offline'}
          </span>
          <span
            style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              background: watchState.isConnected ? '#10b981' : '#f87171',
              boxShadow: watchState.isConnected ? '0 0 6px #10b981' : 'none',
              display: 'inline-block',
            }}
          />
        </button>

        <button className="btn btn-secondary desktop-only" onClick={onOpenAthletes} title="Manage registered athletes">
          <span className="btn-icon">🎯</span>
          <span>Athletes</span>
        </button>

        <button className="btn btn-primary" onClick={onNewSession} title="Start a new scoring session">
          <span className="btn-icon">+</span>
          <span className="desktop-only">New Session</span>
        </button>
      </div>
    </header>
  );
};
