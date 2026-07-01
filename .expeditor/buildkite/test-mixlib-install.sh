#!/bin/bash
# Test omnitruck with a specific mixlib-install version or branch
set -euo pipefail

MIXLIB_VERSION="${MIXLIB_INSTALL_VERSION:-}"
MIXLIB_BRANCH="${MIXLIB_INSTALL_BRANCH:-}"

echo "=========================================="
echo "Testing with mixlib-install configuration"
echo "=========================================="

if [ -n "$MIXLIB_BRANCH" ]; then
    echo "Installing mixlib-install from branch: $MIXLIB_BRANCH"
    # Update Gemfile to use the branch
    sed -i.bak "s|gem 'mixlib-install'.*|gem 'mixlib-install', git: 'https://github.com/chef/mixlib-install.git', branch: '$MIXLIB_BRANCH'|" Gemfile
    rm Gemfile.bak
elif [ -n "$MIXLIB_VERSION" ]; then
    echo "Installing mixlib-install version: $MIXLIB_VERSION"
    sed -i.bak "s|gem 'mixlib-install'.*|gem 'mixlib-install', '= $MIXLIB_VERSION'|" Gemfile
    rm Gemfile.bak
else
    echo "Using mixlib-install version from Gemfile"
fi

# Show what we're testing with
echo ""
echo "Gemfile configuration:"
grep mixlib-install Gemfile

# Install and verify
bundle install --jobs=4
echo ""
echo "Installed mixlib-install version:"
bundle exec ruby -e "require 'mixlib/install/version'; puts Mixlib::Install::VERSION"

echo ""
echo "✅ Ready to test with configured mixlib-install version"
