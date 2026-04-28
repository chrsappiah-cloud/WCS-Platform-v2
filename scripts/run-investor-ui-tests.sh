#!/usr/bin/env bash
# Run focused tests for investor-demo UI (captions, watch progress, Discover trust cluster, video policy).
# Usage:
#   ./scripts/run-investor-ui-tests.sh
#   ./scripts/run-investor-ui-tests.sh 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID'
#
# List simulators: xcodebuild -showdestinations -scheme WCS-Platform -project WCS-Platform/WCS-Platform.xcodeproj

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/WCS-Platform/WCS-Platform.xcodeproj"
DEST="${1:-platform=iOS Simulator,name=WCS iPhone}"

# Swift Testing identifiers: Target/Suite/testName() — quote so () is not parsed by the shell.
exec xcodebuild test \
  -project "$PROJECT" \
  -scheme WCS-Platform \
  -destination "$DEST" \
  '-only-testing:WCS-PlatformTests/WCS_PlatformTests/webVTTParser_findsActiveCue()' \
  '-only-testing:WCS-PlatformTests/WCS_PlatformTests/mockLearning_watchProgressSurfacesOnHydratedLesson()' \
  '-only-testing:WCS-PlatformTests/WCS_PlatformTests/homeDiscover_trustCluster_contentContract()' \
  '-only-testing:WCS-PlatformTests/WCS_PlatformTests/homeDiscover_trustCluster_linkedInStoriesURL_isAllowlisted()' \
  '-only-testing:WCS-PlatformTests/WCS_PlatformTests/lessonVideoPlaybackPolicy_detectsAppleSampleHLS()' \
  '-only-testing:WCS-PlatformTests/WCS_PlatformTests/lessonVideoPlaybackPolicy_nearestUdemyStyleRate()' \
  '-only-testing:WCS-PlatformTests/WCS_PlatformTests/mockCatalog_sampleVideoLessonsPreferHLSMaster()'
