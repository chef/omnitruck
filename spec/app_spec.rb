#--
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2024 Chef Software, Inc.
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
#

require 'spec_helper'
require 'uri'

context 'Omnitruck' do
  def app
    Omnitruck
  end

  # Accept: application/json is required for all metadata/JSON endpoints because
  # the metadata endpoint checks request.accept?('text/plain') and responds with
  # plain text when the Accept header matches (including the default */*).
  JSON_ACCEPT = { 'HTTP_ACCEPT' => 'application/json' }.freeze

  # ---------------------------------------------------------------------------
  # Info / status endpoints
  # ---------------------------------------------------------------------------

  describe 'GET /products' do
    it 'returns a JSON array of known products' do
      get '/products'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      products = JSON.parse(last_response.body)
      expect(products).to be_an(Array)
      expect(products).to include('chef', 'chef-workstation', 'chefdk', 'inspec')
    end
  end

  describe 'GET /platforms' do
    it 'returns a JSON hash of supported platforms' do
      get '/platforms'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      platforms = JSON.parse(last_response.body)
      expect(platforms).to be_a(Hash)
      expect(platforms['ubuntu']).to eq('Ubuntu Linux')
      expect(platforms['windows']).to eq('Windows')
      expect(platforms['el']).to eq('Red Hat Enterprise Linux/CentOS')
      expect(platforms['mac_os_x']).to eq('macOS')
    end
  end

  describe 'GET /architectures' do
    it 'returns a JSON array of supported architectures' do
      get '/architectures'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      archs = JSON.parse(last_response.body)
      expect(archs).to be_an(Array)
      expect(archs).not_to be_empty
      expect(archs).to include('x86_64')
    end
  end

  describe 'GET /_healthz' do
    it 'returns 204 No Content' do
      get '/_healthz'
      expect(last_response.status).to eq(204)
    end
  end

  describe 'GET /_version' do
    it 'returns version information as JSON' do
      get '/_version'
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['version']).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe 'GET /_status' do
    it 'returns a timestamp JSON from the stable chef manifest' do
      get '/_status'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      data = JSON.parse(last_response.body)
      expect(data).to have_key('timestamp')
      expect(data['timestamp']).to eq('2024-09-14 06:26:34 -0400')
    end
  end

  # ---------------------------------------------------------------------------
  # Metadata endpoint
  # ---------------------------------------------------------------------------

  describe 'GET /stable/chef/metadata' do
    let(:el7_params) { { p: 'el', pv: '7', m: 'x86_64' } }

    context 'with el/7/x86_64, no version specified' do
      it 'returns JSON metadata for the latest stable chef version' do
        get '/stable/chef/metadata', el7_params, JSON_ACCEPT
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')
        data = JSON.parse(last_response.body)
        expect(data['version']).to eq(latest_stable_chef)
        expect(data['url']).to include('/stable/chef/')
        expect(data['url']).to include('/el/7/')
        expect(data['sha256']).not_to be_nil
        expect(data['sha256']).not_to be_empty
        expect(data['sha1']).not_to be_nil
        expect(data['sha1']).not_to be_empty
      end

      it 'returns plain-text metadata when Accept: text/plain' do
        get '/stable/chef/metadata', el7_params, 'HTTP_ACCEPT' => 'text/plain'
        expect(last_response).to be_ok
        parsed = last_response.body.lines.inject({}) do |h, line|
          k, v = line.strip.split("\t")
          h[k] = v unless k.nil?
          h
        end
        expect(parsed['version']).to eq(latest_stable_chef)
        expect(parsed['url']).to include('/stable/chef/')
        expect(parsed['sha256']).not_to be_empty
        expect(parsed['sha1']).not_to be_empty
      end
    end

    context 'with an explicit version' do
      it 'returns metadata for the specified version' do
        get '/stable/chef/metadata', el7_params.merge(v: latest_stable_chef), JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['version']).to eq(latest_stable_chef)
      end
    end

    context 'with ubuntu 20.04/x86_64' do
      it 'returns a .deb package URL' do
        get '/stable/chef/metadata', { p: 'ubuntu', pv: '20.04', m: 'x86_64' }, JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['url']).to include('ubuntu')
        expect(data['url']).to end_with('.deb')
      end
    end

    context 'with windows 2019/x86_64' do
      it 'returns a .msi package URL' do
        get '/stable/chef/metadata', { p: 'windows', pv: '2019', m: 'x86_64' }, JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['url']).to include('windows')
        expect(data['url']).to end_with('.msi')
      end
    end

    context 'with sles 12/x86_64 (native SLES build threshold exceeded)' do
      it 'returns a native SLES package URL' do
        get '/stable/chef/metadata', { p: 'sles', pv: '12', m: 'x86_64' }, JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['url']).not_to be_empty
        expect(data['url']).to include('sles')
      end
    end

    context 'with an invalid version' do
      it 'returns 404' do
        get '/stable/chef/metadata', el7_params.merge(v: '0.0.0'), JSON_ACCEPT
        expect(last_response.status).to eq(404)
      end
    end

    context 'with an invalid platform' do
      it 'returns 404' do
        get '/stable/chef/metadata', { p: 'fakeos', pv: '99', m: 'x86_64' }, JSON_ACCEPT
        expect(last_response.status).to eq(404)
      end
    end

    context 'with explicit stable channel and prerelease=true' do
      it 'still uses the stable channel from the explicit URL segment' do
        get '/stable/chef/metadata', el7_params.merge(prerelease: 'true'), JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['version']).to eq(latest_stable_chef)
      end
    end
  end

  describe 'GET /current/chef/metadata' do
    let(:el7_params) { { p: 'el', pv: '7', m: 'x86_64' } }

    it 'returns metadata from the current channel' do
      get '/current/chef/metadata', el7_params, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['version']).to eq(latest_current_chef)
      expect(data['url']).to include('/current/chef/')
    end
  end

  describe 'GET /chef/metadata (no explicit channel)' do
    let(:el7_params) { { p: 'el', pv: '7', m: 'x86_64' } }

    it 'defaults to stable channel when no prerelease param is given' do
      get '/chef/metadata', el7_params, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['version']).to eq(latest_stable_chef)
    end

    it 'uses current channel when prerelease=true is given' do
      get '/chef/metadata', el7_params.merge(prerelease: 'true'), JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['version']).to eq(latest_current_chef)
    end

    it 'uses current channel when nightlies=true is given' do
      get '/chef/metadata', el7_params.merge(nightlies: 'true'), JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['version']).to eq(latest_current_chef)
    end
  end

  # ---------------------------------------------------------------------------
  # Download endpoint
  # ---------------------------------------------------------------------------

  describe 'GET /stable/chef/download' do
    let(:el7_params) { { p: 'el', pv: '7', m: 'x86_64' } }

    it 'redirects to the el/7 package URL' do
      get '/stable/chef/download', el7_params
      expect(last_response).to be_redirect
      expect(last_response.location).to include('/stable/chef/')
      expect(last_response.location).to include('/el/7/')
    end

    it 'redirects ubuntu packages to .deb URLs' do
      get '/stable/chef/download', { p: 'ubuntu', pv: '20.04', m: 'x86_64' }
      expect(last_response).to be_redirect
      expect(last_response.location).to include('ubuntu')
      expect(last_response.location).to end_with('.deb')
    end

    it 'normalizes i686 to i386 for windows packages (32-bit URL)' do
      get '/stable/chef/download', { p: 'windows', pv: '2019', m: 'i686' }
      expect(last_response).to be_redirect
      # Windows 32-bit packages use x86 in the filename (not x86_64)
      expect(last_response.location).to include('windows')
      expect(last_response.location).to end_with('.msi')
      expect(last_response.location).not_to include('x86_64')
    end

    it 'normalizes arm64 to aarch64 for linux packages' do
      get '/stable/chef/download', { p: 'ubuntu', pv: '20.04', m: 'arm64' }
      expect(last_response).to be_redirect
      # Ubuntu arm64 packages use arm64 in the filename (manifest key is aarch64)
      expect(last_response.location).to include('ubuntu')
      expect(last_response.location).to end_with('.deb')
      expect(last_response.location).to include('arm64')
    end

    context 'with an invalid version' do
      it 'returns 404' do
        get '/stable/chef/download', el7_params.merge(v: '0.0.0')
        expect(last_response.status).to eq(404)
      end
    end

    context 'with an invalid platform' do
      it 'returns 404' do
        get '/stable/chef/download', { p: 'fakeos', pv: '99', m: 'x86_64' }
        expect(last_response.status).to eq(404)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Packages endpoint
  # ---------------------------------------------------------------------------

  describe 'GET /stable/chef/packages' do
    it 'returns a nested JSON package list' do
      get '/stable/chef/packages'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      data = JSON.parse(last_response.body)
      expect(data).to be_a(Hash)
      expect(data).to have_key('el')
      expect(data['el']).to have_key('7')
      expect(data['el']['7']).to have_key('x86_64')
      pkg = data['el']['7']['x86_64']
      expect(pkg).to have_key('url')
      expect(pkg).to have_key('sha256')
      expect(pkg).to have_key('version')
    end

    it 'returns a flattened JSON package list with flatten=true' do
      get '/stable/chef/packages', { flatten: 'true' }
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data).to be_a(Hash)
      # Flattened: each platform value is an array of package hashes
      first_platform_pkgs = data.values.first
      expect(first_platform_pkgs).to be_an(Array)
      first_pkg = first_platform_pkgs.first
      expect(first_pkg).to have_key('url')
      expect(first_pkg).to have_key('platform_version')
      expect(first_pkg).to have_key('architecture')
    end
  end

  describe 'GET /current/chef/packages' do
    it 'returns packages from the current channel' do
      get '/current/chef/packages'
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data).to be_a(Hash)
      expect(data).to have_key('el')
    end
  end

  # ---------------------------------------------------------------------------
  # Versions endpoints (stubs Mixlib::Install to avoid network calls)
  # ---------------------------------------------------------------------------

  describe 'GET /stable/chef/versions/all' do
    before do
      allow(Mixlib::Install).to receive(:available_versions)
        .with('chef', 'stable')
        .and_return(['18.3.0', '18.4.0', '18.5.0'])
    end

    it 'returns all available versions as a JSON array' do
      get '/stable/chef/versions/all'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      data = JSON.parse(last_response.body)
      expect(data).to eq(['18.3.0', '18.4.0', '18.5.0'])
    end
  end

  describe 'GET /stable/chef/versions/latest' do
    before do
      allow(Mixlib::Install).to receive(:available_versions)
        .with('chef', 'stable')
        .and_return(['18.3.0', '18.4.0', '18.5.0'])
    end

    it 'returns the latest version as a JSON string' do
      get '/stable/chef/versions/latest'
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data).to eq('18.5.0')
    end
  end

  # ---------------------------------------------------------------------------
  # Amazon Linux 2 URL rewriting
  # ---------------------------------------------------------------------------

  describe 'Amazon Linux 2 URL rewriting' do
    context 'chef on amazon/2 (metadata)' do
      it 'remaps internally to el/7 packages' do
        get '/stable/chef/metadata', { p: 'amazon', pv: '2', m: 'x86_64' }, JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        # chef on amazon/2 is remapped to el/7 in get_package_info
        expect(data['url']).to include('/el/7/')
      end
    end

    context 'chef on amazon/2 (download)' do
      it 'redirects to an el/7 package URL' do
        get '/stable/chef/download', { p: 'amazon', pv: '2', m: 'x86_64' }
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/el/7/')
      end
    end

    context 'chef-workstation on amazon/2 (metadata)' do
      it 'rewrites the amazon/2 URL to el/7 in the response' do
        get '/stable/chef-workstation/metadata', { p: 'amazon', pv: '2', m: 'x86_64' }, JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        # URL is rewritten from /amazon/2/ to /el/7/ for chef-workstation
        expect(data['url']).to include('/el/7/')
        expect(data['url']).not_to include('/amazon/2/')
      end
    end

    context 'chef-workstation on amazon/2 (download)' do
      it 'redirects to an el/7 URL' do
        get '/stable/chef-workstation/download', { p: 'amazon', pv: '2', m: 'x86_64' }
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/el/7/')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # SLES platform remapping
  # ---------------------------------------------------------------------------

  describe 'SLES platform handling' do
    context 'with sles/12/x86_64 and latest chef (above native-build threshold)' do
      it 'serves native SLES packages without remapping to EL' do
        get '/stable/chef/metadata', { p: 'sles', pv: '12', m: 'x86_64' }, JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['url']).to include('sles')
        expect(data['url']).not_to include('/el/')
      end
    end

    context 'with sles/11/x86_64 and a version below the native-build threshold' do
      it 'remaps to EL packages for pre-native-build versions' do
        # 12.0.3 < SLES_PROJECT_VERSIONS["chef"] (12.21.1) => remaps to EL
        # sles pv 11 <= 11 maps to el/5
        get '/stable/chef/metadata', { p: 'sles', pv: '11', m: 'x86_64', v: '12.0.3' }, JSON_ACCEPT
        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['url']).to include('/el/')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Legacy redirects
  # ---------------------------------------------------------------------------

  describe 'legacy redirects' do
    it 'GET /download passes through to /chef/download' do
      get '/download', { p: 'el', pv: '7', m: 'x86_64' }
      expect(last_response).to be_redirect
    end

    it 'GET /metadata passes through to /chef/metadata and returns JSON' do
      get '/metadata', { p: 'el', pv: '7', m: 'x86_64' }, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data).to have_key('url')
    end

    it 'GET /download-server passes through to /chef-server/download' do
      get '/download-server', { p: 'el', pv: '7', m: 'x86_64' }
      expect(last_response).to be_redirect
    end

    it 'GET /metadata-server passes through to /chef-server/metadata' do
      get '/metadata-server', { p: 'el', pv: '7', m: 'x86_64' }, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data).to have_key('url')
    end

    it 'GET /full_client_list passes through to /chef/packages' do
      get '/full_client_list'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
    end

    it 'GET /full_server_list passes through to /chef-server/packages' do
      get '/full_server_list'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
    end

    it 'GET /chef_platform_names returns platforms JSON (via direct legacy redirect to /platforms)' do
      # /chef_platform_names is in the legacy hash: '/chef_platform_names' => '/platforms'
      # It calls /platforms directly (not via /chef/platforms), so returns 200 with JSON
      get '/chef_platform_names'
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data).to have_key('ubuntu')
      expect(data).to have_key('windows')
    end

    it 'GET /chef/metadata-chefdk passes through to /chefdk/metadata' do
      get '/chef/metadata-chefdk', { p: 'el', pv: '7', m: 'x86_64' }, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['url']).to include('chefdk')
    end

    it 'GET /install.msi redirects to a windows download URL' do
      get '/install.msi'
      expect(last_response).to be_redirect
      expect(last_response.location).to include('download')
      expect(last_response.location).to include('windows')
    end

    it 'GET /chef/install.msi redirects to a windows download URL' do
      get '/chef/install.msi'
      expect(last_response).to be_redirect
      expect(last_response.location).to include('download')
    end
  end

  # ---------------------------------------------------------------------------
  # Multiple projects
  # ---------------------------------------------------------------------------

  describe 'GET /stable/chefdk/metadata' do
    it 'returns chefdk package metadata for the latest stable version' do
      get '/stable/chefdk/metadata', { p: 'el', pv: '7', m: 'x86_64' }, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['url']).to include('chefdk')
      expect(data['version']).to eq(latest_stable_chefdk)
    end
  end

  describe 'GET /stable/inspec/metadata' do
    it 'returns inspec package metadata' do
      get '/stable/inspec/metadata', { p: 'el', pv: '7', m: 'x86_64' }, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['url']).to include('inspec')
    end
  end

  describe 'GET /stable/chef-workstation/metadata' do
    it 'returns chef-workstation metadata for the latest stable version' do
      get '/stable/chef-workstation/metadata', { p: 'el', pv: '7', m: 'x86_64' }, JSON_ACCEPT
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['url']).to include('chef-workstation')
      expect(data['version']).to eq(latest_stable_chef_workstation)
    end
  end
end
