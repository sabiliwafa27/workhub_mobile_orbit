# WorkHub Mobile Build & CI/CD Guide

This project is configured with automated Cloud Builds via **GitHub Actions** (`.github/workflows/build_apk.yml`). You can compile and download your Android `.apk` without installing the Flutter or Android SDK locally.

---

## How to Build & Download the APK

### Step 1: Initialize Git & Push to your GitHub Repository
In your preferred terminal (PowerShell or Command Prompt), run:

```bash
cd C:\Users\rosyad\flutter_edp_projects\workhub_mobile

git init
git add .
git commit -m "feat: initial workhub mobile scaffold with api client and ci"

# Link your remote GitHub repository
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPOSITORY_NAME>.git
git branch -M main
git push -u origin main
```

---

### Step 2: Automatic Compilation
1. Pull requests run tests and a verification build. A push to `main` creates a Shorebird release; a manual **Build Android APK** run can create a release or patch. The cloud runner will:
   - Check out the codebase.
   - Set up **Java JDK 17** & the latest **Flutter SDK**.
   - Run `flutter pub get`.
   - Run `flutter test`.
   - For a release, build a Shorebird-enabled ARM64 APK. For a patch, publish a Dart/Flutter update to the selected Shorebird release.

---

### Step 3: Download the APK
1. Go to your repository on **GitHub.com**.
2. Click on the **Actions** tab at the top.
3. Click on the latest workflow run: **"Build Android APK"**.
4. For a release run, download `app-release.apk` from the GitHub Release attached to that run.

## Shorebird OTA updates

The **Check for App Updates** menu now checks Shorebird first. If Shorebird is unavailable in the installed build, the app falls back to the existing GitHub APK updater.

1. Install Shorebird CLI, sign in to the Shorebird account that will own this app, and run `shorebird init` in the project. Add the generated app ID and a Shorebird API token to GitHub repository secrets as `SHOREBIRD_APP_ID` and `SHOREBIRD_TOKEN`.
2. Push to `main`, or run **Build Android APK** manually with `operation: release`. This creates a Shorebird release and publishes its ARM64 APK.
3. Install that Shorebird-built APK once. APKs previously built with plain `flutter build` do not contain the Shorebird runtime and cannot receive patches.
4. For later Dart or Flutter UI changes, run **Build Android APK** with `operation: patch` and the target release version (for example `1.0.0+42`). The patch downloads when the user taps **Check for App Updates** and takes effect after the app is fully closed and reopened.

Native Android or iOS code, plugin platform code, assets, permissions, or a Flutter engine change still requires a new full Shorebird release and APK installation.
