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
1. As soon as you push to `main` (or run it manually via the **Run workflow** button in GitHub Actions), the cloud runner will:
   - Check out the codebase.
   - Set up **Java JDK 17** & the latest **Flutter SDK**.
   - Run `flutter pub get`.
   - Compile both **Split-per-ABI APKs** (optimized for ARM64 / v7a) and a **Universal Release APK**.

---

### Step 3: Download the APK
1. Go to your repository on **GitHub.com**.
2. Click on the **Actions** tab at the top.
3. Click on the latest workflow run: **"Build Android APK"**.
4. Scroll down to the **Artifacts** section at the bottom of the page.
5. Click **`workhub-mobile-apk`** to download the zip file.
6. Inside the zip, you will find:
   - `app-release.apk` (Universal APK — installable directly on any Android device!).
