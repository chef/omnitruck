#!/bin/bash

set -eou pipefail

TARGET_CHANNEL="${EXPEDITOR_TARGET_CHANNEL:-acceptance}"

# Get the Fastly service identifiers from the dashboard and paste them here.
if [ "$TARGET_CHANNEL" == "acceptance" ]; then
  FASTLY_SERVICE="3yB7EKyX9OJbc53RVk3tZ8"
elif [ "$TARGET_CHANNEL" == "stable" ]; then
  FASTLY_SERVICE="27pKDzl9ahMdwMsYKFaGE"
else
  echo "We do not currently support purging CDN for $TARGET_CHANNEL"
  exit 1
fi

if [[ ${FASTLY_SERVICE+x} != "x" ]]; then
  echo "Purging Fastly Service $FASTLY_SERVICE"
  curl -X POST -H "Fastly-Key: $FASTLY_API_TOKEN" "https://api.fastly.com/service/$FASTLY_SERVICE/purge_all"
else
  echo "WARN: Fastly Service not set in $0!"
  exit 1
fi
