# TO DO LIST — Flutter

A polished, responsive Flutter To Do List app based on the supplied mobile UI reference.
The app uses a dark navy/purple night-sky palette, glass-style task surfaces, and a
mountain illustration drawn entirely with Flutter so it has no external image assets.

## Included screens

- Home dashboard
- Add Task bottom sheet
- Task options menu
- Edit Task
- Completed Tasks view
- Empty state
- Full Task Details
- Statistics / Progress
- Settings

## Features

- Create, edit, delete, complete and uncomplete tasks
- High / Low priority
- Due dates
- Descriptions
- All / Today / High Priority / Completed filters
- Progress ring and statistics
- Local persistence using `shared_preferences`
- Dark blue glass-style UI
- Responsive layouts
- No external image assets required; the mountain header is drawn in Flutter

## Run locally

```bash
flutter pub get
flutter run
```

The Android platform folder is included, so this project can be opened directly in
Android Studio or built with `flutter build apk` on a machine with the Android SDK.

## Verify

```bash
flutter analyze
flutter test
```

Every push to `main` also runs the Android release build in GitHub Actions.
The resulting `app-release.apk` is uploaded as the `app-release` workflow artifact.

## GitHub

Commit the whole `todo_list_flutter` folder, including `android/`, `lib/`, `test/`,
`pubspec.yaml`, and `pubspec.lock`. Generated folders such as `.dart_tool/` and
`build/` are ignored.

## Replit

If Flutter is enabled in the workspace, run the same commands from this folder.
