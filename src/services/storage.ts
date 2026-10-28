import { Athlete, Session, ScoringEnd, ArrowScore, SessionSummary, SessionDetails, EndSummaryItem } from '../types';

const STORAGE_KEY_ATHLETES = 'archery_pro_athletes';
const STORAGE_KEY_SESSIONS = 'archery_pro_sessions';
const STORAGE_KEY_ENDS = 'archery_pro_ends';

// Pre-seeded Olympic archers and sample session
const INITIAL_ATHLETES: Athlete[] = [
  { id: 1, name: 'Arjuna Pratama', athlete_code: 'INA-001', created_at: new Date(Date.now() - 86400000 * 7).toISOString() },
  { id: 2, name: 'Diananda Choirunisa', athlete_code: 'INA-002', created_at: new Date(Date.now() - 86400000 * 5).toISOString() },
  { id: 3, name: 'Riau Ega Agatha', athlete_code: 'INA-003', created_at: new Date(Date.now() - 86400000 * 3).toISOString() },
];

function seedInitialData() {
  if (!localStorage.getItem(STORAGE_KEY_ATHLETES)) {
    localStorage.setItem(STORAGE_KEY_ATHLETES, JSON.stringify(INITIAL_ATHLETES));
  }

  if (!localStorage.getItem(STORAGE_KEY_SESSIONS)) {
    const sampleSessionId = 101;
    const initialSession: Session = {
      id: sampleSessionId,
      athlete_id: 1,
      athlete_name: 'Arjuna Pratama',
      bow_category: 'Recurve',
      session_type: 'training',
      distance: '70m',
      arrows_per_end: 6,
      total_ends: 5,
      current_end: 5,
      status: 'completed',
      started_at: new Date(Date.now() - 7200000).toISOString(),
      completed_at: new Date(Date.now() - 3600000).toISOString(),
    };

    const initialEnds: ScoringEnd[] = [
      {
        id: 1,
        session_id: sampleSessionId,
        end_number: 1,
        arrows: [
          { arrow_number: 1, score: 'X', is_x: true, source: 'manual' },
          { arrow_number: 2, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 3, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 4, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 5, score: '8', is_x: false, source: 'manual' },
          { arrow_number: 6, score: '8', is_x: false, source: 'manual' },
        ],
        total_score: 54,
        x_count: 1,
      },
      {
        id: 2,
        session_id: sampleSessionId,
        end_number: 2,
        arrows: [
          { arrow_number: 1, score: 'X', is_x: true, source: 'manual' },
          { arrow_number: 2, score: 'X', is_x: true, source: 'manual' },
          { arrow_number: 3, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 4, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 5, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 6, score: '9', is_x: false, source: 'manual' },
        ],
        total_score: 57,
        x_count: 2,
      },
      {
        id: 3,
        session_id: sampleSessionId,
        end_number: 3,
        arrows: [
          { arrow_number: 1, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 2, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 3, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 4, score: '8', is_x: false, source: 'manual' },
          { arrow_number: 5, score: '8', is_x: false, source: 'manual' },
          { arrow_number: 6, score: '7', is_x: false, source: 'manual' },
        ],
        total_score: 52,
        x_count: 0,
      },
      {
        id: 4,
        session_id: sampleSessionId,
        end_number: 4,
        arrows: [
          { arrow_number: 1, score: 'X', is_x: true, source: 'manual' },
          { arrow_number: 2, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 3, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 4, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 5, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 6, score: '8', is_x: false, source: 'manual' },
        ],
        total_score: 56,
        x_count: 1,
      },
      {
        id: 5,
        session_id: sampleSessionId,
        end_number: 5,
        arrows: [
          { arrow_number: 1, score: 'X', is_x: true, source: 'manual' },
          { arrow_number: 2, score: 'X', is_x: true, source: 'manual' },
          { arrow_number: 3, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 4, score: '10', is_x: false, source: 'manual' },
          { arrow_number: 5, score: '9', is_x: false, source: 'manual' },
          { arrow_number: 6, score: '9', is_x: false, source: 'manual' },
        ],
        total_score: 58,
        x_count: 2,
      },
    ];

    localStorage.setItem(STORAGE_KEY_SESSIONS, JSON.stringify([initialSession]));
    localStorage.setItem(STORAGE_KEY_ENDS, JSON.stringify(initialEnds));
  }
}

// Ensure seed data is initialized
if (typeof window !== 'undefined') {
  seedInitialData();
}

export function parseArrowPoints(scoreVal: string | null | undefined, isX = false): { points: number; isX: boolean } {
  if (!scoreVal) return { points: 0, isX: false };
  const s = String(scoreVal).trim().toUpperCase();
  if (s === 'X' || s === '10X') {
    return { points: 10, isX: true };
  }
  if (s === 'M') {
    return { points: 0, isX: false };
  }
  const num = parseInt(s, 10);
  if (!isNaN(num) && num >= 0 && num <= 10) {
    return { points: num, isX: isX && num === 10 };
  }
  return { points: 0, isX: false };
}

export function calculateEndStats(arrows: ArrowScore[]): { totalScore: number; xCount: number; arrowCount: number } {
  let totalScore = 0;
  let xCount = 0;
  let arrowCount = 0;

  arrows.forEach(arr => {
    if (arr.score !== null) {
      arrowCount++;
      const { points, isX } = parseArrowPoints(arr.score, arr.is_x);
      totalScore += points;
      if (isX) xCount++;
    }
  });

  return { totalScore, xCount, arrowCount };
}

export function calculateSummary(sessionId: number, ends: ScoringEnd[]): SessionSummary {
  let totalScore = 0;
  let totalX = 0;
  let totalArrows = 0;
  let highestEnd: { end_number: number; score: number } | null = null;
  let lowestEnd: { end_number: number; score: number } | null = null;
  const endsSummary: EndSummaryItem[] = [];

  const sortedEnds = [...ends].sort((a, b) => a.end_number - b.end_number);

  for (const end of sortedEnds) {
    const endNum = end.end_number;
    const endScore = end.total_score;
    const endX = end.x_count;
    const arrowCount = end.arrows.filter(a => a.score !== null).length;

    totalScore += endScore;
    totalX += endX;
    totalArrows += arrowCount;

    if (highestEnd === null || endScore > highestEnd.score) {
      highestEnd = { end_number: endNum, score: endScore };
    }
    if (lowestEnd === null || endScore < lowestEnd.score) {
      lowestEnd = { end_number: endNum, score: endScore };
    }

    endsSummary.push({
      end_number: endNum,
      total_score: endScore,
      x_count: endX,
      arrow_count: arrowCount,
      cumulative_score: totalScore,
    });
  }

  const averageScorePerArrow = totalArrows > 0 ? Number((totalScore / totalArrows).toFixed(2)) : 0;
  const averageScorePerEnd = ends.length > 0 ? Number((totalScore / ends.length).toFixed(1)) : 0;

  return {
    session_id: sessionId,
    total_score: totalScore,
    total_x: totalX,
    total_arrows: totalArrows,
    average_score_per_arrow: averageScorePerArrow,
    average_score_per_end: averageScorePerEnd,
    highest_scoring_end: highestEnd,
    lowest_scoring_end: lowestEnd,
    ends_summary: endsSummary,
  };
}

export const StorageService = {
  getAthletes(): Athlete[] {
    try {
      const data = localStorage.getItem(STORAGE_KEY_ATHLETES);
      return data ? JSON.parse(data) : [];
    } catch {
      return INITIAL_ATHLETES;
    }
  },

  saveAthlete(athlete: { name: string; athlete_code?: string | null }): Athlete {
    const athletes = this.getAthletes();
    const newAthlete: Athlete = {
      id: Date.now(),
      name: athlete.name.trim(),
      athlete_code: athlete.athlete_code?.trim() || null,
      created_at: new Date().toISOString(),
    };
    athletes.push(newAthlete);
    localStorage.setItem(STORAGE_KEY_ATHLETES, JSON.stringify(athletes));
    return newAthlete;
  },

  getSessions(): Session[] {
    try {
      const data = localStorage.getItem(STORAGE_KEY_SESSIONS);
      const list: Session[] = data ? JSON.parse(data) : [];
      return list.sort((a, b) => new Date(b.started_at).getTime() - new Date(a.started_at).getTime());
    } catch {
      return [];
    }
  },

  createSession(params: {
    athlete_id: number;
    bow_category: Session['bow_category'];
    session_type: Session['session_type'];
    distance: string;
    arrows_per_end: number;
    total_ends: number;
  }): Session {
    const athletes = this.getAthletes();
    const athlete = athletes.find(a => a.id === params.athlete_id);

    const newSession: Session = {
      id: Date.now(),
      athlete_id: params.athlete_id,
      athlete_name: athlete ? athlete.name : 'Unknown Athlete',
      bow_category: params.bow_category,
      session_type: params.session_type,
      distance: params.distance,
      arrows_per_end: params.arrows_per_end,
      total_ends: params.total_ends,
      current_end: 1,
      status: 'in_progress',
      started_at: new Date().toISOString(),
      completed_at: null,
    };

    const sessions = this.getSessions();
    sessions.unshift(newSession);
    localStorage.setItem(STORAGE_KEY_SESSIONS, JSON.stringify(sessions));
    return newSession;
  },

  getSessionDetails(sessionId: number): SessionDetails | null {
    const sessions = this.getSessions();
    const session = sessions.find(s => s.id === sessionId);
    if (!session) return null;

    const athletes = this.getAthletes();
    const athlete = athletes.find(a => a.id === session.athlete_id) || null;

    const allEndsRaw = localStorage.getItem(STORAGE_KEY_ENDS);
    const allEnds: ScoringEnd[] = allEndsRaw ? JSON.parse(allEndsRaw) : [];
    const sessionEnds = allEnds
      .filter(e => e.session_id === sessionId)
      .sort((a, b) => a.end_number - b.end_number);

    const summary = calculateSummary(sessionId, sessionEnds);

    return {
      session,
      athlete,
      ends: sessionEnds,
      summary,
    };
  },

  deleteSession(sessionId: number): void {
    const sessions = this.getSessions().filter(s => s.id !== sessionId);
    localStorage.setItem(STORAGE_KEY_SESSIONS, JSON.stringify(sessions));

    const allEndsRaw = localStorage.getItem(STORAGE_KEY_ENDS);
    if (allEndsRaw) {
      const allEnds: ScoringEnd[] = JSON.parse(allEndsRaw);
      const remainingEnds = allEnds.filter(e => e.session_id !== sessionId);
      localStorage.setItem(STORAGE_KEY_ENDS, JSON.stringify(remainingEnds));
    }
  },

  saveEnd(sessionId: number, endNumber: number, arrows: ArrowScore[]): { session: Session; end: ScoringEnd; summary: SessionSummary } {
    const { totalScore, xCount } = calculateEndStats(arrows);

    const allEndsRaw = localStorage.getItem(STORAGE_KEY_ENDS);
    const allEnds: ScoringEnd[] = allEndsRaw ? JSON.parse(allEndsRaw) : [];

    // Remove existing end if already saved
    const filteredEnds = allEnds.filter(e => !(e.session_id === sessionId && e.end_number === endNumber));

    const newEnd: ScoringEnd = {
      id: Date.now(),
      session_id: sessionId,
      end_number: endNumber,
      arrows: arrows.map((a, idx) => ({
        arrow_number: idx + 1,
        score: a.score,
        is_x: Boolean(a.is_x),
        source: a.source || 'manual',
      })),
      total_score: totalScore,
      x_count: xCount,
      created_at: new Date().toISOString(),
    };

    filteredEnds.push(newEnd);
    localStorage.setItem(STORAGE_KEY_ENDS, JSON.stringify(filteredEnds));

    // Update session current_end and status
    const sessions = this.getSessions();
    const sessionIndex = sessions.findIndex(s => s.id === sessionId);
    if (sessionIndex !== -1) {
      const sess = sessions[sessionIndex];
      if (endNumber >= sess.total_ends) {
        sess.status = 'completed';
        sess.completed_at = new Date().toISOString();
      } else {
        sess.current_end = endNumber + 1;
      }
      sessions[sessionIndex] = sess;
      localStorage.setItem(STORAGE_KEY_SESSIONS, JSON.stringify(sessions));
    }

    const sessionEnds = filteredEnds.filter(e => e.session_id === sessionId);
    const summary = calculateSummary(sessionId, sessionEnds);
    const updatedSession = sessions[sessionIndex];

    return {
      session: updatedSession,
      end: newEnd,
      summary,
    };
  },

  updateEnd(sessionId: number, endNumber: number, arrows: ArrowScore[]): SessionDetails {
    const { totalScore, xCount } = calculateEndStats(arrows);

    const allEndsRaw = localStorage.getItem(STORAGE_KEY_ENDS);
    const allEnds: ScoringEnd[] = allEndsRaw ? JSON.parse(allEndsRaw) : [];

    const endIdx = allEnds.findIndex(e => e.session_id === sessionId && e.end_number === endNumber);
    if (endIdx !== -1) {
      allEnds[endIdx].arrows = arrows.map((a, idx) => ({
        arrow_number: idx + 1,
        score: a.score,
        is_x: Boolean(a.is_x),
        source: a.source || 'manual',
      }));
      allEnds[endIdx].total_score = totalScore;
      allEnds[endIdx].x_count = xCount;
      localStorage.setItem(STORAGE_KEY_ENDS, JSON.stringify(allEnds));
    }

    return this.getSessionDetails(sessionId)!;
  },
};
