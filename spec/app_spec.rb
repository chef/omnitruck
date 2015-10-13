#--
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2013 Chef Software, Inc.
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

  context "download / metadata endpoints" do
    let(:channel) { nil }
    let(:project){ nil }
    let(:project_version){ nil }
    let(:platform) { nil }
    let(:platform_version) { nil }
    let(:architecture) { nil }
    let(:params) do
      params = {}
      params[:v] = project_version if project_version
      params[:p] = platform if platform
      params[:pv] = platform_version if platform_version
      params[:m] = architecture if architecture
      params
    end

    let(:endpoint) { nil }

    shared_examples_for 'a correct package info' do
      context 'download' do
        let(:endpoint) { "/#{channel}/#{project}/download" }

        it "should serve a redirect package " do
          get(endpoint, params)
          expect(last_response).to be_redirect
          follow_redirect!

          expect(last_request.url).to eq(expected_info[:url])
        end
      end

      context 'metadata' do
        let(:endpoint) { "/#{channel}/#{project}/metadata" }

        it "should serve JSON metadata for package" do
          get(endpoint, params, "HTTP_ACCEPT" => "application/json")
          metadata_json = last_response.body
          parsed_json = JSON.parse(metadata_json)

          expect(parsed_json['url']).to eq(expected_info[:url])
          expect(parsed_json['sha256']).to eq(expected_info[:sha256])
          expect(parsed_json['md5']).to eq(expected_info[:md5])
          expect(parsed_json['version']).to eq(expected_info[:version])
        end

        it "should serve plain text metadata for package" do
          get(endpoint, params, "HTTP_ACCEPT" => "text/plain")
          text_metadata = last_response.body
          parsed_metadata = text_metadata.lines.inject({}) do |metadata, line|
            key, value = line.strip.split("\t")
            metadata[key] = value
            metadata
          end

          expect(parsed_metadata['url']).to eq(expected_info[:url])
          expect(parsed_metadata['sha256']).to eq(expected_info[:sha256])
          expect(parsed_metadata['md5']).to eq(expected_info[:md5])
          expect(parsed_metadata['version']).to eq(expected_info[:version])
        end
      end
    end

    context "for chef" do
      let(:project) { "chef" }

      context 'for stable' do
        let(:channel) { 'stable' }

        context 'for mac_os_x' do
          let(:platform) { 'mac_os_x' }

          context 'for 10.7' do
            let(:platform_version) { '10.7' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/mac_os_x/10.7/x86_64/chef-12.2.1-1.dmg',
                    sha256: '53034d6e1eea0028666caee43b99f43d2ca9dd24b260bc53ae5fad1075e83923',
                    md5: 'd00335944b2999d0511e6db30d1e71dc',
                    version: '12.2.1'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end

          # YOLO mode
          context 'for 10.12' do
            let(:platform_version) { '10.12' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/mac_os_x/10.11/x86_64/chef-12.4.3-1.dmg',
                    sha256: '32d290cb5648ea600d976717fa32fc1e213e4452f10dc7b481f4e9aa7200293c',
                    md5: 'e0caf8a0bd8b4140191fdfe7946da27c',
                    version: '12.4.3'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        # Platform mapping
        context 'for sles' do
          let(:platform) { 'sles' }

          context 'for 11.0' do
            let(:platform_version) { '11.0' }

            context 'for i686' do
              let(:architecture) { 'i686' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/el/6/i686/chef-12.4.3-1.el6.i386.rpm',
                    sha256: '221890739edadcf46501154c8cbdba771612140364ca4afa8290327c4703a1ee',
                    md5: 'a71d6c0039753ad207848ca385bd0432',
                    version: '12.4.3'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for suse' do
          let(:platform) { 'suse' }

          context 'for 12.1' do
            let(:platform_version) { '12.1' }

            context 'for i686' do
              let(:architecture) { 'i686' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/el/6/i686/chef-12.4.3-1.el6.i386.rpm',
                    sha256: '221890739edadcf46501154c8cbdba771612140364ca4afa8290327c4703a1ee',
                    md5: 'a71d6c0039753ad207848ca385bd0432',
                    version: '12.4.3'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end

          # 12.0 exercises major_only mode since only 12.1 exists -- this tests matching by major version going forwards
          context 'for 12.0' do
            let(:platform_version) { '12.0' }

            context 'for i686' do
              let(:architecture) { 'i686' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/el/6/i686/chef-12.4.3-1.el6.i386.rpm',
                    sha256: '221890739edadcf46501154c8cbdba771612140364ca4afa8290327c4703a1ee',
                    md5: 'a71d6c0039753ad207848ca385bd0432',
                    version: '12.4.3'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end

          # 12.2 exercises major_only mode since only 12.1 exists -- this tests matching by major version going backwards
          context 'for 12.2' do
            let(:platform_version) { '12.2' }

            context 'for i686' do
              let(:architecture) { 'i686' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/el/6/i686/chef-12.4.3-1.el6.i386.rpm',
                    sha256: '221890739edadcf46501154c8cbdba771612140364ca4afa8290327c4703a1ee',
                    md5: 'a71d6c0039753ad207848ca385bd0432',
                    version: '12.4.3'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for ubuntu' do
          let(:platform) { 'ubuntu' }

          context 'for 12.04' do
            let(:platform_version) { '12.04' }

            context 'for i686' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_12.4.3-1_amd64.deb',
                    sha256: 'de772b659e09b0ead5a116585f0f610ab74c82cb313a7bf7c747a6eb94db59df',
                    md5: 'd5f74a74ed2a405ffa47ae7ba2de1747',
                    version: '12.4.3'
                  }
                end

                it_behaves_like 'a correct package info'
              end

              context 'with "latest"' do
                let(:project_version) { 'latest' }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_12.4.3-1_amd64.deb',
                    sha256: 'de772b659e09b0ead5a116585f0f610ab74c82cb313a7bf7c747a6eb94db59df',
                    md5: 'd5f74a74ed2a405ffa47ae7ba2de1747',
                    version: '12.4.3'
                  }
                end

                it_behaves_like 'a correct package info'
              end

              context 'with partial version' do
                let(:project_version) { '12.1' }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_12.1.2-1_amd64.deb',
                    sha256: '4a92cdd99d337ac51529ca7fa402e2470e1a4e99a63d4260c81f275e047f4fb4',
                    md5: 'bbcc53f35e17b7bfe96bc2329854cb1b',
                    version: '12.1.2'
                  }
                end

                it_behaves_like 'a correct package info'
              end

              context 'with full version' do
                let(:project_version) { '10.24.0' }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/11.04/x86_64/chef_10.24.0-1.ubuntu.11.04_amd64.deb',
                    sha256: '4afb1aae6409a33b511d932ce670d1e1c7c8c69daf36647606d65e6f6ef36313',
                    md5: '244446bd643339fc5e68201d4855ac25',
                    version: '10.24.0'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end

          # Here we are testing an edge condition of yolo mode.
          # Cache has 12.6.1 version for 13.04 but it does not have it for 14.04
          # Yolo mode should serve the 13.04 artifact when asked latest on 14.04
          context 'for 14.04' do
            let(:platform_version) { '14.04' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'with "latest"' do
                let(:project_version) { 'latest' }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/13.04/x86_64/chef_12.6.1-1_amd64.deb',
                    sha256: '44448a2477c11615f86ffe686a68fa6636112ba82ebe6bb22daa5dd416f3c13e',
                    md5: '44449f54115d754373c9891b8759497c',
                    version: '12.6.1'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end

          # What we're testing on this next one is if yolo is sorting numerically or lexicographically
          # If we're getting string compares we'll get "10.04" as our yolo version, but we want to do a
          # numeric compare and get 12.04 instead:
          #   String (Wrong): "101" < "10" < "12"
          #   Integer (Right): 10 < 12 < 101
          context 'for extreme yolo version 101.04' do
            let(:platform_version) { '101.04' }

            context 'for i686' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/13.04/x86_64/chef_12.6.1-1_amd64.deb',
                    sha256: '44448a2477c11615f86ffe686a68fa6636112ba82ebe6bb22daa5dd416f3c13e',
                    md5: '44449f54115d754373c9891b8759497c',
                    version: '12.6.1'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for windows' do
          let(:platform) { 'windows' }

          %w{2008r2 2012 2012r2 8 7 2003r2 2012r2}.each do |windows_platform_version|
            %w{x86_64 i386 i686}.each do |architecture|

              context "for #{windows_platform_version}" do
                let(:platform_version) { windows_platform_version }

                context "for #{architecture}" do
                  let(:architecture) { architecture }

                  context 'without a version' do
                    let(:project_version) { nil }
                    let(:expected_info) do
                      {
                        url: 'https://opscode-omnibus-packages.s3.amazonaws.com/windows/2012r2/i386/chef-client-12.4.3-1-x86.msi',
                        sha256: '010925f18c1b7c70abff698960108a2f8687accf1be0250309d832d0f60add37',
                        md5: '42be33c3fe1174b2b8c437b29cf42e84',
                        version: '12.4.3'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with specific version' do
                    let(:project_version) { '12.4.1' }
                    let(:expected_info) do
                      {
                        url: 'https://opscode-omnibus-packages.s3.amazonaws.com/windows/2008r2/x86_64/chef-client-12.4.1-1.msi',
                        sha256: 'f02f5243f16b860e1d208e7d078b8bf0600c60159d49141b678391936b0afff2',
                        md5: '4d9d2320ad9f86f942bb4b12e34bc221',
                        version: '12.4.1'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end
                end
              end
            end
          end
        end
      end

      context 'for current' do
        let(:channel) { 'current' }

        context 'for solaris2' do
          let(:platform) { 'solaris2' }

          context 'for 5.11' do
            let(:platform_version) { '5.11' }

            context 'for sun4v' do
              let(:architecture) { 'sun4v' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages-current.s3.amazonaws.com/solaris2/5.11/sun4v/chef-12.4.3%2B20150930210020-1.sun4v.solaris',
                    sha256: '0b47b33151c7714b753061d2a80ab79c8efd23f800610a23ad32b5d6d19cc671',
                    md5: '27bad1563bff9b6cf499c4ede54b1a1d',
                    version: '12.4.3+20150930210020'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end
    end

    context 'for chefdk' do
      let(:project) { "chefdk" }

      context 'for stable' do
        let(:channel) { 'stable' }

        context 'for windows' do
          let(:platform) { 'windows' }

          context 'for 2008r2' do
            let(:platform_version) { '2008r2' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/windows/2012r2/i386/chefdk-0.8.1-1-x86.msi',
                    sha256: '4861563c12cfa9fc27df602a19e19906b7297150f19a00f45dc41c1121d25e2e',
                    md5: '6fc01d690fb8f7e1e8b9e657dc6c807c',
                    version: '0.8.1'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end

      context 'for current' do
        let(:channel) { 'current' }

        context 'for mac_os_x' do
          let(:platform) { 'mac_os_x' }

          context 'for 10.10' do
            let(:platform_version) { '10.10' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages-current.s3.amazonaws.com/mac_os_x/10.10/x86_64/chefdk-0.8.0%2B20150930085008-1.dmg',
                    sha256: 'bd763a3c107172e28a49596fb0fcdf58803eb898a2e2b5f002803dd38cc0b9e6',
                    md5: 'b9a0bc6f034bb8d2124a2246f5c5ecd2',
                    version: '0.8.0+20150930085008'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end
    end

    context 'for chef-server' do
      let(:project) { "chef-server" }

      context 'for stable' do
        let(:channel) { 'stable' }

        context 'for el' do
          let(:platform) { 'el' }

          context 'for 6' do
            let(:platform_version) { '6' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-server-11.1.6-1.el6.x86_64.rpm',
                    sha256: 'd4f9c9515dd8035acd4b38098fd2f243f26fb925ae15e47817f93d73cf9a850c',
                    md5: '46306e25be913efe0ffca5aa98f42c85',
                    version: '11.1.6'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end

      # there are no builds in the current channel of chef-server anymore
    end

    context 'for angrychef' do
      let(:project) { "angrychef" }

      context 'for stable' do
        let(:channel) { 'stable' }

        context 'for debian' do
          let(:platform) { 'debian' }

          context 'for 6' do
            let(:platform_version) { '6' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages.s3.amazonaws.com/debian/6/x86_64/angrychef_12.2.1-1_amd64.deb',
                    sha256: 'da3affb7301c8a7ccb105c15da4229091c8ba8573e124fe07b5044e2869080e4',
                    md5: '1047a611391f8d1f154bd17dc80f05be',
                    version: '12.2.1'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end

      context 'for current' do
        let(:channel) { 'current' }

        context 'for freebsd' do
          let(:platform) { 'freebsd' }

          context 'for 10' do
            let(:platform_version) { '10' }

            context 'for amd64' do
              let(:architecture) { 'amd64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://opscode-omnibus-packages-current.s3.amazonaws.com/freebsd/10/amd64/angrychef-12.5.0%2B20150910004014_1.amd64.sh',
                    sha256: '3f5e8ccbbfb3034545f0099b396c0c281807658e434394621c6ee7b8d07a2c14',
                    md5: 'c1f95d1f4dc68c42478ce8254b8b36d2',
                    version: '12.5.0+20150910004014'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end
    end

  end

  context '/<CHANNEL>/<PROJECT>/versions endpoint' do
    Chef::Project::KNOWN_PROJECTS.each do |project|
      context "for #{project}" do
        let(:endpoint){ "/stable/#{project}/versions" }

        it "exists" do
          get(endpoint)
          expect(last_response).to be_ok
        end

        it "returns the correct JSON data" do
          get(endpoint)
          expect(last_response.header['Content-Type']).to include 'application/json'
          expect(last_response.body).to match(project)
        end
      end
    end

    # Let's test with chefdk because chef manifest have a 12.6.1 entry in it which
    # limits the information we are getting out of this endpoint.
    context "for stable chefdk" do
      let(:endpoint) { '/stable/chefdk/versions' }
      let(:params) { { v: version } }
      let(:versions_output) {
        get(endpoint, params)
        metadata_json = last_response.body
        JSON.parse(metadata_json)
      }

      [ nil, 'latest', '0'].each do |version|
        context "with version #{version.inspect}" do
          let(:version) { version }

          it 'returns the latest version for each platform, platform_version and architecture' do
            expect(versions_output.keys.length).to eq(5)

            versions_output.each do |p, data|
              data.each do |pv, data|
                data.each do |m, metadata|
                  expect(metadata['relpath']).to be_a(String)
                  expect(metadata['md5']).to match /^[0-9a-f]{32}$/
                  expect(metadata['sha256']).to match /^[0-9a-f]{64}$/
                  expect(metadata['url']).to match 'http'
                  expect(metadata['version']).to eq('0.8.1')
                end
              end
            end
          end
        end
      end

      context 'with version 0.6' do
        let(:version) { '0.6' }

        it 'returns the latest starting with 0.6 for each platform, platform_version and architecture' do
          expect(versions_output.keys.length).to eq(5)

          versions_output.each do |p, data|
            data.each do |pv, data|
              data.each do |m, metadata|
                expect(metadata['relpath']).to be_a(String)
                expect(metadata['md5']).to match /^[0-9a-f]{32}$/
                expect(metadata['sha256']).to match /^[0-9a-f]{64}$/
                expect(metadata['url']).to match 'http'
                # 0.6.2 is the latest on the 0.6.X series
                expect(metadata['version']).to eq('0.6.2')
              end
            end
          end
        end
      end

      context 'with version 0.7.0' do
        let(:version) { '0.7.0' }

        it 'returns version 0.7.0 for each platform, platform_version and architecture' do
          expect(versions_output.keys.length).to eq(5)

          versions_output.each do |p, data|
            data.each do |pv, data|
              data.each do |m, metadata|
                expect(metadata['relpath']).to be_a(String)
                expect(metadata['md5']).to match /^[0-9a-f]{32}$/
                expect(metadata['sha256']).to match /^[0-9a-f]{64}$/
                expect(metadata['url']).to match 'http'
                # We expect the exact version here
                expect(metadata['version']).to eq('0.7.0')
              end
            end
          end
        end
      end
    end

    context "for current chefdk" do
      let(:endpoint) { '/current/chefdk/versions' }
      let(:params) { { v: version } }
      let(:versions_output) {
        get(endpoint, params)
        metadata_json = last_response.body
        JSON.parse(metadata_json)
      }

      # This version does not exist for Mac OS X. This case tests a corner case
      # where a version is not available for a specific platform but available
      # for others. Note that we check we get 4 platforms instead of 5.
      context "with full integration version" do
        let(:version) { '0.8.0+20150927085010' }
        it 'returns the exact version for each platform, platform_version and architecture' do
          expect(versions_output.keys.length).to eq(4)

          versions_output.each do |p, data|
            data.each do |pv, data|
              data.each do |m, metadata|
                expect(metadata['relpath']).to be_a(String)
                expect(metadata['md5']).to match /^[0-9a-f]{32}$/
                expect(metadata['sha256']).to match /^[0-9a-f]{64}$/
                expect(metadata['url']).to match 'http'
                expect(metadata['version']).to eq('0.8.0+20150927085010')
              end
            end
          end
        end
      end
    end
  end

  context "install script" do
    %w(
      sh
      ps1
    ).each do |extension|
      context "/install.#{extension}" do
        let(:install_script) { "/install.#{extension}" }
        it "exists" do
          get install_script
          expect(last_response).to be_ok
        end
      end
    end

    context "unknown extension" do
      it "returns a 404" do
        get "/stable/chef/install.poop"
        expect(last_response).to be_not_found
      end
    end
  end

  context "/_status" do
    let(:endpoint){"/_status"}

    it "exists" do
      get endpoint
      expect(last_response).to be_ok
    end

    it "returns JSON data" do
      get endpoint
      expect(last_response.header['Content-Type']).to include 'application/json'
    end

    it "returns the timestamp of the last poller run" do
      get endpoint
      expect(JSON.parse(last_response.body)["timestamp"]).to eq("2015-10-01 23:36:33 -0700")
    end
  end

  context "legacy behavior" do
    let(:prerelease){ nil }
    let(:nightlies){ nil }

    let(:params) do
      params = {}
      params[:p] = 'ubuntu'
      params[:pv] = '10.04'
      params[:m] = 'x86_64'
      params[:prerelease] = prerelease unless prerelease.nil? # could be false, explicitly
      params[:nightlies] = nightlies unless nightlies.nil?    # could be false, explicitly
      params
    end

    %w(
      nightlies
      prerelease
    ).each do |legacy_param|

      context "#{legacy_param} param" do
        let(:endpoint) { '/metadata' }
        let(legacy_param.to_sym) { true }

        it "returns a package from the current channel" do
          get(endpoint, params)
          expect(last_response.body).to match("opscode-omnibus-packages-current")
        end
      end

    end

    {
      '/download' => 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef_12.4.3-1_amd64.deb',
      '/download-server' => 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.1.6-1_amd64.deb',
      '/metadata' => {
        url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef_12.4.3-1_amd64.deb',
        sha256: 'de772b659e09b0ead5a116585f0f610ab74c82cb313a7bf7c747a6eb94db59df',
        md5: 'd5f74a74ed2a405ffa47ae7ba2de1747',
        version: '12.4.3'
      },
      '/metadata-server' => {
        url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.1.6-1_amd64.deb',
        sha256: 'ae2b6d893241de8eeb05aee8f00b947034f88097d9b61e5ea2ad511352a58b3f',
        md5: '5f77ef54091a7445ad7eef6f7de699bd',
        version: '11.1.6'
      },
      '/full_client_list' => nil,
      '/full_list' => nil,
      '/full_server_list' => nil
    }.each do |legacy_endpoint, response_match_data|

      context "legacy endpoint #{legacy_endpoint}" do
        let(:endpoint) { legacy_endpoint }

        it "returns the correct response data" do
          get(endpoint, params)

          if legacy_endpoint =~ /download/
            follow_redirect!
            expect(last_request.url).to match(response_match_data)
          elsif legacy_endpoint =~ /metadata/
            parsed_metadata = last_response.body.lines.inject({}) do |metadata, line|
              key, value = line.strip.split("\t")
              metadata[key] = value
              metadata
            end

            expect(parsed_metadata['url']).to eq(response_match_data[:url])
            expect(parsed_metadata['sha256']).to eq(response_match_data[:sha256])
            expect(parsed_metadata['md5']).to eq(response_match_data[:md5])
            expect(parsed_metadata['version']).to eq(response_match_data[:version])
          else
            parsed_json = JSON.parse(last_response.body)

            # we check a certain hash structure that needs to be present in these endpoints
            parsed_json.each do |platform, data|
              data.each do |platform_version, data|
                data.each do |architecture, metadata|
                  expect(metadata['url']).to be_a(String)
                  expect(metadata['md5']).to be_a(String)
                  expect(metadata['sha256']).to be_a(String)
                  expect(metadata['relpath']).to be_a(String)
                  expect(metadata['version']).to be_a(String)
                end
              end
            end

          end
        end

      end
    end
  end
end
