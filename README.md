# MagicTrick

An iOS card trick app where the magician performs a real card trick using only physical device interactions — no buttons, no UI chrome, no visible controls.

## How It Works

The trick relies on **orientation**, **shake**, and **touch** — the phone itself becomes the prop.

### The Flow

1. **Idle** — Cards are stacked face-down in the center
2. **Rotate to landscape** — Cards fan out across the screen
3. **Spectator picks a card** — Drag any card upward, it flips face-up to reveal the card. Release it — the card stays visible for 2 seconds, then flips back and returns to the fan. The chosen card is secretly remembered.
4. **Rotate to portrait** — Cards gather back into a stack
5. **Shake the device** — Dramatic riffle shuffle animation plays
6. **Magician reveals** — Rotate to landscape, drag any card up, and it flips face-up showing... the spectator's card

### The Secret

During the shuffle, the magician **double-taps the top-right corner** of the screen. This activates a hidden trigger that makes any card the magician drags transform into the spectator's chosen card when it flips over.

Without the double-tap, the reveal works as expected — whatever card is dragged is revealed normally.

## Tech Stack

- **SwiftUI** — Pure SwiftUI, no UIKit (except AppDelegate for orientation lock)
- **CMMotionManager** — Accelerometer-based shake detection
- **Core Haptics** — Tactile feedback for card flips, shuffles, and reveals
- **iOS 16.0+**

## Project Structure

```
MagicTrick/
├── MagicTrickApp.swift          # App entry, AppDelegate for orientation
├── Models/
│   ├── Card.swift               # Card model with Rank/Suit enums
│   ├── Deck.swift                # 52-card deck
│   └── TrickPhase.swift         # Game phases: idle → spread → shuffling → reveal
├── ViewModels/
│   └── TrickViewModel.swift     # Core game logic, peek flow, shuffle, magic trigger
├── Views/
│   ├── ContentView.swift        # Root view, orientation + shake routing
│   ├── DeckView.swift           # Card layout, fan spread, drag gestures
│   ├── CardView.swift           # Individual card rendering (front + back)
│   └── RevealView.swift         # Reveal phase presentation
└── Utilities/
    ├── MotionManager.swift      # CMMotionManager shake detection
    └── HapticManager.swift      # Haptic feedback
```

## Key Design Decisions

- **No UI chrome** — No buttons, labels, or menus. All interaction is physical.
- **Card back** — Apple-style minimal design: deep navy, thin border, centered diamond, corner dots.
- **Finger-following drag** — Cards track the finger in 2D once flipped, before flip they only move upward.
- **Realistic shuffle** — Overhand riffle with staggered lifts, lateral spread, and slam-drop bounce.
