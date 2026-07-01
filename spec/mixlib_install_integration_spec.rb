require 'spec_helper'
require 'rack/test'

# Compatibility tests for mixlib-install gem
describe 'Mixlib-Install Compatibility' do
  include Rack::Test::Methods

  def app
    Omnitruck
  end

  describe 'version compatibility' do
    it 'uses mixlib-install >= 3.17.0' do
      require 'mixlib/install/version'
      
      version = Gem::Version.new(Mixlib::Install::VERSION)
      minimum_version = Gem::Version.new('3.17.0')
      
      expect(version).to be >= minimum_version
    end
  end

  describe 'install script generation' do
    it 'generates bash scripts' do
      get '/install.sh'
      
      expect(last_response).to be_ok
      expect(last_response.body).to start_with('#!/bin/sh')
      expect(last_response.body.lines.count).to be > 50
    end

    it 'generates PowerShell scripts' do
      get '/install.ps1'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('function Install-Project')
    end

    it 'supports -f flag for custom filenames' do
      get '/install.sh'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('f)  cmdline_filename="$OPTARG"')
    end
  end
end

