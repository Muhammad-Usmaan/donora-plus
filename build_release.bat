@echo off
REM ──────────────────────────────────────────────────────────────
REM Donora+ — Release build (release APK)
REM
REM USAGE:  build_release.bat
REM
REM This script guarantees that --dart-define-from-file=.env is
REM always passed, so SUPABASE_URL and SUPABASE_ANON_KEY are baked
REM into the release binary.  Running raw `flutter build apk --release`
REM without this flag is the #1 cause of "No host specified in URI"
REM crashes in release mode.
REM ──────────────────────────────────────────────────────────────

setlocal

if not exist "%~dp0.env" (
    echo.
    echo ERROR: Missing .env file
    echo.
    echo   Copy .env.example and fill in Supabase credentials:
    echo     copy .env.example .env
    echo.
    exit /b 1
)

echo Building release APK with --dart-define-from-file=.env ...
flutter build apk --release --dart-define-from-file="%~dp0.env"
if %errorlevel% neq 0 (
    echo.
    echo Build failed.
    exit /b 1
)

echo.
echo Done → build\app\outputs\flutter-apk\app-release.apk
