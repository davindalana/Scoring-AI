# Archery Score Pro

A precision Olympic archery scoring and analytics web application built with React, TypeScript, and Vite. Complies with World Archery target scoring rules and standards.

## Features

- **Tactile Scoring Keypad & Olympic Target Face**:
  - Interactive SVG Olympic target face with 10 concentric rings and inner X bullseye. Tap any ring to record an arrow score with instant visual feedback.
  - Responsive, tactile keypad with quick entry buttons for X (10 pts), 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, and M (Miss).
  - Arrow slots with ring-color coding (Gold, Red, Blue, Black, White).
  - Desktop keyboard shortcuts (1-9, 0 for 10, X, M, Backspace, Arrow keys, Enter).

- **Athlete Management & Directory**:
  - Registered athletes directory with search filtering.
  - Register new athletes with full names and custom registration codes.
  - Direct 1-click "Shoot" action to start a session for any athlete.

- **Session Configuration & Flexibility**:
  - Bow Categories: Recurve (Olympic Standard), Compound, Barebow, Standard Bow / National.
  - Session Types: Training (Practice) or Competition (Official Round).
  - Distances: 70m, 50m, 30m, 18m, or custom distance.
  - Ends & Arrow formats: 3 or 6 arrows per end, customizable end count (1–50).

- **Live Analytics & Scorecard**:
  - Real-time dashboard: Current End, End Total, End X count, Session Total, Running Arrow Average.
  - Interactive end correction modal allowing adjustments to any previously recorded end.
  - Automatic cumulative progression tracking.

- **AI Target & Arrow Detection**:
  - Computer vision engine for target and arrow detection from uploaded photos or camera capture.
  - Calculates impact positions, ring distance ratios, and confidence scores.
  - Interactive candidate score chips review with quick cycling/correction before applying directly to current end slots.

- **Mobile-First UX & Ergonomics**:
  - Touch-first responsive mobile interface with sticky bottom navigation (Home, Score, iWatch, Athletes).
  - Tactile vibration haptic feedback and safe-area optimization for smartphones.

- **Apple Watch (iWatch) Integration & Shot Recoil Detection**:
  - Live Apple Watch companion simulator and sync service (`WatchService`).
  - CoreMotion release recoil impulse detector: detects bowstring release shock (G-force), hold duration (seconds), heart rate (BPM), and aiming stability.
  - Interactive **Shot Rematch Dialog**: prompts archer on every detected shot to verify, adjust, or discard before assigning to the arrow slot.
  - Quick wrist keypad allowing score entries directly from the watch.
  - Native watchOS codebase preserved in `/watch_app/` (`ArcheryWatchApp.swift`, `WatchSessionManager.swift`, `MotionManager.swift`, `ShotDetector.swift`, `WatchContentView.swift`).


## Development

```bash
# Install dependencies
npm install

# Start development server on port 3000
npm run dev

# Build production bundle
npm run build
```
