import React, { useState, useEffect } from 'react';
import { Athlete } from '../types';
import { StorageService } from '../services/storage';
import { useToast } from './Toast';

interface AthleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectAthleteToShoot?: (athleteId: number) => void;
  onAthleteCreated?: (athlete: Athlete) => void;
  initialTab?: 'list' | 'new';
}

export const AthleteModal: React.FC<AthleteModalProps> = ({
  isOpen,
  onClose,
  onSelectAthleteToShoot,
  onAthleteCreated,
  initialTab = 'list',
}) => {
  const [tab, setTab] = useState<'list' | 'new'>(initialTab);
  const [searchQuery, setSearchQuery] = useState('');
  const [name, setName] = useState('');
  const [athleteCode, setAthleteCode] = useState('');
  const { showToast } = useToast();

  useEffect(() => {
    if (isOpen) {
      setTab(initialTab);
      setSearchQuery('');
    }
  }, [isOpen, initialTab]);

  if (!isOpen) return null;

  const athletes = StorageService.getAthletes();
  const filteredAthletes = athletes.filter(a => {
    const q = searchQuery.toLowerCase().trim();
    return a.name.toLowerCase().includes(q) || (a.athlete_code || '').toLowerCase().includes(q);
  });

  const handleRegister = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    try {
      const created = StorageService.saveAthlete({
        name: name.trim(),
        athlete_code: athleteCode.trim() || null,
      });
      showToast(`Athlete "${created.name}" registered!`, 'success');
      setName('');
      setAthleteCode('');
      if (onAthleteCreated) {
        onAthleteCreated(created);
      } else {
        setTab('list');
      }
    } catch {
      showToast('Failed to save athlete.', 'error');
    }
  };

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" onClick={onClose}>
      <div className="modal-content modal-md" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <div className="tab-pills" style={{ margin: 0 }}>
            <button
              type="button"
              className={`tab-pill ${tab === 'list' ? 'active' : ''}`}
              onClick={() => setTab('list')}
            >
              Athletes Directory
            </button>
            <button
              type="button"
              className={`tab-pill ${tab === 'new' ? 'active' : ''}`}
              onClick={() => setTab('new')}
            >
              + Register New
            </button>
          </div>
          <button className="close-btn" onClick={onClose} title="Close modal">
            &times;
          </button>
        </div>

        {tab === 'list' ? (
          <div>
            <div className="search-box" style={{ marginBottom: '1rem' }}>
              <span className="search-icon">🔍</span>
              <input
                type="text"
                className="search-input"
                placeholder="Search athletes by name or code..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
              />
            </div>

            <div className="athletes-directory-list">
              {filteredAthletes.length === 0 ? (
                <div className="text-muted text-center p-3">
                  {searchQuery ? 'No matching athletes found.' : 'No athletes registered yet.'}
                </div>
              ) : (
                filteredAthletes.map(a => {
                  const initials = a.name
                    .split(' ')
                    .map(p => p[0])
                    .join('')
                    .substring(0, 2)
                    .toUpperCase();

                  return (
                    <div key={a.id} className="athlete-dir-card">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <span
                          className="athlete-avatar"
                          style={{ width: '36px', height: '36px', fontSize: '0.95rem' }}
                        >
                          {initials}
                        </span>
                        <div>
                          <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{a.name}</div>
                          <div style={{ color: 'var(--text-secondary)', fontSize: '0.8rem' }}>
                            {a.athlete_code ? `Code: ${a.athlete_code}` : 'No code'}
                          </div>
                        </div>
                      </div>
                      {onSelectAthleteToShoot && (
                        <div>
                          <button
                            type="button"
                            className="btn btn-sm btn-primary"
                            onClick={() => {
                              onSelectAthleteToShoot(a.id);
                              onClose();
                            }}
                          >
                            Shoot ➔
                          </button>
                        </div>
                      )}
                    </div>
                  );
                })
              )}
            </div>
          </div>
        ) : (
          <form onSubmit={handleRegister}>
            <div className="form-group">
              <label className="form-label" htmlFor="athlete-name">
                Athlete Full Name *
              </label>
              <input
                id="athlete-name"
                type="text"
                className="form-input"
                placeholder="e.g. Arjuna Pratama"
                value={name}
                onChange={e => setName(e.target.value)}
                required
                autoFocus
              />
            </div>
            <div className="form-group">
              <label className="form-label" htmlFor="athlete-code">
                Athlete Code / Registration # (Optional)
              </label>
              <input
                id="athlete-code"
                type="text"
                className="form-input"
                placeholder="e.g. INA-001"
                value={athleteCode}
                onChange={e => setAthleteCode(e.target.value)}
              />
            </div>
            <div style={{ marginTop: '1.5rem' }}>
              <button type="submit" className="btn btn-primary w-100">
                Save Athlete
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};
