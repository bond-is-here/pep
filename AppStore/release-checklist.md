# Pep release checklist

The app is free and has no subscriptions or in-app purchases. This checklist
records work that still belongs to the Apple Developer/App Store Connect owner;
no signing, upload, purchase, or submission is performed by this repository.

## Repository and build

- [x] Native SwiftUI iPhone app, Pep icon, privacy manifest, and shared scheme.
- [x] Core persistence and workout behavior checks.
- [x] GitHub Actions workflow for native simulator UI tests and unsigned iPhone Release builds.
- [x] Public MIT license, privacy policy, and support instructions.
- [ ] Run a signed Release archive with the correct development team.
- [ ] Confirm the final commit passes native simulator tests and review the attached screenshots.
- [ ] Test the signed build on supported iPhone sizes, VoiceOver, larger text, and Reduce Motion.

## App Store preparation

- [ ] Confirm that the Pep name and icon are available for the intended listing.
- [ ] Set price to Free and leave subscriptions and in-app purchases empty.
- [ ] Provide the actual seller, copyright, support URL, and privacy URL in App Store Connect.
- [ ] Complete Apple's App Privacy and age-rating questionnaires for the final build.
- [ ] Capture real iPhone screenshots with fictional workout data. The macOS previews in development are not App Store screenshots.
- [ ] Validate the final archive, export-compliance answers, version, build number, and signing entitlements before submission.

Build success is evidence of compilation and checks only; it does not prove
runtime behavior, signing readiness, App Store approval, or availability.
