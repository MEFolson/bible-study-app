# Bible Study on Android and iPhone

Both phone versions come from the same Flutter project as the Windows app (`app/`). They are fully offline: the Bible database is packed inside the app and nothing is downloaded.

## Android: ready to share

Files in `dist/`:

| File | Size (bytes) | For |
|---|---|---|
| `bible_study_android.apk` | 203435103 (203.4 MB) | any Android phone (all three processor types in one file). Share this one if unsure. |
| `bible_study_android_arm64-v8a.apk` | 166593759 (166.6 MB) | almost every phone from the last several years |
| `bible_study_android_armeabi-v7a.apk` | 163973875 (164.0 MB) | older 32 bit phones |
| `bible_study_android_x86_64.apk` | 168077851 (168.1 MB) | emulators and a few tablets |

Checksums are in `dist/SHA256SUMS_android.txt`. App name: Bible Study. Application id: `com.mfolson.biblestudy`. Version 1.0.0. Needs Android 7.0 or newer (minimum SDK 24). The APKs are signed with the standard Flutter debug key, which is fine for passing the file to people directly but not for the Play Store. To sign a release APK with your own keystore, see the signing section in `app/README.md`. Do not commit the keystore or `android/key.properties`.

### Installing the APK

1. Copy the APK to the phone (for example by USB, a cloud drive, or a messaging app that keeps the file intact).
2. Open the file on the phone. Android will ask to allow installs from that source: tap Settings, switch on "Allow from this source" (on some phones the setting is called "Install unknown apps"), then go back and tap Install.
3. If Play Protect warns that the app is unknown, choose to install anyway. This happens because the app is not from the Play Store.
4. Have about 800 MB free: about 200 MB for the app and 445 MB for the unpacked database.

### First launch

On the first launch the app unpacks its database (445 MB) into its own private storage and checks every part. This can take a minute on a phone; a progress bar shows how far it is. Later launches open straight away. If the copy is interrupted, it is simply redone next time. The unpacked copy is opened read only and is never changed. Notes are kept in a separate `user.sqlite`.

### Rebuilding the APK

On the build box (Linux), after any pipeline rebuild:

```
cd app
python3 tool/pack_db.py
flutter build apk --release
flutter build apk --release --split-per-abi
```

`tool/pack_db.py` packs `../data/build/bible.sqlite` into 27 compressed parts in `assets/db` (148 MB), which only the Android and iOS builds include. Tools used here: Flutter 3.47.9, Temurin JDK 17 in `/opt/jdk`, Android SDK in `/opt/android-sdk` (platform 36, build tools 36.0.0, plus what the Gradle build fetched itself: platform 35, NDK and CMake).

## iPhone: project ready, builds through GitHub Actions (no Mac needed)

The iOS project is set up in `app/ios`: display name Bible Study, bundle id `com.mfolson.biblestudy`, iOS 15 or newer, export compliance key `ITSAppUsesNonExemptEncryption` set to false, a privacy manifest (`Runner/PrivacyInfo.xcprivacy`: no tracking, no data collected, file size and date checks inside the app's own folder, reason C617.1), and an open book app icon.

On first launch the database is unpacked into `Library/Application Support/bibledb` and that folder is marked as excluded from iCloud and computer backups (a small native call in `Runner/AppDelegate.swift`). It is not put in Caches, because Apple's backup guidance says the system purges Caches from time to time, and the app cannot show any text without the database.

Building happens on GitHub's Mac runners, which are free for public repositories:

* `.github/workflows/ios-compile-check.yml` builds the app without signing, to prove it compiles. No secrets needed. The unsigned compile check passed on 10 Nov 2026: https://github.com/MEFolson/bible-study-app/actions/runs/42834139920
* `.github/workflows/ios-testflight.yml` builds, signs automatically with an App Store Connect API key, and uploads to TestFlight. It needs the repository secrets listed at the top of the file.

Both run only when started by hand from the Actions tab.

## Not tested yet

* The APK has not been run on a phone. The Android emulator could not start on this box (its virtual machine never booted), so the first launch copy was tested instead on the build box with the same code (`flutter test`, `test/bundled_db_test.dart`): all 27 parts unpacked and the copy was byte identical to `bible.sqlite`. Please try the APK on a phone.
* The phone layout (text rows stacked, the word, cross reference and notes panel sliding in from the right) was checked in a narrow window on Linux, not on a phone.
