#!/bin/sh
set -euo pipefail

echo "ci_pre_xcodebuild: configuring build number"

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER is not set; skipping build number update."
  exit 0
fi

echo "Using CI_BUILD_NUMBER=${CI_BUILD_NUMBER}"

# Update CURRENT_PROJECT_VERSION in the Xcode project so every cloud build has
# a unique CFBundleVersion for App Store Connect/TestFlight uploads.
xcrun agvtool new-version -all "${CI_BUILD_NUMBER}"
