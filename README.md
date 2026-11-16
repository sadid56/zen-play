# ZenPlay

A clean, Material 3 YouTube client built with Flutter and Dart for **Android** and **iOS** — no sign-in, no profile clutter, and no Shorts.

## Features

- **Material 3 UI (Light & Dark)** with adaptive theming and custom **ZenPlay** brand mark
- **Live YouTube Integration** via `youtube_explode_dart` (feeds, search, channel uploads, comments, and multi-resolution streams without API keys)
- **Native Video Playback** via `video_player` with double-tap seek, playback speed control, resolution switching, and persistent mini-player
- **Community Enhancements**:
  - **SponsorBlock** automatic sponsor segment skipping
  - **Return YouTube Dislike** vote counts
  - **DeArrow** & Shorts-free feed toggles
- **Watch Page Actions**: Share link, Download with resolution picker, Watch Later, Chapters, Comments, and Live Chat
- **Polished Loading UX**: App opening splash loader and animated skeleton placeholders across feeds, search, channels, and comments

## Prerequisites

- **Flutter SDK** (`3.50.0` or compatible, with **Dart** `^3.5.0`)
- **Android**: Android Studio + Android SDK (for Android emulator or USB-debugging device)
- **iOS (macOS only)**: Xcode + iOS Simulator + CocoaPods (`brew install cocoapods`)

## Setup & Run

1. **Install dependencies**:
   ```sh
   flutter pub get
   ```

2. **Check connected devices & environment**:
   ```sh
   flutter doctor
   flutter devices
   ```

3. **Run on Android or iOS**:
   - **Android**: Connect a physical device (with USB debugging enabled) or start an Android Emulator, then run:
     ```sh
     flutter run
     ```
   - **iOS**: Open the iOS Simulator (`open -a Simulator`), then run:
     ```sh
     flutter run
     ```

4. **Run tests**:
   ```sh
   flutter test
   ```
