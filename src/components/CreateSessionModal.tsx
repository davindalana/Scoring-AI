import React, { useState, useEffect } from 'react';
import { BowCategory, SessionType } from '../types';
import { StorageService } from '../services/storage';
import { useToast } from './Toast';

interface CreateSessionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSessionCreated: (sessionId: number) => void;
  onOpenNewAthlete: () => void;
  initialSessionType?: SessionType;
  preselectedAthleteId?: number | null;
}

export const CreateSessionModal: React.FC<CreateSessionModalProps> = ({
  isOpen,
  onClose,
  onSessionCreated,
  onOpenNewAthlete,
  initialSessionType = 'training',
  preselectedAthleteId = null,
}) => {
  const [athleteId, setAthleteId] = useState<number | ''>(preselectedAthleteId || '');
  const [bowCategory, setBowCategory] = useState<BowCategory>('Recurve');
  const [sessionType, setSessionType] = useState<SessionType>(initialSessionType);
  const [distance, setDistance] = useState<string>('70m');
  const [customDistance, setCustomDistance] = useState<string>('');
  const [arrowsPerEnd, setArrowsPerEnd] = useState<number>(6);
  const [totalEnds, setTotalEnds] = useState<number>(10);
  const { showToast } = useToast();

  useEffect(() => {
    setSessionType(initialSessionType);
  }, [initialSessionType]);

  useEffect(() => {
    if (preselectedAthleteId) {
      setAthleteId(preselectedAthleteId);
    }
  }, [preselectedAthleteId]);

  if (!isOpen) return null;

  const athletes = StorageService.getAthletes();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!athleteId) {
      showToast('Please select an athlete.', 'warning');
      return;
    }

    const finalDistance = distance === 'Custom' ? customDistance.trim() : distance;
    if (distance === 'Custom' && !finalDistance) {
      showToast('Please enter a custom target distance.', 'warning');
      return;
    }

    try {
      const session = StorageService.createSession({
        athlete_id: Number(athleteId),
        bow_category: bowCategory,
        session_type: sessionType,
        distance: finalDistance || '70m',
        arrows_per_end: Number(arrowsPerEnd),
        total_ends: Number(totalEnds),
      });

      showToast('Scoring session started!', 'success');
      onSessionCreated(session.id);
      onClose();
    } catch {
      showToast('Failed to start session.', 'error');
    }
  };

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" onClick={onClose}>
      <div className="modal-content modal-md" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h3 className="modal-title">Create Scoring Session</h3>
          <button className="close-btn" onClick={onClose} title="Close modal">
            &times;
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label" htmlFor="selectAthlete">
              Athlete *
            </label>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <select
                id="selectAthlete"
                className="form-select"
                value={athleteId}
                onChange={e => setAthleteId(e.target.value ? Number(e.target.value) : '')}
                required
                style={{ flex: 1 }}
              >
                <option value="">Select an athlete...</option>
                {athletes.map(a => (
                  <option key={a.id} value={a.id}>
                    {a.name} {a.athlete_code ? `(${a.athlete_code})` : ''}
                  </option>
                ))}
              </select>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={onOpenNewAthlete}
                title="Add new athlete"
              >
                + Add
              </button>
            </div>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="selectBowCategory">
              Bow Category *
            </label>
            <select
              id="selectBowCategory"
              className="form-select"
              value={bowCategory}
              onChange={e => setBowCategory(e.target.value as BowCategory)}
              required
            >
              <option value="Recurve">Recurve (Olympic Standard)</option>
              <option value="Compound">Compound</option>
              <option value="Barebow">Barebow</option>
              <option value="Standard Bow / National">Standard Bow / National</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="selectSessionType">
              Session Type
            </label>
            <select
              id="selectSessionType"
              className="form-select"
              value={sessionType}
              onChange={e => setSessionType(e.target.value as SessionType)}
            >
              <option value="training">Training (Practice)</option>
              <option value="competition">Competition (Official Round)</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="selectDistance">
              Target Distance
            </label>
            <select
              id="selectDistance"
              className="form-select"
              value={distance}
              onChange={e => setDistance(e.target.value)}
            >
              <option value="70m">70 meters (Olympic Recurve)</option>
              <option value="50m">50 meters (Compound / Barebow)</option>
              <option value="30m">30 meters (Short distance)</option>
              <option value="18m">18 meters (Indoor WA Standard)</option>
              <option value="Custom">Custom Distance...</option>
            </select>
            {distance === 'Custom' && (
              <input
                type="text"
                className="form-input"
                placeholder="e.g. 40m"
                value={customDistance}
                onChange={e => setCustomDistance(e.target.value)}
                style={{ marginTop: '0.5rem' }}
                required
              />
            )}
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <div className="form-group">
              <label className="form-label" htmlFor="selectArrowsPerEnd">
                Arrows per End
              </label>
              <select
                id="selectArrowsPerEnd"
                className="form-select"
                value={arrowsPerEnd}
                onChange={e => setArrowsPerEnd(Number(e.target.value))}
              >
                <option value={6}>6 Arrows</option>
                <option value={3}>3 Arrows</option>
              </select>
            </div>
            <div className="form-group">
              <label className="form-label" htmlFor="inputTotalEnds">
                Number of Ends
              </label>
              <input
                id="inputTotalEnds"
                type="number"
                className="form-input"
                value={totalEnds}
                min={1}
                max={50}
                onChange={e => setTotalEnds(Number(e.target.value))}
                required
              />
            </div>
          </div>

          <div style={{ marginTop: '1.5rem' }}>
            <button type="submit" className="btn btn-primary w-100">
              Start Scoring Session ➔
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
