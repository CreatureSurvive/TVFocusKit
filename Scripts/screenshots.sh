#!/bin/sh
# Regenerates the README screenshots in Screenshots/ from the example app's UI tests.
set -eu
cd "$(dirname "$0")/../Example"
xcodegen generate --quiet
result=$(mktemp -d)/screenshots.xcresult
xcodebuild test -project TVFocusDemo.xcodeproj -scheme TVFocusDemo \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p)" \
  -only-testing:TVFocusDemoUITests/ScreenshotTests -resultBundlePath "$result" -quiet
../Scripts/export-screenshots.sh "$result" ../Screenshots
