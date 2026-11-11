# Changelog

## 1.0.2

* New search screen: tap the magnifying glass in the top bar. It searches the chosen translation, or every text, fully offline, highlights the matches, and opens the verse you tap. Hebrew and Greek can be typed with or without vowel points and accents.
* Android: the APKs are now signed with the project's own release key instead of the Flutter debug key. Anyone with 1.0.0 or 1.0.1 installed must uninstall it once before installing 1.0.2 (this deletes notes kept in the app). New version code scheme so later updates install over any of the APK files.
* Windows: the program's file details now name Matthew Folson as the company and copyright holder, and the Microsoft Visual C++ runtime files it needs are included in the folder.
* Android and Windows builds now run on GitHub Actions (`release-builds.yml`). iPhone builds still go through TestFlight.


## 1.0.1

The user facing name is now Zagros Bible Study. On an iPhone home screen the label is Zagros Bible, because the full name is too long to show in full. The App Store listing name is Zagros Bible Study App. The bundle id and Android application id are unchanged (`com.mfolson.biblestudy`). The program file on Windows is still `bible_study.exe`.

Android builds in this release show the new name. The Windows download was rebuilt on a Windows PC, so the window title, ProductName, and FileDescription say Zagros Bible Study, and the version is 1.0.1.

## 1.0.0

First public release, with ready to run apps for Windows and Android. iPhone was not yet available.
