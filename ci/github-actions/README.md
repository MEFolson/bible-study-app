# Workflows waiting to be switched on

These GitHub Actions workflows are ready but cannot be pushed into `.github/workflows/` yet:
the GitHub login used to publish this repository lacks the `workflow` permission, which GitHub
requires for any change to workflow files.

To switch them on, copy each file into `.github/workflows/` (for example on github.com: open the
file, copy it, Add file, Create new file, name it `.github/workflows/<same name>`, paste, commit).

* `ci.yml`: runs on push and pull request to `main`. Sets up Flutter stable, checks format,
  runs `flutter analyze` and `flutter test` (downloads `bible.sqlite.gz` from the v1.0.0
  release, verifies its sha256, unpacks it and runs `pack_db.py`), then builds a debug APK.
  It does not replace GitHub Pages.
* `ios-compile-check.yml`: manual run, no secrets, builds the iOS app without signing to prove it compiles.
* `ios-testflight.yml`: manual run, builds, signs and uploads to TestFlight using the App Store Connect
  API key in the repository secrets listed at the top of the file.

The iOS workflows use `.github/scripts/ios_prepare.sh` and `app/ios/ci/ExportOptions.plist`, which are already in place.
