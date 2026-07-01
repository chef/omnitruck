# Testing mixlib-install Changes with Omnitruck CI

This document explains how to test mixlib-install changes in the omnitruck CI/CD pipeline.

## Overview

Omnitruck depends on `mixlib-install` gem to generate install scripts. When changes are made to mixlib-install, they need to be tested with omnitruck before releasing.

## Testing Approaches

### 1. Automated Regression Tests

**Location:** `spec/mixlib_install_integration_spec.rb`

These tests automatically run in CI and verify:
- Install script generation with various parameter combinations
- Filetype extraction (CHEF-35767 regression test)
- `license_id` + `-f` flag compatibility
- Bash and PowerShell script syntax validation
- mixlib-install version compatibility (>= 3.17.0)

**Run locally:**
```bash
bundle exec rspec spec/mixlib_install_integration_spec.rb --format documentation
```

### 2. Test with Specific mixlib-install Version

To test omnitruck with a specific mixlib-install version or branch:

**Option A: Test with a specific released version**
```bash
# Set environment variable
export MIXLIB_INSTALL_VERSION="3.17.2"

# Run the test script
./.expeditor/buildkite/test-mixlib-install.sh

# Run tests
bundle exec rspec --format documentation
```

**Option B: Test with a development branch**
```bash
# Set environment variable
export MIXLIB_INSTALL_BRANCH="CHEF-35767-fix-cmdline-filename-filetype-extraction"

# Run the test script
./.expeditor/buildkite/test-mixlib-install.sh

# Run tests
bundle exec rspec --format documentation
```

### 3. Trigger CI with Custom mixlib-install Version

The CI pipeline includes an optional stage that tests with custom mixlib-install versions.

**Trigger via Buildkite:**

1. Go to the Buildkite build
2. Click "New Build"
3. Add environment variables:
   - `MIXLIB_INSTALL_VERSION=3.17.2` (for released versions)
   - OR `MIXLIB_INSTALL_BRANCH=your-branch-name` (for development branches)

This will trigger the "Test with Custom mixlib-install" stage.

**Trigger via Expeditor:**

In your PR description or commit message, add:
```
expeditor:buildkite:
  MIXLIB_INSTALL_BRANCH: CHEF-35767-fix-cmdline-filename-filetype-extraction
```

## CI Pipeline Stages

### Stage 1: Unit Tests
- Fast tests without Redis
- ~1-2 minutes
- Runs on every commit

### Stage 2: Integration Tests with Redis
- Full test suite (133 tests)
- Includes poller cache population
- Uses default mixlib-install version from Gemfile
- ~3-5 minutes

### Stage 3: Custom mixlib-install Testing (Optional)
- Only runs when `MIXLIB_INSTALL_VERSION` or `MIXLIB_INSTALL_BRANCH` is set
- Installs custom mixlib-install version
- Runs full test suite with custom version
- ~3-5 minutes

## Testing Workflow for mixlib-install Changes

### Scenario 1: Testing a mixlib-install PR

1. **Create your mixlib-install PR** with changes
2. **Note the branch name** (e.g., `CHEF-35767-fix-cmdline-filename-filetype-extraction`)
3. **Test locally in omnitruck:**
   ```bash
   cd /path/to/omnitruck
   export MIXLIB_INSTALL_BRANCH="your-branch-name"
   ./.expeditor/buildkite/test-mixlib-install.sh
   bundle exec rspec --format documentation
   ```
4. **If tests pass locally**, trigger CI with custom version:
   - Go to omnitruck Buildkite
   - New Build with `MIXLIB_INSTALL_BRANCH=your-branch-name`
5. **If CI passes**, your mixlib-install PR is safe to merge

### Scenario 2: Verifying a mixlib-install Release

1. **After mixlib-install is released** (e.g., v3.17.2)
2. **Test with new version:**
   ```bash
   export MIXLIB_INSTALL_VERSION="3.17.2"
   ./.expeditor/buildkite/test-mixlib-install.sh
   bundle exec rspec --format documentation
   ```
3. **If tests pass**, update omnitruck's Gemfile:
   ```ruby
   gem 'mixlib-install', '>= 3.17.2'
   ```
4. **Commit and push** - CI will test automatically

### Scenario 3: Adding Tests for New mixlib-install Features

When adding new features to mixlib-install that omnitruck will use:

1. **Add tests to** `spec/mixlib_install_integration_spec.rb`
2. **Run tests locally** to ensure they fail without changes
3. **Test with your mixlib-install branch** (see Scenario 1)
4. **Verify tests pass** with your changes
5. **Commit tests to omnitruck** first
6. **Merge mixlib-install PR** after omnitruck tests are in place

## Known Issues Tested

### CHEF-35767: Filetype Extraction Bug
**Problem:** When using `-f chef-workstation.deb` with `license_id`, filetype was set to empty string, causing "invalid Filetype" error.

**Test:** `spec/mixlib_install_integration_spec.rb` includes regression tests for this issue.

**Verification:**
```bash
# Generate script with license_id
curl "http://localhost:9393/install.sh?license_id=test-123" > /tmp/test-install.sh

# Check that filetype extraction is correct
grep -A5 "cmdline_filename" /tmp/test-install.sh

# Should NOT contain: filetype=""
# Should contain: filetype extraction logic with validation
```

## Files

- `.expeditor/buildkite/test-mixlib-install.sh` - Script to install custom mixlib-install version
- `spec/mixlib_install_integration_spec.rb` - Integration and regression tests
- `.expeditor/verify.pipeline.yml` - CI pipeline configuration with optional custom version stage

## Questions?

Contact the Chef Infra team or see [ADR/readme.md](../ADR/readme.md) for architecture decisions.
