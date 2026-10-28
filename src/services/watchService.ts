import { ShotEvent, WatchState, WatchLiveScoringSync } from '../types';

type ShotCallback = (event: ShotEvent) => void;
type WristScoreCallback = (score: string) => void;
type StateCallback = (state: WatchState) => void;

class WatchService {
  private state: WatchState = {
    isConnected: true,
    batteryLevel: 88,
    heartRate: 118,
    isDetecting: true,
    sensitivityG: 2.8,
    lastShotEvent: null,
    shotHistory: [],
    liveScoring: null,
  };

  private shotListeners: ShotCallback[] = [];
  private wristScoreListeners: WristScoreCallback[] = [];
  private stateListeners: StateCallback[] = [];
  private holdStartTime: number | null = null;
  private isAiming = false;
  private heartRateInterval: ReturnType<typeof setInterval> | null = null;

  constructor() {
    if (typeof window !== 'undefined') {
      this.startHeartRateSimulation();
      this.initMotionListener();
    }
  }

  public getState(): WatchState {
    return {
      ...this.state,
      shotHistory: [...this.state.shotHistory],
      liveScoring: this.state.liveScoring
        ? {
            ...this.state.liveScoring,
            currentArrows: [...this.state.liveScoring.currentArrows],
          }
        : null,
    };
  }

  public subscribeShots(callback: ShotCallback): () => void {
    this.shotListeners.push(callback);
    return () => {
      this.shotListeners = this.shotListeners.filter(cb => cb !== callback);
    };
  }

  public subscribeWristScores(callback: WristScoreCallback): () => void {
    this.wristScoreListeners.push(callback);
    return () => {
      this.wristScoreListeners = this.wristScoreListeners.filter(cb => cb !== callback);
    };
  }

  public subscribeState(callback: StateCallback): () => void {
    this.stateListeners.push(callback);
    callback(this.getState());
    return () => {
      this.stateListeners = this.stateListeners.filter(cb => cb !== callback);
    };
  }

  private notifyState() {
    const current = this.getState();
    this.stateListeners.forEach(cb => cb(current));
  }

  private notifyShot(event: ShotEvent) {
    this.state.lastShotEvent = event;
    this.state.shotHistory = [event, ...this.state.shotHistory.slice(0, 19)];
    this.notifyState();
    this.shotListeners.forEach(cb => cb(event));
  }

  public syncLiveScoring(syncData: WatchLiveScoringSync | null) {
    this.state.liveScoring = syncData;
    this.notifyState();
  }

  public sendWristScore(score: string): boolean {
    if (!this.state.isConnected) return false;
    this.wristScoreListeners.forEach(cb => cb(score));
    return this.wristScoreListeners.length > 0;
  }

  public setConnected(connected: boolean) {
    this.state.isConnected = connected;
    this.notifyState();
  }

  public setSensitivity(sensitivity: number) {
    this.state.sensitivityG = Math.max(1.5, Math.min(5.0, Number(sensitivity.toFixed(1))));
    this.notifyState();
  }

  public setDetecting(detecting: boolean) {
    this.state.isDetecting = detecting;
    this.notifyState();
  }

  private startHeartRateSimulation() {
    if (this.heartRateInterval) clearInterval(this.heartRateInterval);
    this.heartRateInterval = setInterval(() => {
      if (!this.state.isConnected) return;
      const delta = (Math.random() - 0.5) * 4;
      const newHr = Math.round(Math.max(95, Math.min(145, this.state.heartRate + delta)));
      this.state.heartRate = newHr;
      this.notifyState();
    }, 3000);
  }

  private initMotionListener() {
    if (typeof window === 'undefined' || !window.DeviceMotionEvent) return;

    try {
      window.addEventListener('devicemotion', (e: DeviceMotionEvent) => {
        if (!this.state.isConnected || !this.state.isDetecting) return;
        const acc = e.accelerationIncludingGravity || e.acceleration;
        if (!acc || acc.x === null || acc.y === null || acc.z === null) return;

        const totalG = Math.sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z) / 9.80665;
        const now = Date.now();

        if (Math.abs(totalG - 1.0) < 0.25) {
          if (!this.isAiming) {
            this.isAiming = true;
            this.holdStartTime = now;
          }
        }

        if (totalG > this.state.sensitivityG) {
          if (this.isAiming && this.holdStartTime && now - this.holdStartTime > 800) {
            const holdSec = Number(((now - this.holdStartTime) / 1000).toFixed(1));
            this.triggerShotEvent(totalG, holdSec);
            this.isAiming = false;
            this.holdStartTime = null;
          }
        }
      });
    } catch {
      // Device motion not permitted or unsupported
    }
  }

  public triggerShotEvent(customG?: number, customHoldSec?: number): ShotEvent {
    const peakG = customG || Number((this.state.sensitivityG + 0.5 + Math.random() * 1.2).toFixed(2));
    const holdDurationSec = customHoldSec || Number((2.8 + Math.random() * 2.2).toFixed(1));
    const stabilityScore = Math.min(99, Math.round(88 + Math.random() * 10));

    let suggestedScore = '10';
    if (stabilityScore > 94 && Math.random() > 0.4) {
      suggestedScore = 'X';
    } else if (stabilityScore > 90) {
      suggestedScore = Math.random() > 0.3 ? '10' : '9';
    } else if (stabilityScore > 85) {
      suggestedScore = Math.random() > 0.4 ? '9' : '8';
    } else {
      suggestedScore = '7';
    }

    const event: ShotEvent = {
      id: `shot-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
      peakG,
      holdDurationSec,
      stabilityScore,
      heartRateBpm: this.state.heartRate,
      suggestedScore,
      confirmed: false,
    };

    this.notifyShot(event);
    return event;
  }
}

export const watchService = new WatchService();
