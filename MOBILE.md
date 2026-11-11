# Zagros Bible Study on Android and iPhone

Both phone versions come from the same Flutter project as the Windows app (`app/`). They are fully offline: the Bible database is packed inside the app and nothing is downloaded.

## Android

The release files, attached to each GitHub release (checksums in `SHA256SUMS.txt` there):

| File | For |
|---|---|
| `bible_study_android.apk` | any Android phone (all three processor types in one file). Share this one if unsure. |
| `bible_study_android_arm64.apk` | almost every phone from the last several years (smaller) |
| `bible_study_android_armv7.apk` | older 32 bit phones |
| `bible_study_android_x86_64.apk` | emulators and a few tablets |

App name: Zagros Bible Study. Application id: `com.mfolson.biblestudy`. Version 1.0.2. Needs Android 7.0 or newer (minimum SDK 24).

Signing: from 1.0.2 the APKs are signed with the project's own release key, not the Flutter debug key that signed 1.0.0 and 1.0.1. Android only installs an update signed with the same key, so anyone who has 1.0.0 or 1.0.1 installed must uninstall it once before installing 1.0.2. Notes are kept inside the app, so uninstalling deletes them. Later versions are signed with the same release key and install over 1.0.2 normally. How signing works, and the version code scheme, is in `app/README.md`.

### Installing the APK

1. Copy the APK to the phone (for example by USB, a cloud drive, or a messaging app that keeps the file intact).
2. Open the file on the phone. Android will ask to allow installs from that source: tap Settings, switch on "Allow from this source" (on some phones the setting is called "Install unknown apps"), then go back and tap Install.
3. If Play Protect warns that the app is unknown, choose to install anyway. This happens because the app is not from the Play Store.
4. Have about 800 MB free: about 200 MB for the app and 445 MB for the unpacked database.

### First launch

On the first launch the app unpacks its database (445 MB) into its own private storage and checks every part. This can take a minute on a phone; a progress bar shows how far it is. Later launches open straight away. If the copy is interrupted, it is simply redone next time. The unpacked copy is opened read only and is never changed. Notes are kept in a separate `user.sqlite`.

### Building the APKs

The release APKs are built on GitHub Actions by `.github/workflows/release-builds.yml` (started by hand from the Actions tab). It fetches the published database, checks its SHA256, packs it, runs `flutter analyze` and `flutter test`, builds the universal and per ABI APKs with Flutter 3.47.9, signs them with the release key from the repository secrets, and checks with `apksigner` that no file is signed with the debug key. The same workflow builds the Windows zip.

To build locally instead, after any pipeline rebuild:

```
cd app
python3 tool/pack_db.py
flutter build apk --release
flutter build apk --release --split-per-abi
```

`tool/pack_db.py` packs `../data/build/bible.sqlite` into 27 compressed parts in `assets/db` (148 MB), which only the Android and iOS builds include. A local release build needs `android/key.properties` (see `app/README.md`).

## iPhone: project ready, builds through GitHub Actions (no Mac needed)

The iOS project is set up in `app/ios`: the home screen name is Zagros Bible (the full name Zagros Bible Study is longer than an iPhone home screen label usually allows), the App Store listing name is Zagros Bible Study App, bundle id `com.mfolson.biblestudy`, iOS 15 or newer for the app itself (testers installing through TestFlight need iOS 16 or newer, because Apple's TestFlight app requires it), export compliance key `ITSAppUsesNonExemptEncryption` set to false, a privacy manifest (`Runner/PrivacyInfo.xcprivacy`: no tracking, no data collected, file size and date checks inside the app's own folder, reason C617.1), and an open book app icon.

On first launch the database is unpacked into `Library/Application Support/bibledb` and that folder is marked as excluded from iCloud and computer backups (a small native call in `Runner/AppDelegate.swift`). It is not put in Caches, because Apple's backup guidance says the system purges Caches from time to time, and the app cannot show any text without the database.

Building happens on GitHub's Mac runners, which are free for public repositories:

* `.github/workflows/ios-compile-check.yml` builds the app without signing, to prove it compiles. No secrets needed. The unsigned compile check passed on 10 Nov 2026: https://github.com/MEFolson/bible-study-app/actions/runs/42834139920
* `.github/workflows/ios-testflight.yml` builds, signs automatically with an App Store Connect API key, and uploads to TestFlight. It needs the repository secrets listed at the top of the file.

Both run only when started by hand from the Actions tab.

## TestFlight

The public TestFlight link is https://testflight.apple.com/join/WHB5rhqx. Each TestFlight build can be tested for up to 90 days from its upload, so a new build has to be uploaded before then. On the App Store and in TestFlight, Apple shows the developer as Ekow Ako Folson, because an individual developer account must use the account holder's legal name.

## Not tested yet

* No APK has been installed or run on a real Android phone yet, including 1.0.2. The Android emulator could not start on the build box (its virtual machine never booted), so the first launch copy was tested instead with the same code (`flutter test`, `test/bundled_db_test.dart`): all 27 parts unpacked and the copy was byte identical to `bible.sqlite`. Please try the APK on a phone and report what happens.
* The phone layout (text rows stacked, the word, cross reference and notes panel sliding in from the right) were checked in a narrow window on Linux, and the search screen in widget tests with images rendered at phone width, not on a phone.
