#!/bin/bash
cd $APP_ROOT
echo "Setting up bundler environment..."

# Create local bundle config
mkdir -p .bundle
cat > .bundle/config << EOF
---
BUNDLE_PATH: "vendor/bundle"
BUNDLE_DEPLOYMENT: "false"
BUNDLE_WITHOUT: ""
BUNDLE_SYSTEM: "false"
BUNDLE_FROZEN: "false"
BUNDLE_CACHE_ALL: "false"
BUNDLE_DISABLE_SHARED_GEMS: "true"
EOF

# Setup Git for HTTPS
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"

# Prepare vendor directory
mkdir -p vendor/bundle

echo "Installing dependencies..."
bundle config set --local path 'vendor/bundle'
bundle install --jobs=4

echo "Starting application..."
exec "$@"