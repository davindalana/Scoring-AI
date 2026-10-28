import React, { useState } from 'react';
import { Navbar } from './components/Navbar';
import { AthleteModal } from './components/AthleteModal';
import { CreateSessionModal } from './components/CreateSessionModal';
import { WatchCompanion } from './components/WatchCompanion';
import { ToastProvider } from './components/Toast';
import { HomeView } from './views/HomeView';
import { ScoringView } from './views/ScoringView';
import { SummaryView } from './views/SummaryView';
import { SessionDetails, SessionType, ShotEvent, Athlete } from './types';
import { StorageService } from './services/storage';
import { watchService } from './services/watchService';

export const App: React.FC = () => {
  const [currentView, setCurrentView] = useState<'home' | 'scoring' | 'summary'>('home');
  const [activeSessionId, setActiveSessionId] = useState<number | null>(null);
  const [summaryDetails, setSummaryDetails] = useState<SessionDetails | null>(null);
  const [pendingWatchShot, setPendingWatchShot] = useState<ShotEvent | null>(null);

  // Modals state
  const [isAthleteModalOpen, setIsAthleteModalOpen] = useState(false);
  const [athleteModalTab, setAthleteModalTab] = useState<'list' | 'new'>('list');
  const [returnToSessionModal, setReturnToSessionModal] = useState(false);
  const [isCreateSessionOpen, setIsCreateSessionOpen] = useState(false);
  const [createSessionType, setCreateSessionType] = useState<SessionType>('training');
  const [preselectedAthleteId, setPreselectedAthleteId] = useState<number | null>(null);
  const [isWatchModalOpen, setIsWatchModalOpen] = useState(false);

  const handleGoHome = () => {
    setCurrentView('home');
    setActiveSessionId(null);
    setSummaryDetails(null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleStartSession = (type: SessionType) => {
    setCreateSessionType(type);
    setIsCreateSessionOpen(true);
  };

  const handleOpenSession = (sessionId: number) => {
    const details = StorageService.getSessionDetails(sessionId);
    if (!details) return;

    if (details.session.status === 'completed') {
      setSummaryDetails(details);
      setCurrentView('summary');
    } else {
      setActiveSessionId(sessionId);
      setCurrentView('scoring');
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleSessionCreated = (sessionId: number) => {
    setActiveSessionId(sessionId);
    setCurrentView('scoring');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleSessionCompleted = (details: SessionDetails) => {
    setSummaryDetails(details);
    setCurrentView('summary');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleOpenNewAthleteFromSession = () => {
    setIsCreateSessionOpen(false);
    setReturnToSessionModal(true);
    setAthleteModalTab('new');
    setIsAthleteModalOpen(true);
  };

  const handleAthleteCreated = (created: Athlete) => {
    if (returnToSessionModal) {
      setIsAthleteModalOpen(false);
      setReturnToSessionModal(false);
      setPreselectedAthleteId(created.id);
      setIsCreateSessionOpen(true);
    }
  };

  const handleSelectAthleteToShoot = (athleteId: number) => {
    setPreselectedAthleteId(athleteId);
    setCreateSessionType('training');
    setIsCreateSessionOpen(true);
  };

  const ensureActiveScoringSession = (): number => {
    if (currentView === 'scoring' && activeSessionId) {
      return activeSessionId;
    }
    const existingInProgress = StorageService.getSessions().find(s => s.status === 'in_progress');
    if (existingInProgress) {
      setActiveSessionId(existingInProgress.id);
      setCurrentView('scoring');
      return existingInProgress.id;
    }
    const athletes = StorageService.getAthletes();
    const defaultAthleteId = athletes[0]?.id || 1;
    const created = StorageService.createSession({
      athlete_id: defaultAthleteId,
      bow_category: 'Recurve',
      session_type: 'training',
      distance: '70m',
      arrows_per_end: 6,
      total_ends: 10,
    });
    setActiveSessionId(created.id);
    setCurrentView('scoring');
    return created.id;
  };

  const handleWatchShotFromModal = (event: ShotEvent) => {
    if (currentView !== 'scoring' || !activeSessionId) {
      ensureActiveScoringSession();
      setPendingWatchShot(event);
    }
  };

  const handleWatchWristScoreFromModal = (score: string) => {
    if (currentView !== 'scoring' || !activeSessionId) {
      ensureActiveScoringSession();
      setTimeout(() => {
        watchService.sendWristScore(score);
      }, 60);
    }
  };

  const activeSessionDetails = activeSessionId
    ? StorageService.getSessionDetails(activeSessionId)
    : summaryDetails;

  return (
    <ToastProvider>
      <Navbar
        onGoHome={handleGoHome}
        onOpenAthletes={() => {
          setReturnToSessionModal(false);
          setAthleteModalTab('list');
          setIsAthleteModalOpen(true);
        }}
        onNewSession={() => {
          setCreateSessionType('training');
          setIsCreateSessionOpen(true);
        }}
        onOpenWatch={() => setIsWatchModalOpen(true)}
      />

      <main className="container">
        {currentView === 'home' && (
          <HomeView
            onStartSession={handleStartSession}
            onOpenSession={handleOpenSession}
          />
        )}

        {currentView === 'scoring' && activeSessionId && (
          <ScoringView
            sessionId={activeSessionId}
            onExitSession={handleGoHome}
            onSessionCompleted={handleSessionCompleted}
            onOpenWatchModal={() => setIsWatchModalOpen(true)}
            initialPendingShot={pendingWatchShot}
            onClearPendingShot={() => setPendingWatchShot(null)}
          />
        )}

        {currentView === 'summary' && summaryDetails && (
          <SummaryView
            details={summaryDetails}
            onBackHome={handleGoHome}
            onNewSession={() => {
              setCreateSessionType('training');
              setIsCreateSessionOpen(true);
            }}
          />
        )}
      </main>

      {/* Mobile Sticky Bottom Navigation Bar */}
      <nav className="mobile-bottom-bar no-print">
        <button
          type="button"
          className={`mobile-tab-btn ${currentView === 'home' ? 'active' : ''}`}
          onClick={handleGoHome}
        >
          <span className="mobile-tab-icon">🏠</span>
          <span className="mobile-tab-label">Home</span>
        </button>

        <button
          type="button"
          className={`mobile-tab-btn ${currentView === 'scoring' ? 'active' : ''}`}
          onClick={() => {
            if (activeSessionId) {
              setCurrentView('scoring');
            } else {
              const inProg = StorageService.getSessions().find(s => s.status === 'in_progress');
              if (inProg) {
                handleOpenSession(inProg.id);
              } else {
                handleStartSession('training');
              }
            }
          }}
        >
          <span className="mobile-tab-icon">🎯</span>
          <span className="mobile-tab-label">Score</span>
        </button>

        <button
          type="button"
          className="mobile-tab-btn watch-tab"
          onClick={() => setIsWatchModalOpen(true)}
        >
          <span className="mobile-tab-icon">⌚</span>
          <span className="mobile-tab-label">iWatch</span>
        </button>

        <button
          type="button"
          className="mobile-tab-btn"
          onClick={() => {
            setReturnToSessionModal(false);
            setAthleteModalTab('list');
            setIsAthleteModalOpen(true);
          }}
        >
          <span className="mobile-tab-icon">👥</span>
          <span className="mobile-tab-label">Athletes</span>
        </button>
      </nav>

      {/* Global Modals */}
      <AthleteModal
        isOpen={isAthleteModalOpen}
        onClose={() => {
          setIsAthleteModalOpen(false);
          setReturnToSessionModal(false);
        }}
        initialTab={athleteModalTab}
        onSelectAthleteToShoot={handleSelectAthleteToShoot}
        onAthleteCreated={returnToSessionModal ? handleAthleteCreated : undefined}
      />

      <CreateSessionModal
        isOpen={isCreateSessionOpen}
        onClose={() => {
          setIsCreateSessionOpen(false);
          setPreselectedAthleteId(null);
        }}
        initialSessionType={createSessionType}
        preselectedAthleteId={preselectedAthleteId}
        onSessionCreated={handleSessionCreated}
        onOpenNewAthlete={handleOpenNewAthleteFromSession}
      />

      <WatchCompanion
        isOpen={isWatchModalOpen}
        onClose={() => setIsWatchModalOpen(false)}
        currentSessionDetails={activeSessionDetails}
        onOpenShotDialog={handleWatchShotFromModal}
        onWatchScoreInput={handleWatchWristScoreFromModal}
      />
    </ToastProvider>
  );
};
