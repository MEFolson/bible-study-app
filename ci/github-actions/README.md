# iOS workflows waiting to be switched on

These two GitHub Actions workflows are ready but cannot be pushed into `.github/workflows/` yet:
the GitHub login used to publish this repository lacks the `workflow` permission, which GitHub
requires for any change to workflow files.

To switch them on, move both files into `.github/workflows/` (for example on github.com: open the
file, copy it, Add file, Create new file, name it `.github/workflows/<same name>`, paste, commit).

* `ios-compile-check.yml`: manual run, no secrets, builds the iOS app without signing to prove it compiles.
* `ios-testflight.yml`: manual run, builds, signs and uploads to TestFlight using the App Store Connect
  API key in the repository secrets listed at the top of the file.

Both use `.github/scripts/ios_prepare.sh` and `app/ios/ci/ExportOptions.plist`, which are already in place.
