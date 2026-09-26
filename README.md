# AetherNav Edge

**An offline-first spatial mobility assistant for Android.** When GPS and the
internet disappear, the phone falls back on its own camera, IMU, microphone and
on-device AI to perceive the environment, track movement, answer questions and
warn about hazards — all locally, with no account and no cloud.

> Built as a "Grand Finale" project. The four core features run 100% on-device;
> anything that touches the network (the live map, the optional voice model
> download) is strictly opt-in and off by default.

---

## Features

### Core — fully offline

- **Camera perception** — recognises signs, arrows, stairs, doors, exits and
  obstacles from the live camera using on-device ML Kit (text recognition +
  object detection). Includes a torch toggle. No image ever leaves the device.
- **IMU navigation & trip tracking** — heading from a tilt-compensated compass
  (fused accelerometer + magnetometer) and step-based dead-reckoning in a
  controlled demo area. Start / Stop / Reset a trip to get distance
  (steps × calibrated stride), elapsed time, step count, average speed and
  cadence. Stride length is user-calibratable (0.40–1.10 m).
- **Voice interaction** — ask local questions like *"Where is Exit 4?"* and get
  a spoken, grounded answer (`speech_to_text` + `flutter_tts`). Greetings and
  small talk are handled conversationally; navigation answers are computed
  deterministically and never fabricated.
- **Hazard alerts** — visual, spoken and haptic warnings for detected obstacles.

### Saved trips (Strava-style)

Every completed trip is saved locally (SQLite). The Trip tab lists past trips
(newest first), and tapping one replays its route: if Live location was on
during the trip, the GPS breadcrumb is drawn as a polyline on OpenStreetMap
tiles with start/finish markers; otherwise a full-screen stats card shows
distance, time, steps, pace, speed and cadence. Swipe to delete.

### Opt-in live map

A Map tab shows your position on OpenStreetMap raster tiles with a hand-drawn
"you are here" dot and accuracy circle (`flutter_map` + `geolocator`). This is
the **only** feature that uses the network and location, so it stays **off until
you enable "Live location" in Settings**.

<!-- README_CONTINUE -->

### Optional offline voice model (LLM)

For richer voice answers you can enable an **optional, fully-offline on-device
LLM** (llama.cpp via `llamadart`, running a ~0.8 GB Llama-3.2-1B-Instruct Q4_K_M
GGUF, CPU inference). It acts only as a *language front-end*: the model rephrases
facts the app already computed and is hard-constrained never to invent a place,
direction or distance. It is **opt-in**, downloaded once in the background (or
side-loaded from storage), and managed in **Settings → Offline AI**. With no
model — or on any failure or timeout — voice falls back to the deterministic
matcher, so the app always works without it.

---

## Tech stack

- **Flutter / Dart** (Material 3, local Inter / Inter Tight variable fonts)
- **State:** `provider` (ChangeNotifier controllers, composed in `main.dart`)
- **Perception:** `camera`, `google_mlkit_object_detection`,
  `google_mlkit_text_recognition`
- **Sensors / voice / haptics:** `sensors_plus`, `speech_to_text`,
  `flutter_tts`, `vibration`
- **Map / location:** `flutter_map`, `latlong2`, `geolocator` (OpenStreetMap tiles)
- **Storage:** `sqflite` (trip log + saved trips), `shared_preferences`
  (preferences), `path_provider`
- **Optional LLM:** `llamadart`, `background_downloader`, `file_picker`

`permission_handler` is intentionally pinned to `12.0.1` (>=13 forces
compileSdk 37, which the local toolchain resolves inconsistently).

---

## Getting started

### Prerequisites

- Flutter SDK (Dart `^3.13.1`) and the Android SDK (compileSdk 36, minSdk 24 /
  Android 7.0)
- An Android device or emulator. **Note:** the release APK bundles only the
  `arm64-v8a` ABI (every current phone), so x86 emulators are not supported —
  use a physical device or an arm64 emulator image.

### Run

```bash
flutter pub get
flutter run
```

### Build a release APK

```bash
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

> The release build is currently signed with the debug key (the Flutter
> template default) so it installs by sideloading. For Play Store distribution,
> add your own keystore and signing config in `android/app/build.gradle.kts`.

<!-- README_CONTINUE2 -->

## Permissions

Requested only when the relevant feature is used:

- **Camera** — perception tab
- **Microphone** — voice tab
- **Location** (fine/coarse) — only when *Live location* is enabled
- **Internet** — only for OpenStreetMap tiles and the optional model download
- **Notifications** — only to show the optional model download's progress

## Project layout

```
lib/
  core/          shared helpers (trip math, permissions)
  data/          models + sqflite database
  services/      perception, navigation (IMU), voice, LLM, location
  state/         provider controllers (one per feature)
  ui/            screens + widgets, root shell / navbar
assets/          fonts, launcher icon, demo landmark map
test/            pure unit tests (trip math, voice grounding, LLM fallback)
```

## Privacy

No accounts, no analytics, no cloud. Camera frames are processed on-device and
deleted; trips and logs live only in the app's local SQLite database. The only
outbound network calls are OpenStreetMap tile requests and the optional
one-time model download — both behind explicit opt-in toggles.

## Status & known limitations

- Verified on-device: build, install, launch, navigation across all tabs; the
  tilt-compensated compass; OSM tiles; trip tracking and saved-trip replay.
- IMU navigation is dead-reckoning in a controlled demo area, not a positioning
  system — it drifts and is not a GPS replacement.
- The optional LLM's native inference, the real background model download, and a
  live outdoor GPS walk are validated on physical hardware, not in CI.
- No performance figures are claimed here until measured on-device.

## License

No license file is included yet — add the license of your choice before
distributing.


