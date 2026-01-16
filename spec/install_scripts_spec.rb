require 'spec_helper'
require 'rack/test'

describe 'Omnitruck Install Scripts' do
  include Rack::Test::Methods

  def app
    Omnitruck
  end

  describe 'GET /install.sh' do
    it 'returns install.sh script' do
      get '/install.sh'
      expect(last_response).to be_ok
      expect(last_response.body).to include('#!/bin/sh')
      expect(last_response.body).to include('while getopts')
    end

    context 'with license_id parameter' do
      it 'includes license_id in the generated script' do
        get '/install.sh', { license_id: 'test-license-123' }
        expect(last_response).to be_ok
        expect(last_response.body).to include('#!/bin/sh')
        expect(last_response.body).to include('# License ID provided via context')
        expect(last_response.body).to include("license_id='test-license-123'")
      end
    end

    context 'without license_id parameter' do
      it 'does not include license_id pre-set in script' do
        get '/install.sh'
        expect(last_response).to be_ok
        expect(last_response.body).to include('#!/bin/sh')
        expect(last_response.body).not_to include('# License ID provided via context')
      end
    end
  end

  describe 'GET /install.ps1' do
    it 'returns install.ps1 script' do
      get '/install.ps1'
      expect(last_response).to be_ok
      expect(last_response.body).to include('function Install-Project')
      expect(last_response.body).to include('Get-ProjectMetadata')
    end

    context 'with license_id parameter' do
      it 'includes license_id in the generated script' do
        get '/install.ps1', { license_id: 'trial-license-456' }
        expect(last_response).to be_ok
        expect(last_response.body).to include('# License ID provided via context')
        expect(last_response.body).to include("install -license_id 'trial-license-456'")
      end
    end

    context 'without license_id parameter' do
      it 'does not include license_id in install command' do
        get '/install.ps1'
        expect(last_response).to be_ok
        expect(last_response.body).not_to include('# License ID provided via context')
      end
    end
  end
end
