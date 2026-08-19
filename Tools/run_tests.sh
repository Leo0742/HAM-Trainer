#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
SDK_PATH="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
CACHE_DIR="$PROJECT_DIR/.build/manual-tests"
mkdir -p "$CACHE_DIR/module-cache"
swiftc \
  -sdk "$SDK_PATH" \
  -target "$(uname -m)-apple-macosx14.0" \
  -module-cache-path "$CACHE_DIR/module-cache" \
  "$PROJECT_DIR/HAMTrainer/Models.swift" \
  "$PROJECT_DIR/HAMTrainer/AdaptiveReviewScheduler.swift" \
  "$PROJECT_DIR/HAMTrainer/AppStore.swift" \
  "$PROJECT_DIR/Tests/RunTests.swift" \
  -o "$CACHE_DIR/HAMTrainerCoreTests"
"$CACHE_DIR/HAMTrainerCoreTests" "$PROJECT_DIR/Content"
python3 "$PROJECT_DIR/Tools/validate_content.py"
