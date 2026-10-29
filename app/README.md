# supermarket_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Tests

- `flutter test --exclude-tags golden` runs the regular suite (this is what CI runs).
- Golden tests (tag `golden`, images in `test/goldens/`): run locally with
  `flutter test --tags golden`, regenerate with `flutter test --tags golden --update-goldens`.
  They are excluded in CI because text rendering differs between macOS and Linux.
