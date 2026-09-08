# Contributing to Pep

Thanks for helping make Pep a little more useful and a little more fun.

## Before you start

- Keep the app free, local-first, and free of analytics, ads, accounts, and third-party dependencies.
- Preserve the existing `RepComet` storage paths and `app.repcomet.ios` bundle identifier unless a migration is included.
- Prefer SwiftUI and the existing Pep design system so new screens support the three palettes and Reduce Motion.

## Verify a change

Run the repository check before opening a pull request:

```sh
bash Tools/check.sh
```

This validates project metadata, typechecks the native sources, and runs the core persistence tests. If Xcode's license is unavailable on a local Mac, the check automatically uses the installed Command Line Tools. Use Xcode to run the shared `Pep` scheme on an iOS 17 simulator when available.

## Pull requests

Describe the user-facing behavior, include screenshots for visual changes, and list the checks you ran. Keep changes focused and explain any data-model or migration impact. Never include personal workout or weight data in screenshots, fixtures, or issue reports.
