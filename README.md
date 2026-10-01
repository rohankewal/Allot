# Shikaku

A daily Shikaku puzzle that lives on the Home Screen. The app is just a way
to get the widget: it shows the same board, the rules, and how to add it.

Same family as Lift and Settle: SwiftUI, the monochrome Ink palette (light
and dark as true inversions), Xcode 27 with synchronized folders.

## The puzzle

- **One a day, for everyone.** Boards are made on the phone from the date
  (seeded SplitMix64), so there's no server and everyone gets the same board
  on the same day. It changes at local midnight whether or not the last one
  was finished.
- **Difficulty is random each day:** easy (5×5), medium (6×6) or hard (7×7).
- **Every board is fair.** The generator only keeps boards with exactly one
  answer that can be reached by logic alone, no guessing. Easy needs only
  the basic rules; hard boards are chosen because they need the "overlap"
  technique at least twice. See `Shared/Engine/Solver.swift`.

## Playing in a widget

Widgets can't follow a drag, so a box is drawn with two taps: one corner,
then the opposite corner (the same cell twice makes a 1×1). A new box
replaces any it overlaps; tapping a box removes it. Each cell is a
`Button(intent:)` running `TapCellIntent`, which saves to the App Group;
WidgetKit redraws afterwards.

Box states are shown by shape, not colour: dashed = wrong size, shaded =
fits, solid ink = board solved.

## Settings

Stored in the App Group (`Shared/Settings.swift`) so the widget follows them.

- **Appearance:** Automatic, Light or Dark. The app sets it on its windows;
  the widget overrides its colour scheme when one is forced.
- **Difficulty:** Daily mix (random) or always easy / medium / hard. A fixed
  level still gets a board seeded by the date, so everyone on that level gets
  the same board. Changing it starts today's board over.
- **Mark wrong sizes:** the dashed outline hint. Off = no hints until solved.
- **Show solve time.**
- **Daily reminder** at a chosen time: one-off notifications 30 days ahead,
  each naming that day's difficulty; today's is dropped once it's solved.
  Topped up whenever the app comes forward.
- **Haptics** (app only; widgets can't vibrate).

## Layout

| Folder | Target | What |
|---|---|---|
| `Shared/Engine` | all | Puzzle model, seeded generator, solver |
| `Shared` | app + widget | Board state, App Group store, intents, theme, `BoardView` |
| `ShikakuWidgets` | widget | Large widget, timeline (now + midnight) |
| `Shikaku` | app | Home screen with the board, rules, widget steps |
| `ShikakuTests` | tests | A year of boards: unique, no guessing, stable |

## First run

1. Open `Shikaku.xcodeproj`. Team and bundle IDs are set
   (`com.rohankewalramani.Shikaku`, App Group
   `group.com.rohankewalramani.Shikaku`); Xcode registers the group.
2. Run the **Shikaku** scheme, then add the large widget to the Home Screen.
3. Deployment target is iOS 17, the first with interactive widgets.
