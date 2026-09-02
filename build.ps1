# Donora+ — Release build helper (PowerShell)
# Ensures --dart-define-from-file=.env is always included so that
# SUPABASE_URL, SUPABASE_ANON_KEY, and QWEN_API_KEY are baked in.

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Error "ERROR: .env file not found at $EnvFile`nCopy .env.example to .env and fill in real values."
    exit 1
}

$Target = if ($args.Count -gt 0) { $args[0] } else { "apk" }

Write-Host "Building Donora+ ($Target) with env from .env ..."

switch ($Target) {
    "apk" {
        flutter build apk --release --dart-define-from-file=$EnvFile
        Write-Host "APK built: build\app\outputs\flutter-apk\app-release.apk"
    }
    "appbundle" {
        flutter build appbundle --release --dart-define-from-file=$EnvFile
        Write-Host "App bundle built: build\app\outputs\bundle\release\app-release.aab"
    }
    "ios" {
        flutter build ios --release --dart-define-from-file=$EnvFile
        Write-Host "iOS build complete. Open ios\Runner.xcworkspace to archive."
    }
    "web" {
        flutter build web --release --dart-define-from-file=$EnvFile
        Write-Host "Web build: build\web\"
    }
    default {
        Write-Error "Unknown target: $Target`nUsage: .\build.ps1 [apk|appbundle|ios|web]"
        exit 1
    }
}
