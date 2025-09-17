# GitHub Copilot Instructions for Omnitruck

This is a comprehensive guide for GitHub Copilot when working with the Omnitruck repository. Omnitruck is a Sinatra-based web service that provides an API to download and install Chef Software omnibus artifacts across multiple platforms and architectures.

## Table of Contents

1. [Repository Structure & Purpose](#repository-structure--purpose)
2. [Technology Stack & Dependencies](#technology-stack--dependencies)
3. [Development Workflow Integration](#development-workflow-integration)
4. [Testing Requirements (CRITICAL)](#testing-requirements-critical)
5. [DCO (Developer Certificate of Origin) Compliance](#dco-developer-certificate-of-origin-compliance)
6. [Build System Integration](#build-system-integration)
7. [Pull Request Creation Process](#pull-request-creation-process)
8. [Code Quality & Standards](#code-quality--standards)
9. [Security & Compliance](#security--compliance)
10. [Local Development Environment](#local-development-environment)
11. [Prompt-Based Execution Protocol](#prompt-based-execution-protocol)
12. [Example Workflow Execution](#example-workflow-execution)
13. [Label Management & Expeditor Integration](#label-management--expeditor-integration)
14. [Code Ownership & Review Process](#code-ownership--review-process)
15. [Important Development Notes](#important-development-notes)
16. [Troubleshooting](#troubleshooting)

## Repository Structure & Purpose

### Project Overview
Omnitruck is Chef Software's distribution service that provides:
- REST API endpoints for downloading Chef Software packages
- Install scripts for automated Chef package installation
- Metadata API for package information (versions, checksums, URLs)
- Support for multiple channels (stable, current, unstable)
- Cross-platform support for all Chef Software products

### Repository Structure Diagram
```
omnitruck/
├── app.rb                        # Main Sinatra application (CRITICAL - Core API logic)
├── platforms.rb                  # Platform definitions and mappings (SAFE TO MODIFY)
├── poller                        # Background polling service (SAFE TO MODIFY)
├── config.ru                     # Rack configuration (SAFE TO MODIFY)
├── Gemfile                       # Ruby dependencies (SAFE TO MODIFY)
├── Gemfile.lock                  # Locked dependency versions (AUTO-GENERATED - DO NOT EDIT)
├── Rakefile                      # Build tasks (SAFE TO MODIFY)
├── Makefile                      # Docker/K8s dev tasks (SAFE TO MODIFY)
├── Dockerfile                    # Container definition (SAFE TO MODIFY)
├── skaffold.yaml                 # K8s development (SAFE TO MODIFY)
├── dobi.yaml                     # Build automation (SAFE TO MODIFY)
├── values.yaml                   # Helm values (SAFE TO MODIFY)
├── VERSION                       # Version file (AUTO-GENERATED - DO NOT EDIT)
├── CHANGELOG.md                  # Release notes (AUTO-GENERATED - DO NOT EDIT)
├── .expeditor/                   # Build automation (CRITICAL - Expeditor config)
│   ├── config.yml               # Main Expeditor configuration
│   ├── verify.pipeline.yml      # CI pipeline definition
│   ├── build.docker.yml         # Docker build pipeline
│   ├── update_version.sh        # Version update script
│   └── buildkite/               # Build scripts
├── .github/                      # GitHub configuration
│   ├── CODEOWNERS               # Code review assignments
│   └── dependabot.yml           # Dependency updates
├── charts/omnitruck/             # Helm chart (SAFE TO MODIFY)
├── config/                       # Application configuration
│   ├── config.yml               # Main config (SAFE TO MODIFY)
│   └── config.yml.example       # Example config
├── habitat/                      # Habitat packaging (SAFE TO MODIFY)
│   ├── plan.sh                  # Habitat build plan
│   ├── default.toml             # Default configuration
│   └── config/                  # Habitat config files
├── lib/                          # Core application libraries (CRITICAL)
│   ├── dist.rb                  # Distribution logic
│   ├── platform_dsl.rb          # Platform DSL
│   └── chef/                    # Chef-specific modules
│       ├── cache.rb             # Redis caching layer
│       ├── project_manifest.rb  # Manifest generation
│       ├── version_resolver.rb  # Version resolution logic
│       ├── version.rb           # Version handling
│       └── version/
├── spec/                         # Test suite (CRITICAL FOR ALL CHANGES)
│   ├── app_spec.rb              # Main application tests
│   ├── spec_helper.rb           # Test configuration
│   ├── chef/                    # Library tests
│   └── data/                    # Test fixtures (DO NOT MODIFY - Use rake refresh_data)
└── views/                        # ERB templates (SAFE TO MODIFY)
    └── layout.erb               # Main layout template
```

### File Modification Guidelines

**SAFE TO MODIFY:**
- Application code: `app.rb`, `platforms.rb`, `poller`
- Configuration: `config/config.yml`, Helm charts, Docker files
- Documentation: README, this file, comments
- Tests: All files in `spec/` except test data fixtures
- Build scripts: Makefile, Rakefile (with caution)

**PROHIBITED TO MODIFY:**
- `Gemfile.lock` (managed by Bundler)
- `VERSION` (managed by Expeditor)
- `CHANGELOG.md` (auto-generated by Expeditor)
- Test fixtures in `spec/data/` (use `rake refresh_data` instead)

**MODIFY WITH EXTREME CAUTION:**
- `.expeditor/config.yml` (changes affect build/release pipeline)
- Core library files in `lib/chef/` (require extensive testing)

## Technology Stack & Dependencies

### Primary Technologies
- **Ruby**: 2.7+ (Alpine Linux container)
- **Framework**: Sinatra 1.4.x (lightweight web framework)
- **Database**: Redis (caching and manifest storage)
- **Containerization**: Docker + Kubernetes
- **Build System**: Habitat packaging + Expeditor automation
- **Testing**: RSpec with Rack::Test

### Key Dependencies
```ruby
# Core Framework
gem 'sinatra', '~> 1.4', '< 2'
gem 'sinatra-contrib'      # Sinatra extensions
gem 'sinatra-cors'         # CORS support
gem 'sinatra-param'        # Parameter validation
gem 'unicorn'              # Application server

# Chef Integration
gem 'mixlib-install'       # Chef package management
gem 'mixlib-versioning'    # Version handling

# Infrastructure
gem 'redis'                # Caching layer
gem 'rest-client'          # HTTP client
gem 'json'                 # JSON processing

# Testing Framework
gem 'rspec'                # BDD testing framework
gem 'rack-test'            # HTTP testing
gem 'rspec-its'            # RSpec extensions
gem 'pry-byebug'           # Debugging
```

### Development Environment Requirements
- **Ruby**: 2.7 or higher
- **Redis**: For caching (local or Docker)
- **Docker**: For containerized development
- **Kubernetes**: For local deployment testing (optional)
- **Make**: For build automation
- **Git**: With DCO signing capability

## Development Workflow Integration

### Jira Integration with MCP Server

When working with Jira tickets, use the atlassian-mcp-server MCP server for seamless integration:

```bash
# Fetch Jira issue details
gh copilot suggest "Fetch details for Jira issue CHEF-1234 using MCP server"

# Implementation planning based on Jira story
gh copilot suggest "Analyze Jira story requirements and create implementation plan"
```

### Workflow Phases

#### Phase 1: Initial Setup & Analysis
**Objective**: Understand requirements and plan implementation

**Steps:**
1. **Jira Analysis**
   ```bash
   # Use MCP server to fetch issue details
   jira-get-issue --issue-key=<JIRA_ID>
   ```

2. **Repository Analysis**
   ```bash
   # Analyze current codebase
   find . -name "*.rb" -type f | head -20
   grep -r "class\|module" lib/ --include="*.rb"
   ```

3. **Implementation Planning**
   - Document proposed changes
   - Identify affected files
   - Plan test strategy
   - Estimate effort

**Approval Gate**: "Phase 1 complete. Ready to proceed with implementation? (y/n)"

#### Phase 2: Implementation Phase
**Objective**: Implement feature or fix based on requirements

**Steps:**
1. **Code Implementation**
   - Follow Ruby/Sinatra best practices
   - Maintain backward compatibility
   - Add appropriate error handling
   - Include logging where appropriate

2. **Documentation Updates**
   - Update inline comments
   - Update README if needed
   - Add API documentation

**Approval Gate**: "Phase 2 complete. Ready to proceed with testing? (y/n)"

#### Phase 3: Testing Phase (CRITICAL)
**Objective**: Ensure >80% test coverage and comprehensive validation

**Steps:**
1. **Unit Test Creation** (MANDATORY)
   ```bash
   # Run existing tests first
   bundle exec rspec spec/

   # Check current coverage (if available)
   bundle exec rspec --format documentation

   # Create comprehensive tests
   # - Positive test cases
   # - Negative test cases  
   # - Edge cases
   # - Error conditions
   # - Mock external dependencies
   ```

2. **Test Coverage Verification** (CRITICAL REQUIREMENT)
   - **MINIMUM 80% COVERAGE REQUIRED**
   - Test both success and failure paths
   - Mock Redis and external API calls
   - Test all new public methods
   - Test error handling and edge cases

3. **Integration Testing**
   ```bash
   # Test specific endpoints
   bundle exec rspec spec/app_spec.rb -t focus

   # Test with different Ruby versions if needed
   rbenv local 2.7.6 && bundle exec rspec
   ```

**Approval Gate**: "Phase 3 complete with >80% test coverage. Ready for PR creation? (y/n)"

#### Phase 4: Pull Request Creation
**Objective**: Create comprehensive PR with proper documentation

**Steps:**
1. **Git Operations** (with DCO compliance)
2. **PR Creation** (using GH CLI)
3. **Documentation** (comprehensive PR description)

**Approval Gate**: "Phase 4 complete. PR created and ready for review? (y/n)"

## Testing Requirements (CRITICAL)

### **🚨 HARD REQUIREMENT: >80% TEST COVERAGE 🚨**

**ALL code changes MUST include comprehensive unit tests with >80% coverage. This is NON-NEGOTIABLE.**

### Testing Framework: RSpec

**File Structure:**
```
spec/
├── spec_helper.rb          # Test configuration
├── app_spec.rb            # Main application tests (>1200 test cases)
└── chef/
    ├── cache_spec.rb      # Cache layer tests
    └── version_spec.rb    # Version handling tests
```

### Test Patterns and Examples

#### 1. Controller/Endpoint Testing
```ruby
# spec/app_spec.rb pattern
describe "GET /stable/chef/metadata" do
  let(:params) do
    {
      p: 'ubuntu',
      pv: '20.04', 
      m: 'x86_64',
      v: '17.10.0'
    }
  end

  context "with valid parameters" do
    it "returns correct metadata" do
      get "/stable/chef/metadata", params
      expect(last_response).to be_ok
      expect(last_response.header['Content-Type']).to include 'application/json'
      
      response = JSON.parse(last_response.body)
      expect(response['url']).to match(/https:\/\//)
      expect(response['sha256']).to match(/^[0-9a-f]{64}$/)
      expect(response['version']).to eq('17.10.0')
    end
  end

  context "with invalid platform" do
    let(:params) { { p: 'invalid_platform' } }
    
    it "returns 404" do
      get "/stable/chef/metadata", params
      expect(last_response).to be_not_found
    end
  end
end
```

#### 2. Service Layer Testing
```ruby
# spec/chef/cache_spec.rb pattern
describe Chef::Cache do
  let(:cache) { Chef::Cache.new }
  let(:redis) { double('Redis') }

  before do
    allow(Redis).to receive(:new).and_return(redis)
  end

  describe "#manifest_for" do
    context "when manifest exists" do
      let(:manifest_data) { { 'version' => '1.0.0' }.to_json }
      
      before do
        allow(redis).to receive(:get).with('stable/chef').and_return(manifest_data)
      end
      
      it "returns parsed manifest" do
        result = cache.manifest_for('chef', 'stable')
        expect(result).to eq({ 'version' => '1.0.0' })
      end
    end

    context "when manifest does not exist" do
      before do
        allow(redis).to receive(:get).with('stable/chef').and_return(nil)
      end
      
      it "raises MissingManifestFile error" do
        expect {
          cache.manifest_for('chef', 'stable')
        }.to raise_error(Chef::Cache::MissingManifestFile)
      end
    end
  end
end
```

#### 3. Testing Commands
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/app_spec.rb

# Run tests with documentation format
bundle exec rspec --format documentation

# Run tests for specific functionality
bundle exec rspec spec/app_spec.rb -t focus

# Run tests with increased verbosity
bundle exec rspec --format progress --backtrace

# Refresh test data fixtures
bundle exec rake refresh_data
```

### Test Coverage Requirements

**CRITICAL REQUIREMENTS:**
- **Minimum 80% line coverage**
- **Test all public methods**
- **Test both success and failure paths**
- **Mock all external dependencies (Redis, HTTP calls)**
- **Test edge cases and error conditions**
- **Ensure tests are independent and can run in any order**

### Test Data Management
```bash
# Refresh test fixtures (when manifest structure changes)
bundle exec rake refresh_data

# This updates files in spec/data/ with current manifest structure
# DO NOT manually edit files in spec/data/
```

## DCO (Developer Certificate of Origin) Compliance

### **🚨 CRITICAL: ALL COMMITS MUST BE SIGNED WITH DCO 🚨**

The project requires DCO signoff for all commits. **Builds will fail without proper DCO signoff.**

### DCO Signing Commands

**All commits MUST use the `--signoff` flag:**

```bash
# Standard commit with DCO signoff
git commit --signoff -m "PROJ-123: Add new API endpoint for package validation"

# Short form
git commit -s -m "PROJ-123: Fix version resolution for SLES platforms"

# Amending previous commit with DCO signoff
git commit --amend --signoff --no-edit

# Interactive rebase to add DCO to multiple commits
git rebase -i HEAD~3 --signoff
```

### DCO Signoff Format
Each commit must include this line at the end:
```
Signed-off-by: Your Name <your.email@example.com>
```

**Example commit message:**
```
PROJ-123: Add comprehensive test coverage for version resolver

- Add unit tests for Chef::VersionResolver class
- Test edge cases for partial version matching
- Mock external API dependencies
- Achieve >85% test coverage

Signed-off-by: Developer Name <dev@chef.io>
```

### Fixing Missing DCO Signoffs

**For the last commit:**
```bash
git commit --amend --signoff --no-edit
```

**For multiple commits:**
```bash
# Interactive rebase with DCO signoff
git rebase -i HEAD~<number> --signoff

# Force push after fixing (if already pushed)
git push --force-with-lease origin <branch-name>
```

## Build System Integration

### Expeditor Configuration

Expeditor manages the build, test, and release pipeline. Key configuration in `.expeditor/config.yml`:

```yaml
# Available skip labels for different change types
ignore_labels:
  - "Expeditor: Skip Version Bump"    # Skip version increment
  - "Expeditor: Skip Changelog"       # Skip changelog generation  
  - "Expeditor: Skip All"            # Skip all Expeditor actions
  - "Expeditor: Skip Docker"         # Skip Docker image build

# Version bump triggers
major_bump_labels:
  - "Expeditor: Bump Version Major"
minor_bump_labels:
  - "Expeditor: Bump Version Minor"
```

### Build Pipelines

**Available Pipelines:**
1. **verify**: Runs tests, linting, security scans
2. **docker/build**: Builds and publishes Docker images

**Pipeline Triggers:**
- **Pull Request Merged**: Triggers version bump, changelog, Docker build
- **Project Promoted**: Promotes Docker images across environments

### Build Commands

```bash
# Local development build
make help                    # Show available targets

# Docker development
make dev.skaffold           # Start local K8s development
make docker.delete-images   # Clean up local Docker images
make docker.deploy-registry # Deploy local Docker registry

# Ruby/Bundler commands
bundle install              # Install dependencies
bundle exec rspec           # Run test suite
bundle exec rake refresh_data # Update test fixtures
bundle exec unicorn         # Start application server
```

### Habitat Packaging

Omnitruck includes Habitat packaging configuration:

```bash
# Habitat build (if needed)
hab studio enter
build

# Habitat configuration
habitat/plan.sh             # Build plan
habitat/default.toml         # Default configuration
habitat/config/             # Runtime configuration
```

## Pull Request Creation Process

### Branch Naming Convention
**Use Jira ID as branch name:**
```bash
git checkout -b CHEF-1234
git checkout -b INFRA-5678
git checkout -b SEC-9999
```

### Complete Git Workflow with DCO

```bash
# 1. Create and checkout feature branch
git checkout -b <JIRA_ID>

# 2. Make your changes and commit with DCO signoff
git add .
git commit --signoff -m "<JIRA_ID>: Brief description of changes

Detailed description of what was implemented:
- Specific change 1
- Specific change 2
- Test coverage details

Signed-off-by: Your Name <your.email@example.com>"

# 3. Push to remote repository
git push origin <JIRA_ID>

# 4. Create pull request using GitHub CLI
gh pr create \
  --title "<JIRA_ID>: Brief description" \
  --body-file pr_description.md \
  --label "type/enhancement" \
  --label "team/infrastructure"

# 5. Link to Jira (if not using MCP integration)
gh pr edit <PR_NUMBER> --body "$(cat pr_description.md)

**Jira Ticket**: [<JIRA_ID>](https://chef-software.atlassian.net/browse/<JIRA_ID>)"
```

### PR Description Template (HTML Format)

Create `pr_description.md`:
```html
<h2>Summary</h2>
<p>Brief description of changes made for <strong><JIRA_ID></strong>.</p>

<h2>Jira Ticket</h2>
<p><a href="https://chef-software.atlassian.net/browse/<JIRA_ID>"><JIRA_ID></a></p>

<h2>Changes Made</h2>
<ul>
  <li><strong>Feature/Fix</strong>: Specific implementation details</li>
  <li><strong>Testing</strong>: Comprehensive test coverage added (>80%)</li>
  <li><strong>Documentation</strong>: Updated relevant documentation</li>
</ul>

<h2>Testing Performed</h2>
<ul>
  <li>✅ Unit tests created with >80% coverage</li>
  <li>✅ All existing tests pass</li>
  <li>✅ Integration tests for new endpoints</li>
  <li>✅ Error handling and edge case testing</li>
</ul>

<h2>Files Modified</h2>
<ul>
  <li><code>app.rb</code> - Core API logic updates</li>
  <li><code>spec/app_spec.rb</code> - Comprehensive test coverage</li>
  <li><code>lib/chef/cache.rb</code> - Caching improvements</li>
</ul>

<h2>Deployment Notes</h2>
<ul>
  <li>No breaking changes</li>
  <li>Backward compatible API changes</li>
  <li>No database migrations required</li>
</ul>
```

### Label Selection Guidelines

**Based on change type, use appropriate labels:**

**For Documentation Changes:**
```bash
gh pr create --label "Expeditor: Skip All" --label "type/docs"
```

**For Feature Changes:**
```bash
gh pr create --label "type/enhancement" --label "team/infrastructure"
```

**For Bug Fixes:**
```bash
gh pr create --label "type/bug" --label "priority/medium"
```

**For Test-only Changes:**
```bash
gh pr create --label "Expeditor: Skip Version Bump" --label "type/test"
```

### Repository-Specific Labels

Since GH CLI authentication is not available, use these common labels based on Chef Software standards:

**Type Labels:**
- `type/enhancement` - New features
- `type/bug` - Bug fixes  
- `type/docs` - Documentation changes
- `type/test` - Test improvements
- `type/maintenance` - Maintenance tasks

**Priority Labels:**
- `priority/critical` - Critical issues
- `priority/high` - High priority
- `priority/medium` - Medium priority
- `priority/low` - Low priority

**Team Labels:**
- `team/infrastructure` - Infrastructure team changes
- `team/packages` - Package management team

**Expeditor Labels:**
- `Expeditor: Skip All` - Skip all automation
- `Expeditor: Skip Version Bump` - Skip version increment
- `Expeditor: Skip Changelog` - Skip changelog generation
- `Expeditor: Skip Docker` - Skip Docker builds

## Code Quality & Standards

### Ruby Style Guidelines

**Follow standard Ruby conventions:**

```ruby
# Class naming - PascalCase
class VersionResolver
  # Constants - SCREAMING_SNAKE_CASE
  KNOWN_PROJECTS = %w(chef chef-server chefdk).freeze
  
  # Methods - snake_case
  def resolve_version(project, channel, version = nil)
    # Local variables - snake_case
    resolved_version = find_latest_version(project, channel)
    
    # Use explicit returns for clarity
    return resolved_version if version.nil?
    
    # Handle specific version requests
    find_specific_version(project, channel, version)
  end
  
  private
  
  # Private methods clearly marked
  def find_latest_version(project, channel)
    # Implementation
  end
end
```

**Error Handling:**
```ruby
# Use specific exception classes
class Chef::Cache::MissingManifestFile < StandardError; end

# Proper error handling with context
def manifest_for(project, channel)
  content = @redis.get("#{channel}/#{project}")
  if content.nil?
    raise MissingManifestFile, 
      "Can not find the manifest for '#{project}' - '#{channel}'"
  end
  
  JSON.parse(content)
rescue JSON::ParserError => e
  raise MissingManifestFile, 
    "Invalid JSON in manifest for '#{project}' - '#{channel}': #{e.message}"
end
```

### Sinatra API Patterns

**Follow established patterns in `app.rb`:**

```ruby
# Parameter validation using sinatra-param
get '/:channel/:project/metadata' do
  param :channel, String, required: true, in: %w(stable current unstable)
  param :project, String, required: true
  param :v, String  # version - optional
  param :p, String  # platform - optional  
  param :pv, String # platform_version - optional
  param :m, String  # architecture - optional
  
  # Validation logic
  platform_info = validate_platform_params(params)
  
  # Business logic
  metadata = resolve_package_metadata(platform_info)
  
  # Response formatting
  content_type :json
  metadata.to_json
end

# Error handling
error 404 do
  content_type :json
  { error: 'Package not found' }.to_json
end
```

### Code Documentation

**Include comprehensive documentation:**

```ruby
#
# Resolves package versions based on platform and version constraints
#
# @param [String] project The Chef Software product name
# @param [String] channel The release channel (stable, current, unstable)
# @param [String] version Optional version constraint (can be partial)
# @param [Hash] platform_info Platform details (platform, version, architecture)
#
# @return [Hash] Package metadata including URL, checksums, and resolved version
#
# @raise [Chef::Cache::MissingManifestFile] when manifest is not found
# @raise [ArgumentError] when parameters are invalid
#
def resolve_package_metadata(project, channel, version, platform_info)
  # Implementation with detailed comments for complex logic
end
```

### Security Standards

**Input Validation:**
```ruby
# Sanitize and validate all user inputs
def validate_platform_params(params)
  platform = params[:p]&.downcase&.strip
  version = params[:pv]&.strip
  arch = params[:m]&.downcase&.strip
  
  # Whitelist validation
  unless SUPPORTED_PLATFORMS.include?(platform)
    halt 404, { error: 'Unsupported platform' }.to_json
  end
  
  # Pattern validation for version
  if version && !version.match?(/\A\d+(\.\d+)*\z/)
    halt 400, { error: 'Invalid version format' }.to_json
  end
  
  { platform: platform, version: version, architecture: arch }
end
```

## Security & Compliance

### License Compliance

**All files must include Apache 2.0 license header:**
```ruby
#
# Copyright:: Copyright (c) 2017-2025 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
```

### Security Best Practices

**Input Sanitization:**
- Validate all user inputs against whitelists
- Use parameterized queries for any database operations
- Sanitize output to prevent XSS attacks
- Implement rate limiting for API endpoints

**Dependency Management:**
- Keep all gems up to date (Dependabot handles this)
- Review security advisories for dependencies
- Use `bundle audit` to check for vulnerabilities

**Container Security:**
- Run as non-root user (releng:22430)
- Minimal Alpine Linux base image
- No unnecessary packages in container

### CVE Awareness

**When security vulnerabilities are discovered:**
1. Assess impact on Omnitruck functionality
2. Update dependencies immediately if affected
3. Test thoroughly after updates
4. Document any breaking changes
5. Coordinate with security team for disclosure

## Local Development Environment

### Prerequisites Installation

```bash
# Install Ruby (using rbenv recommended)
rbenv install 2.7.6
rbenv local 2.7.6

# Install dependencies
gem install bundler
bundle install

# Install Redis (macOS)
brew install redis
brew services start redis

# Verify Redis connection
redis-cli ping  # Should return PONG
```

### Environment Configuration

**Create local config file:**
```bash
cp config/config.yml.example config/config.yml
```

**Edit `config/config.yml`:**
```yaml
development:
  virtual_path: ''
  redis_url: 'redis://localhost:6379'
```

**Set environment variables:**
```bash
export OMNITRUCK_YAML="./config/config.yml"
export REDIS_URL="redis://localhost:6379"
export RACK_ENV="development"
```

### Running the Application

```bash
# Start Redis (if not running)
redis-server

# Start the application
bundle exec rackup config.ru -p 8080

# Or using unicorn
bundle exec unicorn -p 8080

# Test basic functionality
curl http://localhost:8080/_status
curl "http://localhost:8080/stable/chef/metadata?p=ubuntu&pv=20.04&m=x86_64"
```

### Docker Development

```bash
# Build local Docker image
docker build -t omnitruck:local .

# Run with Redis dependency
docker run -d --name redis redis:alpine
docker run -p 8080:8080 --link redis:redis \
  -e REDIS_URL="redis://redis:6379" \
  omnitruck:local

# Using Docker Compose (create docker-compose.yml)
cat > docker-compose.yml << EOF
version: '3'
services:
  redis:
    image: redis:alpine
  web:
    build: .
    ports:
      - "8080:8080"
    environment:
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
EOF

docker-compose up
```

### Kubernetes Development

```bash
# Install Skaffold and kubectl
# Configure local Kubernetes (Docker Desktop or minikube)

# Start development environment
make dev.skaffold

# This will:
# - Build Docker image
# - Deploy to local Kubernetes
# - Set up port forwarding
# - Watch for file changes and redeploy
```

### Development Tools

**Useful commands:**
```bash
# Interactive debugging
bundle exec pry
require './app.rb'

# Code style checking (if Chefstyle is added)
bundle exec chefstyle

# Dependency vulnerability checking
bundle audit

# Update test fixtures
bundle exec rake refresh_data

# Run specific tests
bundle exec rspec spec/app_spec.rb:100  # Run specific line
bundle exec rspec -t focus              # Run focused tests
```

## Prompt-Based Execution Protocol

### Protocol Overview

All development tasks must follow a prompt-based approach with clear approval gates and progress tracking.

### Interaction Pattern

**Step Format:**
1. **Announce next step**: Clearly state what will be done
2. **Execute step**: Perform the work
3. **Summarize completion**: Describe what was accomplished
4. **Request approval**: Ask for permission to continue
5. **List remaining steps**: Show what's left to do

### Example Interaction Flow

```
🤖 Copilot: I'm ready to implement the new API endpoint for CHEF-1234. Here's my plan:

Phase 1: Analysis & Planning
Phase 2: Implementation
Phase 3: Testing (>80% coverage)
Phase 4: PR Creation

Starting Phase 1: I'll analyze the Jira ticket and plan the implementation.

[Performs analysis]

✅ Phase 1 Complete:
- Analyzed Jira requirements for new /health endpoint
- Identified files to modify: app.rb, spec/app_spec.rb
- Planned test coverage strategy
- No breaking changes required

📋 Remaining Steps:
- Phase 2: Implementation
- Phase 3: Testing (CRITICAL - >80% coverage)
- Phase 4: PR Creation

❓ Ready to proceed with Phase 2 (Implementation)? (y/n)

👤 User: y

🤖 Copilot: Starting Phase 2: Implementation

[Implements the feature]

✅ Phase 2 Complete:
- Added GET /_health endpoint to app.rb
- Implemented Redis connectivity check
- Added proper error handling
- Updated route documentation

📋 Remaining Steps:
- Phase 3: Testing (CRITICAL - >80% coverage)
- Phase 4: PR Creation

❓ Ready to proceed with Phase 3 (Testing)? This will include comprehensive unit tests to achieve >80% coverage. (y/n)
```

### Approval Gates

**Required approval points:**
1. **After Analysis**: Confirm implementation plan
2. **After Implementation**: Verify code changes before testing
3. **After Testing**: Confirm test coverage >80% before PR
4. **Before PR Creation**: Final review of all changes

### Progress Tracking

**Always include in responses:**
- ✅ **Completed**: What was just finished
- 🔄 **Current**: What is being worked on now
- 📋 **Remaining**: What steps are left
- ❓ **Next**: What needs approval to continue

### Error Handling in Protocol

**When errors occur:**
```
🚨 Error encountered in Phase 2: 
- Test failure in version_resolver_spec.rb
- Missing mock for Redis connection

🔧 Resolution steps:
1. Add Redis mock to spec_helper.rb
2. Update failing tests with proper expectations
3. Verify all tests pass

❓ Should I proceed with error resolution? (y/n)
```

### Timeout Handling

**If user doesn't respond within reasonable time:**
```
⏰ Waiting for approval to continue...

Current status:
✅ Phase 1: Analysis Complete
✅ Phase 2: Implementation Complete  
🔄 Phase 3: Ready to start testing

❓ Should I proceed with Phase 3 (Testing)? Type 'y' to continue, 'n' to stop, or 'status' for current progress.
```

## Example Workflow Execution

### Complete Example: Adding New API Endpoint

**Scenario**: Add `/health` endpoint for monitoring (INFRA-5678)

#### Phase 1: Analysis
```
🤖 Starting Phase 1: Analysis for INFRA-5678

[Analyzes Jira ticket via MCP]
[Reviews current codebase]
[Plans implementation]

✅ Phase 1 Complete:
- Jira ticket requires health check endpoint
- Endpoint should check Redis connectivity
- Return JSON status response
- Files to modify: app.rb, spec/app_spec.rb
- Estimated effort: 2 hours

📋 Remaining: Implementation, Testing, PR Creation
❓ Proceed with Phase 2? (y/n)
```

#### Phase 2: Implementation
```
🤖 Starting Phase 2: Implementation

[Adds endpoint to app.rb]
[Updates documentation]

✅ Phase 2 Complete:
- Added GET /_health endpoint
- Returns Redis status and application status
- Proper error handling for Redis failures
- Updated inline documentation

📋 Remaining: Testing (CRITICAL), PR Creation
❓ Proceed with Phase 3 (Testing)? (y/n)
```

#### Phase 3: Testing
```
🤖 Starting Phase 3: Testing (>80% coverage requirement)

[Creates comprehensive tests]
[Runs test suite]
[Verifies coverage]

✅ Phase 3 Complete:
- Added 12 test cases for /_health endpoint
- Tests cover success, Redis failure, and edge cases
- Mocked Redis dependencies properly
- Achieved 87% test coverage (exceeds 80% requirement)
- All existing tests still pass

Test Results:
- 156 tests passed, 0 failures
- Coverage: 87% (target: >80% ✅)

📋 Remaining: PR Creation
❓ Proceed with Phase 4 (PR Creation)? (y/n)
```

#### Phase 4: PR Creation
```
🤖 Starting Phase 4: PR Creation with DCO compliance

[Creates branch]
[Commits with DCO signoff]
[Creates PR]

✅ Phase 4 Complete:
- Created branch: INFRA-5678
- Committed with DCO signoff
- Created PR #123 with comprehensive description
- Applied labels: type/enhancement, team/infrastructure
- Linked to Jira ticket

PR Details:
- Title: "INFRA-5678: Add health check endpoint for monitoring"
- Description includes all changes and test coverage
- Ready for review by @chef/infra-packages team

🎉 Workflow complete! PR is ready for review.
```

### Example: Bug Fix Workflow

**Scenario**: Fix version resolution bug (CHEF-9999)

```
🤖 Phase 1: Analysis for CHEF-9999
- Bug: Version resolver fails for partial versions on SLES
- Root cause: Platform mapping logic in lib/chef/version_resolver.rb
- Impact: SLES users get 404 errors for valid requests
- Files affected: lib/chef/version_resolver.rb, spec/chef/version_spec.rb

✅ Analysis complete. Ready for implementation? (y/n)

👤 User: y

🤖 Phase 2: Implementation
[Fixes the bug with proper SLES platform handling]

✅ Implementation complete:
- Fixed platform mapping for SLES 12/15
- Added proper version fallback logic
- Maintained backward compatibility

Ready for testing? (y/n)

👤 User: y

🤖 Phase 3: Testing
[Creates extensive tests for the bug fix]

✅ Testing complete:
- Added 15 test cases for SLES platform scenarios
- Tests cover the original bug and edge cases
- Verified fix works for SLES 12, 15, and opensuse-leap
- Coverage: 91% (exceeds requirement)

Ready for PR creation? (y/n)

👤 User: y

🤖 Phase 4: PR Creation
[Creates PR with bug fix labels]

✅ PR created with:
- Branch: CHEF-9999
- Labels: type/bug, priority/high
- Comprehensive description with before/after examples
- Links to Jira ticket and includes reproduction steps

Workflow complete! 🎉
```

## Label Management & Expeditor Integration

### Expeditor Skip Labels

**Use these labels to control Expeditor automation:**

```bash
# Skip all Expeditor actions (documentation-only changes)
gh pr create --label "Expeditor: Skip All"

# Skip version bump only (test improvements, internal refactoring)  
gh pr create --label "Expeditor: Skip Version Bump"

# Skip changelog generation (internal changes not user-facing)
gh pr create --label "Expeditor: Skip Changelog"

# Skip Docker image building (config-only changes)
gh pr create --label "Expeditor: Skip Docker"
```

### Label Decision Matrix

| Change Type | Labels to Use | Expeditor Behavior |
|-------------|---------------|-------------------|
| **Documentation Only** | `Expeditor: Skip All`, `type/docs` | No version bump, no changelog, no builds |
| **Test Improvements** | `Expeditor: Skip Version Bump`, `type/test` | No version bump, changelog generated, builds run |
| **Bug Fixes** | `type/bug`, `priority/medium` | Version bump, changelog, full pipeline |
| **New Features** | `type/enhancement`, `Expeditor: Bump Version Minor` | Minor version bump, changelog, full pipeline |
| **Breaking Changes** | `type/breaking`, `Expeditor: Bump Version Major` | Major version bump, changelog, full pipeline |
| **Security Fixes** | `type/security`, `priority/critical` | Version bump, changelog, expedited pipeline |
| **Internal Refactoring** | `Expeditor: Skip Changelog`, `type/maintenance` | Version bump, no changelog, builds run |

### Helm Chart Updates

**When modifying Helm charts:**
```bash
# Charts are automatically published when these files change:
# - charts/*
# - Dockerfile  
# - lib/*
# - app.rb
# - platforms.rb
# - poller
# - Gemfile
# - Gemfile.lock

# Use appropriate labels for chart changes
gh pr create --label "type/enhancement" --label "area/helm"
```

### Pipeline Integration

**Expeditor triggers these pipelines:**

1. **verify pipeline**: 
   - Runs on all PRs
   - Executes: tests, linting, security scans
   - Uses: `.expeditor/verify.pipeline.yml`

2. **docker/build pipeline**:
   - Runs on merged PRs (unless skipped)
   - Builds and publishes Docker images
   - Uses: `.expeditor/build.docker.yml`

**Example pipeline skip scenarios:**
```bash
# Documentation update - skip everything
git commit -m "DOCS-123: Update API documentation

Only updates README.md with new endpoint examples.
No code changes."

gh pr create --label "Expeditor: Skip All" --label "type/docs"

# Test coverage improvement - skip version bump
git commit -m "TEST-456: Improve test coverage for cache layer

Adds comprehensive tests for Redis error handling.
Increases coverage from 78% to 89%."

gh pr create --label "Expeditor: Skip Version Bump" --label "type/test"
```

## Code Ownership & Review Process

### CODEOWNERS Configuration

**Current code ownership:**
```
# .github/CODEOWNERS
*  @chef/infra-packages @chef/chef-foundation-reviewers
```

**All changes require approval from:**
- `@chef/infra-packages` team (primary maintainers)
- `@chef/chef-foundation-reviewers` team (secondary reviewers)

### Review Requirements

**For different change types:**

**Critical Files** (require extra scrutiny):
- `app.rb` - Core application logic
- `lib/chef/cache.rb` - Caching layer
- `lib/chef/version_resolver.rb` - Version resolution
- `.expeditor/config.yml` - Build automation

**Standard Files** (normal review process):
- Test files in `spec/`
- Configuration files
- Documentation
- Helm charts

**Auto-Generated Files** (no manual changes):
- `Gemfile.lock`
- `VERSION`
- `CHANGELOG.md`

### Review Checklist

**Reviewers should verify:**

1. **DCO Compliance**: All commits signed off
2. **Test Coverage**: >80% coverage maintained
3. **Backward Compatibility**: No breaking API changes
4. **Security**: Input validation, no credential exposure
5. **Performance**: No significant performance regressions
6. **Documentation**: Adequate inline and external docs
7. **Error Handling**: Proper exception handling
8. **Code Style**: Follows Ruby conventions

### Approval Process

**Minimum approvals required:**
- 1 approval from `@chef/infra-packages`
- 1 approval from `@chef/chef-foundation-reviewers`

**For critical changes (core API, security):**
- 2 approvals from `@chef/infra-packages`
- 1 approval from `@chef/chef-foundation-reviewers`
- Security team review (if applicable)

### Review Response Times

**Expected response times:**
- **Critical/Security**: 4 hours
- **Bug fixes**: 24 hours  
- **Features**: 48 hours
- **Documentation**: 72 hours

### Handling Review Feedback

```bash
# Address review comments
git add .
git commit --signoff -m "Address review feedback: improve error handling

- Add specific error messages for platform validation
- Improve test coverage for edge cases
- Update documentation with examples"

# Update PR
git push origin <branch-name>

# Respond to review comments
gh pr comment <PR_NUMBER> --body "Thanks for the feedback! I've addressed:
1. Added specific error messages as requested
2. Improved test coverage to 89%
3. Updated documentation with examples"
```

## Important Development Notes

### Critical Development Principles

1. **All work is performed locally** - No cloud-based development
2. **>80% test coverage is mandatory** - Non-negotiable requirement
3. **DCO signoff required** - Builds fail without proper signoff
4. **Backward compatibility** - Maintain API compatibility
5. **Security first** - Validate all inputs, handle errors gracefully

### Files That Should Never Be Modified

**🚨 DO NOT EDIT THESE FILES:**
- `Gemfile.lock` - Managed by Bundler
- `VERSION` - Auto-generated by Expeditor
- `CHANGELOG.md` - Auto-generated by Expeditor  
- `spec/data/*.json` - Test fixtures (use `rake refresh_data`)

### Performance Considerations

**Redis Usage:**
- Use connection pooling for production
- Implement proper timeout handling
- Cache manifest data efficiently
- Monitor Redis memory usage

**API Response Times:**
- Target <200ms for metadata endpoints
- Target <100ms for redirect endpoints
- Implement proper caching headers
- Use gzip compression for large responses

**Memory Management:**
- Monitor Ruby memory usage
- Implement proper garbage collection
- Use streaming for large file operations
- Avoid loading entire manifests into memory

### Integration Points

**External Dependencies:**
- **Redis**: Primary caching layer
- **Mixlib::Install**: Package metadata resolution
- **Chef Software S3**: Package artifact storage
- **Expeditor**: Build and release automation

**API Consumers:**
- **mixlib-install gem**: Ruby client library
- **Chef install scripts**: Shell and PowerShell installers
- **Chef Workstation**: Direct API integration
- **Third-party tools**: Various package managers

### Common Pitfalls to Avoid

1. **Missing DCO signoff** - Always use `--signoff`
2. **Insufficient test coverage** - Must exceed 80%
3. **Breaking API changes** - Maintain backward compatibility
4. **Hardcoded URLs** - Use configuration for all external URLs
5. **Missing error handling** - Handle all exception cases
6. **Platform case sensitivity** - Normalize platform names
7. **Version comparison bugs** - Use proper semantic versioning
8. **Redis connection leaks** - Properly close connections

### Debugging Common Issues

**Redis Connection Issues:**
```bash
# Check Redis connectivity
redis-cli ping

# Check Redis logs
docker logs <redis-container>

# Test Redis from Ruby
irb -r redis
Redis.new.ping
```

**Version Resolution Problems:**
```ruby
# Debug version resolution in console
require './app.rb'
require 'pry'

resolver = Chef::VersionResolver.new
binding.pry

# Test specific scenarios
resolver.resolve('chef', 'stable', '17.10', 'ubuntu', '20.04', 'x86_64')
```

**Test Data Issues:**
```bash
# Refresh test fixtures when manifests change
bundle exec rake refresh_data

# Verify test data integrity
find spec/data -name "*.json" -exec json_verify {} \;
```

## Troubleshooting

### Common Development Issues

#### 1. Bundle Install Failures

**Problem**: Gem compilation errors on macOS
```bash
# Solution: Install build tools
xcode-select --install

# For specific gems requiring native extensions
bundle config build.nokogiri --use-system-libraries
bundle install
```

**Problem**: Redis dependency issues
```bash
# Solution: Install Redis locally
brew install redis
brew services start redis

# Verify Redis is running
redis-cli ping  # Should return PONG
```

#### 2. Test Failures

**Problem**: Intermittent test failures
```bash
# Solution: Reset test environment
bundle exec rake refresh_data
bundle exec rspec --seed 1234  # Use consistent seed

# Check for test isolation issues
bundle exec rspec --bisect  # Find problematic test combinations
```

**Problem**: Test data out of sync
```bash
# Solution: Regenerate test fixtures
bundle exec rake refresh_data

# Verify fixtures are valid JSON
find spec/data -name "*.json" -exec json_verify {} \;
```

#### 3. Docker Issues

**Problem**: Docker build failures
```bash
# Solution: Clean Docker environment
docker system prune -a
make docker.delete-images

# Rebuild from scratch
docker build --no-cache -t omnitruck:local .
```

**Problem**: Redis connectivity in Docker
```bash
# Solution: Check Docker networking
docker network ls
docker run --rm redis:alpine redis-cli -h <redis-host> ping

# Use Docker Compose for easier networking
docker-compose up --build
```

#### 4. Application Runtime Issues

**Problem**: 404 errors for valid platforms
```bash
# Debug: Check platform mappings
irb -r './platforms.rb'
PlatformDSL.platforms  # List all supported platforms

# Verify manifest data
redis-cli get "stable/chef"
```

**Problem**: Version resolution failures
```bash
# Debug: Test version resolver directly
irb -r './app.rb'
cache = Chef::Cache.new
manifest = cache.manifest_for('chef', 'stable')
puts JSON.pretty_generate(manifest)
```

#### 5. Performance Issues

**Problem**: Slow API responses
```bash
# Profile Redis operations
redis-cli --latency-history -i 1

# Profile Ruby application
gem install ruby-prof
# Add profiling to specific endpoints
```

**Problem**: Memory leaks
```bash
# Monitor memory usage
ps aux | grep unicorn
top -p <unicorn-pid>

# Use memory profiler
gem install memory_profiler
# Add profiling code to app.rb
```

### Error Resolution Steps

#### 1. Build Pipeline Failures

**DCO Signoff Missing:**
```bash
# Fix last commit
git commit --amend --signoff --no-edit

# Fix multiple commits
git rebase -i HEAD~<count> --signoff
git push --force-with-lease origin <branch>
```

**Test Coverage Below 80%:**
```bash
# Run coverage analysis
bundle exec rspec --format documentation

# Identify untested code
# Add comprehensive tests for missing coverage
# Focus on edge cases and error conditions
```

#### 2. Integration Issues

**Expeditor Pipeline Failures:**
```bash
# Check .expeditor/config.yml syntax
yamllint .expeditor/config.yml

# Verify label configuration matches PR labels
gh pr view <PR_NUMBER> --json labels
```

**Helm Chart Deployment Issues:**
```bash
# Validate Helm chart
helm lint charts/omnitruck/

# Test local deployment
helm install omnitruck-test charts/omnitruck/ --dry-run
```

### Getting Help

#### 1. Internal Resources

**Chef Software Teams:**
- `@chef/infra-packages` - Primary maintainers
- `@chef/chef-foundation-reviewers` - Secondary reviewers
- `#releng-notify` Slack channel - Build notifications

**Documentation:**
- Chef Software internal wiki
- Expeditor documentation
- Ruby/Sinatra best practices

#### 2. External Resources

**Technical Documentation:**
- [Sinatra Documentation](http://sinatrarb.com/documentation.html)
- [RSpec Documentation](https://rspec.info/documentation/)
- [Redis Documentation](https://redis.io/documentation)

**Best Practices:**
- [Ruby Style Guide](https://rubystyle.guide/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Development](https://kubernetes.io/docs/tasks/debug-application-cluster/)

#### 3. Escalation Path

1. **Development Issues**: Post in team Slack channel
2. **Build/Release Issues**: Contact `@chef/infra-packages`
3. **Security Issues**: Contact Chef Security Team
4. **Critical Production Issues**: Follow incident response process

---

## Final Validation Checklist

Before completing any development task, ensure:

- [ ] **Repository structure understood** - Clear understanding of file organization
- [ ] **DCO signoff on all commits** - Every commit includes `--signoff`
- [ ] **>80% test coverage achieved** - Comprehensive test suite with high coverage
- [ ] **Actual repository labels used** - No generic placeholder labels
- [ ] **Expeditor integration documented** - Proper skip labels and build integration
- [ ] **Prompt-based workflow followed** - Step-by-step approval process
- [ ] **Ruby/Sinatra patterns followed** - Consistent with existing codebase
- [ ] **Complete Git workflow documented** - From branch creation to PR merge
- [ ] **Security requirements met** - Input validation and error handling
- [ ] **Troubleshooting section included** - Common issues and solutions

This guide provides everything needed to contribute effectively to the Omnitruck repository while maintaining the highest standards of quality, security, and integration with Chef Software's development practices.
