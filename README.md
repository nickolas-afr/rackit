# Rackit

Built for personal use.
A native iOS strength-training log, built for one user and one job: **logging a set has to be faster than doing the set.**

Local-only. No network, no account, no sync, no telemetry. Everything lives in a SwiftData store on the phone.

## Requirements

- **Xcode 27** (`objectVersion = 110`; Xcode 26 cannot open the project). On this machine it lives at `~/Downloads/Xcode-beta.app`.
- **iOS 27.0** minimum.

`xcode-select` points at the stable Xcode, so `build.sh` sets `DEVELOPER_DIR` explicitly rather than needing `sudo`:

```bash
./build.sh build
```

```bash
./build.sh test
```

## Targets

| Target | What it is |
|---|---|
| `Rack` | The app. |
| `RackWidgets` | Widget extension holding the rest-timer Live Activity. |
| `RackTests` | Unit tests over the pure logic and the model layer. |
| `Shared/` | Folder compiled into both `Rack` and `RackWidgets` — just the Live Activity attributes. |

## How it works

### Logging

The set row is `[type] [last time] [weight] [reps] [✓]`.

- **Rows pre-fill from history.** Opening a session mirrors the last completed session containing that exercise — same row count, same loads, same set types — with last time's numbers in grey beside each row. Same as last time costs exactly one tap. With no history, rows fall back to the split's target reps at zero load.
- **A custom numeric panel replaces the system keyboard.** Every value is a button, not a text field, so the system keyboard never appears. The panel leads with step buttons (±1.25 / ±2.5 / ±5 kg, ±1 rep) because mid-workout the intent is almost never "type 102.5", it's "same as last set, plus 2.5". There is a digit grid for exact entry, a Next action running weight → reps → next set, and an ✕ to dismiss the panel when a field is tapped by accident.
- **Set types** cycle by tapping the number chip. Warm-ups are excluded from volume, from records, and from the rest timer.
- **Unchecked sets are discarded on finish**, and the confirmation says how many. Keeping them as zeros would corrupt every volume total that reads the session afterwards.

### Rest timer

Auto-starts when a set is checked off, using the split's override or the exercise's default.

The countdown is derived from an **absolute end date**, never a decrementing counter — a tick-based timer drifts or stalls the moment iOS suspends the app, which is exactly what happens when the phone goes in a pocket. A local notification is scheduled for the same instant, and a **Live Activity** puts the countdown on the lock screen; both render from the end date, so neither needs the app to be alive.

### Records

Detected when a session is **finished**, not while logging — until then a set can still be edited or deleted. Four per exercise: heaviest weight, best estimated 1RM, best single-set volume, best session volume.

**Equalling a previous best is not a record.** The comparison is strictly greater than.

Deleting a session rebuilds the whole record table from what remains, so a record can never outlive the session that produced it. Changing the 1RM formula offers the same rebuild, and modifies no session.

### Units

Every weight is stored in **kilograms**. Conversion happens only at the edge, for display, so switching units cannot introduce rounding drift into stored data.

The numeric panel reads its decimal separator back out of the same format style that renders every number on screen, rather than from `Locale.decimalSeparator` — the two can disagree (notably for `autoupdatingCurrent`), and when they do the keypad puts one glyph on its key while the row beside it shows another.

## Architecture notes

- `Rack/Logic/` is pure and `nonisolated`: 1RM, plate maths, volume, muscle-load decay, record detection, unit formatting. It works on plain value types, which is what makes it testable without standing up a store.
- `Rack/Services/` bridges that logic to SwiftData and to the system (notifications, haptics, Live Activity).
- `Rack/Features/` is the UI, one folder per screen area.
- Default actor isolation is `MainActor`. Pure logic types opt out with `nonisolated` so they are usable from anywhere.
- SwiftData delete rules are declared on the parent side, which is the only place SwiftData honours the inverse: deleting a split nullifies its sessions rather than deleting them, and deleting an exercise leaves the history of having performed it intact (session rows snapshot the name).

## Tests

143 tests. The pure logic is covered directly — 1RM formulas including the rep cap and the single-rep case, plate maths in whole grams, unit formatting and round-tripping across locales, volume rules including the bodyweight fallback, 7-day-half-life decay, and record detection including ties — plus model-level tests for the store, seeding, logging and the record lifecycle.

```bash
./build.sh test
```
