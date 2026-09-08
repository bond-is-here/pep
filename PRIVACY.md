# Pep privacy policy

Last updated: September 7, 2026

This policy describes the Pep iPhone app in this repository. Pep is a workout
routine and progress tracker. It does not require a Pep account.

## Information kept on your device

Pep stores the information you enter so it can build routines, record workouts,
calculate training volume, and show progress:

- Routine names, exercises, sets, repetitions, rest periods, and completed sets.
- Workout start and finish times and the routine history shown in Progress.
- Optional body-weight check-ins, the selected kilograms/pounds unit, and your
  weekly workout goal.
- Appearance preferences such as the selected Pep palette and motion setting.

The app saves these records in an atomic JSON file under the app's Application
Support directory. It has no developer-operated workout server and no cloud
sync feature. Your routines, workouts, and weight entries are not uploaded by
the app. Device backups are a separate matter controlled by Apple.

Pep does not read from or write to Apple Health or HealthKit. Its locally saved
workout and body-weight information is app data, not an Apple Health database.

## Analytics, advertising, and support

Pep contains no analytics, advertising, tracking, or third-party crash-reporting
SDK. It does not sell workout or body-weight information.

If you contact the maintainers through [Pep GitHub Issues](https://github.com/bond-is-here/pep/issues),
your GitHub identity and anything you post are visible to maintainers and other
readers of that public issue. Do not post workout archives, body measurements,
medical information, credentials, or screenshots containing private details.

## Retention and deletion

Pep keeps local records until you change or remove them. You can delete an
individual weight check-in from Progress and delete routines from the routine
editor; completed workout history remains available unless you delete the app.

To remove all Pep data stored in the current iPhone app container:

1. Open iOS Settings > General > iPhone Storage > Pep.
2. Choose Delete App and confirm.

This permanently removes the current app container. Offload App preserves app
data, and Remove from Home Screen does not uninstall the app. iCloud or
computer backups may contain earlier app data; deleting Pep does not promise
removal of those backup copies.

## Questions and changes

For help with these controls, see [SUPPORT.md](SUPPORT.md) or raise a general,
non-sensitive question through [GitHub Issues](https://github.com/bond-is-here/pep/issues).
Updates to this policy will be published here with a revised date.
