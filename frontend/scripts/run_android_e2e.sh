#!/usr/bin/env bash

# 실제 Kakao 계정 수동 E2E용 Android emulator 실행기.
set -euo pipefail

if [[ -z "${KAKAO_NATIVE_APP_KEY:-}" ]]; then
  echo 'KAKAO_NATIVE_APP_KEY is required. Export it in this terminal first.' >&2
  exit 1
fi

api_base_url="${API_BASE_URL:-http://10.0.2.2:8000/api/v1}"
device_id="${FLUTTER_DEVICE_ID:-emulator-5554}"

if ! flutter devices --machine | grep -q "\"id\": \"${device_id}\""; then
  echo "Android emulator '${device_id}' is not connected." >&2
  echo 'Start one with Flutter/Android Studio, or set FLUTTER_DEVICE_ID.' >&2
  exit 1
fi

flutter pub get
flutter run \
  -d "$device_id" \
  --dart-define="KAKAO_NATIVE_APP_KEY=${KAKAO_NATIVE_APP_KEY}" \
  --dart-define="API_BASE_URL=${api_base_url}"
