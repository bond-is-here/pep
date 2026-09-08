# Pep

**A little pep. A stronger you.**

A free, native iPhone workout tracker with playful colors, a smiling workout buddy, and simple routines you can start in a tap. Built entirely with SwiftUI. No account, ads, subscriptions, analytics, backend, or third-party app dependencies.

## Appearance and motion

Choose your colors in Settings:

- **Play** (default): bold violet, a butter-yellow buddy, and pale lavender surfaces.
- **Poolside:** fresh teal and soft peach.
- **Punch:** bright pink and cobalt.

All three palettes use a light appearance, clear typography, and rounded controls. Your selection applies throughout the app and persists between launches.

The buddy adds a small wobble and blink. Press responses, animated set checkmarks and counters, and a one-time workout completion celebration make progress feel tangible. The **Bring Pep to life** switch controls these effects. System **Reduce Motion** also takes precedence. Decorative animation pauses when the app is inactive.

## What works

- **Today:** a routine suggestion that rotates from your completed history, an instant routine chooser, your current week, one-tap start, resume an interrupted session, and optional weight check-in.
- **Routines:** three editable starter routines, a searchable library of 30 exercises, custom exercises, exercise reordering, and configurable sets, repetitions, and rest periods.
- **Workouts:** editable weights and repetitions, completed-set tracking, add/remove sets, elapsed time, a rest timer, and a completion recap. Previously completed weights carry into the next session of the same routine.
- **Progress:** completed sessions, total training volume, weekly activity, body-weight trends, individual session details, and confirmed deletion of workouts and weight check-ins.
- **Little wins:** lifetime workout milestones, from your first session to the high-five club and beyond. Milestones count real saved workouts, with no streak to lose.
- **Settings:** kilograms/pounds, a weekly goal of one to seven sessions, and backup/restore through Files.

Workout volume counts completed sets only. Starter routines are supplied; workout history and body weights start empty.

## Run on iPhone

1. Complete Xcode's first launch setup, including reviewing its license and installing an iOS simulator runtime if needed.
2. Open **`Pep.xcodeproj`** in Xcode 16 or later.
3. Select the **Pep** scheme and an iPhone simulator, then press **Run**.
4. To run on a physical iPhone, choose your signing team in **Signing & Capabilities**, set a bundle identifier for your team if needed, and select your connected phone.

Minimum deployment target: **iOS 17**. The project supports iPhone and iPad, with an interface designed primarily for iPhone. App Store submission and distribution signing are separate from this source project.

## Data

`WorkoutStore` saves an atomic JSON snapshot under the app's Application Support directory at `RepComet/workouts.json`. Routine changes, valid set edits, active workouts, rest deadlines, weight entries, units, and goals persist automatically. Rest timers use an absolute date and resume correctly after backgrounding or reopening the app; they do not send notifications while the app is closed.

Appearance preferences live separately in `RepComet/appearance.json`, so changing palettes or motion does not alter a workout or its history.

The source folder retains its original `RepComet` path, and the app retains bundle identifier `app.repcomet.ios`. Its project, display name, build product, and shared Xcode scheme are **Pep**. Keeping the identifier and storage paths preserves compatibility with existing installations.

Corrupt data is preserved in a recovery backup, with a notice that survives relaunch. Settings → Back up & restore → Save recovery copy exports the most recent untouched file for possible repair; all originals stay on the device. Inaccessible files and data from a newer schema are left untouched. Backups are validated before loading; failed imports leave the current log intact. Finishing or discarding a workout, editing a routine, and adding or deleting history require a successful disk write. Failed active-set saves keep the current edits open with a visible retry action.

Choose **Settings → Back up & restore → Save to Files** to export your routines, sessions, weights, preferences, and active workout. Choose **Choose a backup** to review the counts and explicitly replace your log. Finish or discard a current workout before restoring. Backups are limited to 20 MB and contain personal workout/weight information; keep them somewhere you trust. Appearance preferences stay on the device. The app has no automatic network requests or cloud synchronization; any cloud location used in Files is chosen by you.

## Verification

Run project validation, native source typechecking, and the Foundation/Observation regression tests:

```sh
bash Tools/check.sh
```

Run just the model tests on a configured Xcode installation:

```sh
swift test
```

On the development Mac, an optional runner uses the installed Command Line Tools and XCTest frameworks without changing system settings:

```sh
Tests/run-core-tests.sh --command-line-tools
```

The regression tests cover persistence, active workout and timer restoration, completed-only volume, historical snapshots, routine identity and rotation, milestones, localized numeric entry and weight precision, validation, unit conversions, week boundaries, corrupt-data recovery, future-schema protection, backup/restore transactions, and write failures.

The shared Pep scheme includes a native XCUITest target. GitHub Actions runs it on an available iPhone simulator, as well as the core checks and an unsigned iPhone Release build. UI tests use a separate DEBUG-only data directory and preserve it within each relaunch test. The local Mac's Xcode license and simulator setup remain incomplete, so local iOS runtime testing requires finishing that setup. Native macOS renders are useful for layout inspection, but are not iPhone runtime tests or App Store screenshots. The separate HTML prototype used in early design is not a test of the shipped SwiftUI app.

## Project structure

```text
Pep.xcodeproj/         iOS app project with shared Pep scheme
RepComet/RepCometApp.swift  App entry point
RepComet/DesignSystem.swift Colors, typography, components, and the Pep buddy
RepComet/Appearance.swift Persisted color palettes and motion preferences
RepComet/Core/             Codable models, exercise library, observable store
RepComet/Views/            App screens and workout/routine/weight flows
RepComet/Assets.xcassets/   Original app icon and accent color
Tests/                 Core tests and optional local runner
Tools/                 Reproducible project and icon generators
```

After adding or removing Swift files, regenerate the Xcode project with `python3 Tools/generate_project.py`. The project has no package dependencies. To redraw the original icon, run `python3 Tools/generate_icon.py` with Pillow installed; the generated icon is already included.
