import React, { useState } from 'react';
import { Session, SessionStatus } from '../types';
import { StorageService } from '../services/storage';
import { ConfirmModal } from '../components/ConfirmModal';
import { useToast } from '../components/Toast';

interface HomeViewProps {
  onStartSession: (type: 'training' | 'competition') => void;
  onOpenSession: (sessionId: number) => void;
  onRefreshTrigger?: number;
}

export const HomeView: React.FC<HomeViewProps> = ({
  onStartSession,
  onOpenSession,
}) => {
  const [filter, setFilter] = useState<'all' | SessionStatus>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [sessionToDelete, setSessionToDelete] = useState<Session | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const { showToast } = useToast();

  const sessions = StorageService.getSessions();

  const filteredSessions = sessions.filter(s => {
    if (filter !== 'all' && s.status !== filter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const ath = (s.athlete_name || '').toLowerCase();
      const bow = (s.bow_category || '').toLowerCase();
      return ath.includes(q) || bow.includes(q);
    }
    return true;
  });

  const handleDeleteSession = () => {
    if (!sessionToDelete) return;
    try {
      StorageService.deleteSession(sessionToDelete.id);
      showToast('Session deleted successfully.', 'success');
      setSessionToDelete(null);
      setRefreshKey(prev => prev + 1);
    } catch {
      showToast('Failed to delete session.', 'error');
    }
  };

  return (
    <section className="view-section" key={refreshKey}>
      <div className="hero-banner">
        <div className="hero-badge">World Archery Standards</div>
        <h1>Precision Scoring & Analytics</h1>
        <p>Tactile range entry, interactive 10-ring Olympic target visualizer, and instant session statistics.</p>
      </div>

      <div className="action-grid">
        <div
          className="action-card"
          onClick={() => onStartSession('training')}
          role="button"
          tabIndex={0}
        >
          <div className="action-card-header">
            <div>
              <h3>Training Session</h3>
              <p className="action-card-sub">Practice ends, grouping tests & consistency stats</p>
            </div>
            <div className="action-icon gold-icon">🎯</div>
          </div>
          <div className="card-action-btn">
            <button type="button" className="btn btn-primary w-100">Start Practice ➔</button>
          </div>
        </div>

        <div
          className="action-card comp"
          onClick={() => onStartSession('competition')}
          role="button"
          tabIndex={0}
        >
          <div className="action-card-header">
            <div>
              <h3>Competition Round</h3>
              <p className="action-card-sub">Official 72 / 36 arrow tournament round</p>
            </div>
            <div className="action-icon red-icon">🏆</div>
          </div>
          <div className="card-action-btn">
            <button type="button" className="btn btn-secondary comp-btn w-100">Start Round ➔</button>
          </div>
        </div>
      </div>

      {/* Recent Sessions */}
      <div className="sessions-header-row">
        <div className="section-title">
          <h2>Recent Sessions</h2>
          <span className="count-badge">{filteredSessions.length} sessions</span>
        </div>

        <div className="filter-controls">
          <div className="search-box">
            <span className="search-icon">🔍</span>
            <input
              type="text"
              className="search-input"
              placeholder="Search athlete or bow..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>
          <div className="tab-pills">
            <button
              className={`tab-pill ${filter === 'all' ? 'active' : ''}`}
              onClick={() => setFilter('all')}
            >
              All
            </button>
            <button
              className={`tab-pill ${filter === 'in_progress' ? 'active' : ''}`}
              onClick={() => setFilter('in_progress')}
            >
              In Progress
            </button>
            <button
              className={`tab-pill ${filter === 'completed' ? 'active' : ''}`}
              onClick={() => setFilter('completed')}
            >
              Completed
            </button>
          </div>
        </div>
      </div>

      <div className="sessions-list">
        {filteredSessions.length === 0 ? (
          <div
            style={{
              textAlign: 'center',
              color: 'var(--text-secondary)',
              padding: '2.5rem',
              background: 'var(--bg-card)',
              borderRadius: 'var(--radius-md)',
              border: '1px dashed var(--border-glass)',
            }}
          >
            {searchQuery
              ? 'No matching sessions found.'
              : 'No sessions recorded yet. Tap Start Practice or + New Session to begin.'}
          </div>
        ) : (
          filteredSessions.map(s => {
            const isComplete = s.status === 'completed';
            const athleteName = s.athlete_name || 'Athlete';
            const initials = athleteName
              .split(' ')
              .map(p => p[0])
              .join('')
              .substring(0, 2)
              .toUpperCase();

            const dateStr = s.started_at
              ? new Date(s.started_at).toLocaleDateString(undefined, {
                  month: 'short',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                })
              : '';

            return (
              <div
                key={s.id}
                className="session-item"
                onClick={() => onOpenSession(s.id)}
              >
                <div className="session-item-main">
                  <div className="session-avatar">{initials}</div>
                  <div>
                    <div className="session-title">{athleteName}</div>
                    <div className="session-sub">
                      {s.bow_category} • {s.distance} • {s.arrows_per_end} arr/end • {dateStr}
                    </div>
                  </div>
                </div>
                <div className="session-item-right">
                  <span className={`session-badge ${isComplete ? 'badge-completed' : 'badge-progress'}`}>
                    {isComplete ? 'Completed' : `End ${s.current_end}/${s.total_ends}`}
                  </span>
                  <button
                    type="button"
                    className="btn-icon-danger"
                    title="Delete Session"
                    onClick={e => {
                      e.stopPropagation();
                      setSessionToDelete(s);
                    }}
                  >
                    🗑️
                  </button>
                  <span style={{ fontSize: '1.1rem', color: 'var(--text-muted)', marginLeft: '0.25rem' }}>
                    ➔
                  </span>
                </div>
              </div>
            );
          })
        )}
      </div>

      <ConfirmModal
        isOpen={Boolean(sessionToDelete)}
        title="Delete Scoring Session"
        message={`Are you sure you want to permanently delete this ${sessionToDelete?.bow_category} session for ${sessionToDelete?.athlete_name}? All recorded ends will be removed.`}
        okText="Delete Session"
        cancelText="Keep Session"
        onConfirm={handleDeleteSession}
        onCancel={() => setSessionToDelete(null)}
      />
    </section>
  );
};
