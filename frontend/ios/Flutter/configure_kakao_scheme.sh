#!/bin/sh
set -eu

kakao_native_app_key=""
old_ifs="$IFS"
IFS=","
for encoded_define in ${DART_DEFINES:-}; do
  decoded_define="$(printf '%s' "$encoded_define" | openssl base64 -d -A 2>/dev/null || true)"
  case "$decoded_define" in
    KAKAO_NATIVE_APP_KEY=*)
      kakao_native_app_key="${decoded_define#KAKAO_NATIVE_APP_KEY=}"
      ;;
  esac
done
IFS="$old_ifs"

if [ -z "$kakao_native_app_key" ]; then
  if [ "${CONFIGURATION:-Debug}" = "Debug" ]; then
    exit 0
  fi
  echo "error: KAKAO_NATIVE_APP_KEY is required for ${CONFIGURATION} builds." >&2
  exit 1
fi

built_info_plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 kakao${kakao_native_app_key}" \
  "$built_info_plist"
