export interface Athlete {
  id: number;
  name: string;
  athlete_code?: string | null;
  created_at?: string;
}

export type ScoreValue = 'X' | '10' | '9' | '8' | '7' | '6' | '5' | '4' | '3' | '2' | '1' | 'M' | null;

export interface ArrowScore {
  arrow_number: number;
  score: ScoreValue;
  is_x: boolean;
  source?: 'manual' | 'ai' | 'target_face' | 'watch';
  x?: number;
  y?: number;
}

export interface ScoringEnd {
  id?: number;
  session_id: number;
  end_number: number;
  arrows: ArrowScore[];
  total_score: number;
  x_count: number;
  created_at?: string;
}

export type BowCategory = 'Recurve' | 'Compound' | 'Barebow' | 'Standard Bow / National';
export type SessionType = 'training' | 'competition';
export type SessionStatus = 'in_progress' | 'completed';

export interface Session {
  id: number;
  athlete_id: number;
  athlete_name?: string;
  bow_category: BowCategory;
  session_type: SessionType;
  distance: string;
  arrows_per_end: number;
  total_ends: number;
  current_end: number;
  status: SessionStatus;
  started_at: string;
  completed_at?: string | null;
}

export interface EndSummaryItem {
  end_number: number;
  total_score: number;
  x_count: number;
  arrow_count: number;
  cumulative_score: number;
}

export interface EndHighlight {
  end_number: number;
  score: number;
}

export interface SessionSummary {
  session_id: number;
  total_score: number;
  total_x: number;
  total_arrows: number;
  average_score_per_arrow: number;
  average_score_per_end: number;
  highest_scoring_end?: EndHighlight | null;
  lowest_scoring_end?: EndHighlight | null;
  ends_summary: EndSummaryItem[];
}

export interface SessionDetails {
  session: Session;
  athlete?: Athlete | null;
  ends: ScoringEnd[];
  summary: SessionSummary;
}

export interface DetectedArrowPoint {
  arrow_number: number;
  score: string;
  is_x: boolean;
  confidence: number;
  x?: number;
  y?: number;
}

// ==================== APPLE WATCH / IWATCH INTEGRATION TYPES ====================
export interface ShotEvent {
  id: string;
  timestamp: string;
  peakG: number;
  holdDurationSec: number;
  stabilityScore: number;
  heartRateBpm: number;
  suggestedScore?: string;
  confirmed?: boolean;
}

export interface WatchLiveScoringSync {
  sessionId: number | null;
  athleteName: string;
  bowCategory: string;
  distance: string;
  currentEnd: number;
  totalEnds: number;
  endScore: number;
  sessionTotal: number;
  activeSlotIndex: number;
  arrowsPerEnd: number;
  currentArrows: ArrowScore[];
}

export interface WatchState {
  isConnected: boolean;
  batteryLevel: number;
  heartRate: number;
  isDetecting: boolean;
  sensitivityG: number;
  lastShotEvent: ShotEvent | null;
  shotHistory: ShotEvent[];
  liveScoring: WatchLiveScoringSync | null;
}
