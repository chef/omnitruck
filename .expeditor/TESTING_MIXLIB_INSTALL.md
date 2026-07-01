# Testing mixlib-install with Omnitruck

## Overview

Omnitruck depends on `mixlib-install` gem to generate install scripts. Compatibility tests run automatically on every PR.

## Automated Tests

**File:** `spec/mixlib_install_integration_spec.rb` (4 tests)

Tests verify:
- mixlib-install version >= 3.17.0
- Bash script generation
- PowerShell script generation  
- `-f` flag support for custom filenames

**Run locally:**
```bash
bundle exec rspec spec/mixlib_install_integration_spec.rb
```

## CI Pipeline

Two stages run on every commit:

**Stage 1: Unit Tests** (~1-2 min)
- All 137 tests (133 original + 4 mixlib-install)
- Fast, no Redis required

**Stage 2: Integration Tests** (~3-5 min)  
- All 137 tests with Redis cache
- Runs poller to populate data

## Testing mixlib-install Changes

To test a mixlib-install PR before release:

1. **Update Gemfile:**
   ```ruby
   gem 'mixlib-install', git: 'https://github.com/chef/mixlib-install.git', branch: 'your-branch'
   ```

2. **Test locally:**
   ```bash
   bundle install
   bundle exec rspec
   ```

3. **Push to CI:**
   ```bash
   git add Gemfile Gemfile.lock
   git commit -s -m "Test with mixlib-install branch"
   git push
   ```

CI automatically tests your mixlib-install changes.

## Updating mixlib-install Version

When a new version is released:

1. Update `Gemfile`:
   ```ruby
   gem 'mixlib-install', '>= 3.17.2'
   ```

2. Test and commit:
   ```bash
   bundle update mixlib-install
   bundle exec rspec
   git commit -am "Update mixlib-install to 3.17.2"
   ```

## What Gets Tested

- ✅ Install script generation works
- ✅ -f flag for custom filenames
- ✅ Bash and PowerShell scripts
- ✅ mixlib-install version >= 3.17.0

These tests catch issues when:
- Omnitruck code affects script generation
- mixlib-install gem version changes
- New features are added
