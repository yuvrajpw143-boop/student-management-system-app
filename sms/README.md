# EduTrack – Student Management System
Flutter app → REST API (Node/Express) → MySQL. Profile photos: Flutter → Firebase Storage.

## 1. Database
`mysql -u root -p < database/schema.sql` (creates DB `student_mgmt`, tables and demo data).

## 2. Backend
```
cd backend && npm install && cp .env.example .env   # edit DB_* and JWT_SECRET
npm start
```
Demo login (auto-created on first start): **admin@school.com / admin123**. Health check: `GET /api/health`.
Secrets live only in `backend/.env` (never commit it).

## 3. Firebase (you must do this – needs your Google login)
1. Create a Firebase project, enable **Storage**, add an **Android app** (package name = the one in `app/android/app/build.gradle`, e.g. `com.example.edutrack`).
2. Download **google-services.json** → put it in `app/android/app/`. (This is the only Firebase credential file; no keys are in the Dart code.)
3. Add the Google Services Gradle plugin per the Firebase console instructions; set `minSdkVersion 23`.
4. Storage rules (limits uploads to images under 5 MB):
```
rules_version='2'; service firebase.storage { match /b/{b}/o { match /students/{f} {
  allow read; allow write: if request.resource.size < 5*1024*1024 && request.resource.contentType.matches('image/.*'); } } }
```
Note: the app authenticates with your own JWT, not Firebase Auth, so these rules allow anonymous image uploads to `students/`. Fine for a demo; harden later with Firebase Auth or signed uploads.

## 4. Flutter app
```
cd app && flutter create . --platforms=android --project-name edutrack   # generates android/ (keeps lib/ and pubspec)
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000        # Android emulator -> local API
```
Add to `android/app/src/main/AndroidManifest.xml` for HTTP dev only: `android:usesCleartextTraffic="true"` (not needed with an https production URL). Add `<uses-permission android:name="android.permission.INTERNET"/>` if absent.

## 5. Production
Deploy `backend/` to Render/Railway/Fly (Node 18+, start command `npm start`) with a managed MySQL (Railway, PlanetScale-compatible, Aiven); set the env vars from `.env.example`; run `database/schema.sql` once.
```
flutter build apk --release --dart-define=API_URL=https://YOUR-BACKEND-URL
```
APK: `app/build/app/outputs/flutter-apk/app-release.apk`. Install: `adb install -r app-release.apk`, or copy it to the phone and open it (allow "install unknown apps"). Test: sign in with the demo user, add a student with photo, mark attendance, add marks, check Dashboard.
