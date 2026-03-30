#!/bin/sh
set -euo pipefail

echo "ci_pre_xcodebuild: configuring build number"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER is not set; skipping build number update."
  exit 0
fi

echo "Using CI_BUILD_NUMBER=${CI_BUILD_NUMBER}"

PROJECT_PATH=""
for candidate in ./*.xcodeproj; do
  if [ -d "${candidate}" ]; then
    PROJECT_PATH="${candidate#./}"
    break
  fi
done
if [ -z "${PROJECT_PATH}" ]; then
  echo "No .xcodeproj found at repo root: ${REPO_ROOT}"
  exit 1
fi

PROJECT_FILE="${PROJECT_PATH}/project.pbxproj"
if [ ! -f "${PROJECT_FILE}" ]; then
  echo "Project file not found: ${PROJECT_FILE}"
  exit 1
fi

# Update CURRENT_PROJECT_VERSION so every cloud build has a unique
# CFBundleVersion for App Store Connect/TestFlight uploads.
/usr/bin/perl -0pi -e "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" "${PROJECT_FILE}"

if ! /usr/bin/grep -q "CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};" "${PROJECT_FILE}"; then
  echo "Failed to update CURRENT_PROJECT_VERSION in ${PROJECT_FILE}"
  exit 1
fi

echo "Updated CURRENT_PROJECT_VERSION to ${CI_BUILD_NUMBER}"
