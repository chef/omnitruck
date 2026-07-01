require 'spec_helper'
require 'rack/test'

# General integration tests for mixlib-install gem compatibility
describe 'Mixlib-Install Integration Tests' do
  include Rack::Test::Methods

  def app
    Omnitruck
  end

  describe 'Install script generation with mixlib-install' do
    context 'bash script with license_id parameter' do
      it 'generates valid bash script with -f flag support' do
        get '/install.sh', { license_id: 'test-license-123' }
        
        expect(last_response).to be_ok
        script = last_response.body
        
        # Script should accept -f flag for custom filename
        expect(script).to include('f)  cmdline_filename="$OPTARG"')
        expect(script).to include('license_id="test-license-123"')
      end

      it 'generates bash script with standard install parameters' do
        get '/install.sh'
        
        expect(last_response).to be_ok
        script = last_response.body
        
        # Should support standard parameters
        expect(script).to include('#!/bin/sh')
        expect(script).to include('while getopts')
      end

      it 'handles known package types' do
        get '/install.sh'
        
        expect(last_response).to be_ok
        script = last_response.body
        
        # Should mention common package types
        expect(script).to match(/rpm|deb|pkg/)
      end
    end

    context 'PowerShell script generation' do
      it 'generates valid ps1 script' do
        get '/install.ps1'
        
        expect(last_response).to be_ok
        script = last_response.body
        
        # Verify PowerShell script structure
        expect(script).to include('function ')
        expect(script).to include('Install-Project')
      end

      it 'includes license parameter support' do
        get '/install.ps1', { license_id: 'test-ps1-123' }
        
        expect(last_response).to be_ok
        script = last_response.body
        
        expect(script).to include("$license_id = 'test-ps1-123'")
      end
    end

    context 'parameter combinations' do
      it 'handles license_id and base_url together' do
        get '/install.sh', { license_id: 'test-123', base_url: 'https://custom.chef.io' }
        
        expect(last_response).to be_ok
        script = last_response.body
        
        expect(script).to include('license_id="test-123"')
        expect(script).to include('base_api_url="https://custom.chef.io"')
      end
    end

    context 'mixlib-install version' do
      it 'uses mixlib-install >= 3.17.0' do
        require 'mixlib/install/version'
        
        version = Gem::Version.new(Mixlib::Install::VERSION)
        minimum_version = Gem::Version.new('3.17.0')
        
        expect(version).to be >= minimum_version
      end
    end

    context 'script syntax validation' do
      it 'generates syntactically valid bash script' do
        get '/install.sh'
        
        expect(last_response).to be_ok
        script = last_response.body
        
        # Basic syntax checks
        expect(script).to start_with('#!/bin/sh')
        expect(script.lines.count).to be > 50  # Should be a substantial script
      end
    end
  end
end
