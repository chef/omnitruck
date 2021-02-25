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

  context "/products endpoint" do
    it "returns all the products" do
      get("/products")

      response = JSON.parse(last_response.body)
      Chef::Cache::KNOWN_PROJECTS.each do |project|
        response.include?(project)
      end
    end
  end

  context "/platforms endpoint" do
    it "returns JSON data" do
      get("/platforms")
      expect(last_response.header['Content-Type']).to include 'application/json'
    end
  end

  context "/architectures endpoint" do
    it "returns all the architectures" do
      get("/architectures")

      response = JSON.parse(last_response.body)
      Mixlib::Install::Options::SUPPORTED_ARCHITECTURES.each do |arch|
        response.include?(arch)
      end
    end
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

    let(:expected_project) { project }
    let(:expected_channel) { channel }
    let(:expected_platform) { platform }
    let(:expected_platform_version) { platform_version }
    let(:expected_architecture) { architecture }
    let(:expected_version) { project_version }
    let(:expected_info) do
      record = spec_data_record(expected_channel, expected_project, expected_platform, expected_platform_version, expected_architecture, expected_version)

      {
        url: record['url'],
        sha256: record['sha256'],
        sha1: record['sha1'],
        version: expected_version,
      }
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

          expect(parsed_json['version']).to eq(expected_info[:version])
          expect(parsed_json['url']).to eq(expected_info[:url])
          expect(parsed_json['sha256']).to eq(expected_info[:sha256])
          expect(parsed_json['sha1']).to eq(expected_info[:sha1])
        end

        it "should serve plain text metadata for package" do
          get(endpoint, params, "HTTP_ACCEPT" => "text/plain")
          text_metadata = last_response.body
          parsed_metadata = text_metadata.lines.inject({}) do |metadata, line|
            key, value = line.strip.split("\t")
            metadata[key] = value
            metadata
          end

          expect(parsed_metadata['version']).to eq(expected_info[:version])
          expect(parsed_metadata['url']).to eq(expected_info[:url])
          expect(parsed_metadata['sha256']).to eq(expected_info[:sha256])
          expect(parsed_metadata['sha1']).to eq(expected_info[:sha1])
        end
      end

      context "an incorrect version" do
        let(:endpoint) { "/#{channel}/#{project}/download" }

        context "download" do
          it "should 404" do
            params['v'] = '0.0.0'
            get(endpoint, params)
            expect(last_response).to be_not_found
          end
        end

        context "metadata" do
          let(:endpoint) { "/#{channel}/#{project}/metadata" }
          it "should 404" do
            params['v'] = '0.0.0'
            get(endpoint, params)
            expect(last_response).to be_not_found
          end
        end
      end

      context "an incorrect platform" do
        let(:endpoint) { "/#{channel}/#{project}/download" }

        context "download" do
          it "should 404" do
            params['p'] = 'foo'
            get(endpoint, params)
            expect(last_response).to be_not_found
          end
        end

        context "metadata" do
          let(:endpoint) { "/#{channel}/#{project}/metadata" }
          it "should 404" do
            params['p'] = 'foo'
            get(endpoint, params)
            expect(last_response).to be_not_found
          end
        end
      end
    end

    context 'automate and delivery' do
      let(:channel) { 'stable' }
      let(:platform) { 'el' }
      let(:platform_version) { '6' }
      let(:architecture) { 'x86_64' }

      shared_examples_for 'automate and delivery compatibility' do
        let(:expected_project) { 'automate' }

        context 'without a version' do
          let(:project_version) { nil }
          let(:expected_version) { '1.8.96' }

          it_behaves_like 'a correct package info'
        end

        context 'latest version' do
          let(:project_version) { 'latest' }
          let(:expected_version) { '1.8.96' }

          it_behaves_like 'a correct package info'
        end

        context 'automate version' do
          let(:project_version) { '0.7.61' }

          it_behaves_like 'a correct package info'
        end

        context 'delivery version' do
          let(:project_version) { '0.4.199' }
          let(:expected_project) { 'delivery' }

          it_behaves_like 'a correct package info'
        end
      end

      %w(automate delivery).each do |proj|
        context "for #{proj}" do
          let(:project) { proj }

          it_behaves_like 'automate and delivery compatibility'
        end
      end
    end

    context "for chef" do
      let(:project) { "chef" }

      context 'for stable' do
        let(:channel) { 'stable' }

        context 'for amazon linux' do
          let(:platform) { 'amazon' }
          let(:expected_platform) { 'el' }

          context 'for 2018.03' do
            let(:platform_version) { '2018.03' }
            let(:expected_platform_version) { '6' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chef }

                it_behaves_like 'a correct package info'
              end
            end
          end

          context 'for 2' do
            let(:platform_version) { '2' }
            let(:expected_platform_version) { '7' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chef }

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for mac_os_x' do
          let(:platform) { 'mac_os_x' }

          context 'for 10.7' do
            let(:platform_version) { '10.7' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { '12.2.1' }

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
                let(:expected_version) { '15.2.20' }

                it_behaves_like 'a correct package info'
              end
            end
          end

          context 'for 11.0' do
            let(:platform_version) { '11.0' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chef }

                it_behaves_like 'a correct package info'
              end
            end

            context 'for arm64' do
              let(:architecture) { 'arm64' }
              let(:expected_architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chef }

                it_behaves_like 'a correct package info'
              end
            end
          end

          # We're using the current channel because that currently has the sample data
          context 'with mix of 11.0 and 11' do
            let(:channel) { 'current' }
            let(:architecture) { 'x86_64' }
            let(:project_version) { nil }
            let(:expected_version) { latest_current_chef }

            context 'with 10.x' do
              let(:platform_version) { '10.15' }

              it_behaves_like 'a correct package info'
            end

            context 'with 11.x' do
              let(:platform_version) { '11.0' }
              let(:expected_platform_version) { '11' }

              it_behaves_like 'a correct package info'
            end

            context 'with 11' do
              let(:platform_version) { '11' }

              it_behaves_like 'a correct package info'
            end
          end
        end

        # SLES 11 covers use cases in their entirety.
        # Edge cases and basic platform and project version differences
        # are covered as one-off tests.
        context 'for sles' do
          let(:platform) { 'sles' }

          shared_examples_for 'sles artifacts' do
            let(:expected_platform) { 'sles' }

            context 'for 11' do
              let(:platform_version) { '11' }

              context 'for i686' do
                let(:architecture) { 'i686' }
                let(:expected_platform) { 'el' }
                let(:expected_platform_version) { '5' }
                let(:expected_architecture) { 'i386' }

                context 'with a version' do
                  let(:project_version) { '12.0.3' }

                  it_behaves_like 'a correct package info'
                end
              end

              context 'for s390x' do
                let(:architecture) { 's390x' }

                context 'without a version' do
                  let(:project_version) { nil }
                  let(:expected_version) { '15.1.36' }

                  it_behaves_like 'a correct package info'
                end

                context 'with pre-native sles build version (no remapping)' do
                  let(:project_version) { '12.20.3' }

                  it_behaves_like 'a correct package info'
                end
              end

              context 'for x86_64' do
                let(:architecture) { 'x86_64' }

                context 'without a version' do
                  let(:project_version) { nil }
                  let(:expected_version) { '15.1.36' }

                  it_behaves_like 'a correct package info'
                end

                context 'with latest version' do
                  let(:project_version) { 'latest' }
                  let(:expected_version) { '15.1.36' }

                  it_behaves_like 'a correct package info'
                end

                context 'with first native sles build version' do
                  let(:project_version) { '12.21.1' }

                  it_behaves_like 'a correct package info'
                end

                context 'with non-native sles build version' do
                  let(:project_version) { '12.20.3' }
                  let(:expected_platform) { 'el' }
                  let(:expected_platform_version) { '5' }

                  it_behaves_like 'a correct package info'
                end

                context 'for a latest non-native sles project (manage)' do
                  let(:project) { 'manage' }
                  let(:project_version) { nil }
                  let(:expected_platform) { 'el' }
                  let(:expected_platform_version) { '5' }
                  let(:expected_version) { '2.5.8' }

                  it_behaves_like 'a correct package info'
                end
              end
            end

            context 'for 12' do
              let(:platform_version) { '12' }

              context 'for x86_64' do
                let(:architecture) { 'x86_64'}

                context 'with first native sles build version' do
                  let(:project_version) { '12.21.1' }

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 12 project_version' do
                  let(:project_version) { '12' }
                  let(:expected_version) { '12.22.5' }

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 12.21 project_version' do
                  let(:project_version) { '12.21' }
                  let(:expected_version) { '12.21.31' }

                  it_behaves_like 'a correct package info'
                end

                context 'with non-native sles build version partial version 12.20' do
                  let(:project_version) { '12.20' }
                  let(:expected_version) { '12.20.3' }
                  let(:expected_platform) { 'el' }
                  let(:expected_platform_version) { '6' }
                  let(:expected_architecture) { 'x86_64' }

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 13 project_version' do
                  let(:project_version) { '13' }
                  let(:expected_version) { '13.12.14' }

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 13.1 project_version' do
                  let(:project_version) { '13.1' }
                  let(:expected_version) { '13.1.31' }

                  it_behaves_like 'a correct package info'
                end

                context 'with 13.1.31 project_version' do
                  let(:project_version) { '13.1.31' }

                  it_behaves_like 'a correct package info'
                end

                context 'with non-native sles build version' do
                  let(:project_version) { '12.20.3' }
                  let(:expected_platform) { 'el' }
                  let(:expected_platform_version) { '6' }

                  it_behaves_like 'a correct package info'
                end

                context 'for automate' do
                  let(:project) { 'automate' }

                  context 'with first native sles build version' do
                    let(:project_version) { '0.8.5' }

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '0.7.61' }
                    let(:expected_platform) { 'el' }
                    let(:expected_platform_version) { '6' }

                    it_behaves_like 'a correct package info'
                  end
                end

                context 'for chef-server' do
                  let(:project) { 'chef-server' }

                  context 'with first native sles build version' do
                    let(:project_version) { '12.15.0' }

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '12.13.0' }
                    let(:expected_platform) { 'el' }
                    let(:expected_platform_version) { '6' }

                    it_behaves_like 'a correct package info'
                  end
                end

                context 'for chefdk' do
                  let(:project) { 'chefdk' }

                  context 'with first native sles build version' do
                    let(:project_version) { '1.3.43' }

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '1.3.40' }
                    let(:expected_platform) { 'el' }
                    let(:expected_platform_version) { '6' }

                    it_behaves_like 'a correct package info'
                  end
                end

                context 'for inspec' do
                  let(:project) { 'inspec' }

                  context 'with first native sles build version' do
                    let(:project_version) { '1.20.0' }

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '1.19.2' }
                    let(:expected_platform) { 'el' }
                    let(:expected_platform_version) { '6' }

                    it_behaves_like 'a correct package info'
                  end
                end
              end
            end
          end

          it_behaves_like 'sles artifacts'

          context 'when suse' do
            let(:platform) { 'suse' }

            it_behaves_like 'sles artifacts'
          end

          context 'when opensuse-leap' do
            let(:platform) { 'opensuse-leap' }

            it_behaves_like 'sles artifacts'
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
                let(:expected_version) { '13.4.24' }

                it_behaves_like 'a correct package info'
              end

              context 'with "latest"' do
                let(:project_version) { 'latest' }
                let(:expected_version) { '13.4.24' }

                it_behaves_like 'a correct package info'
              end

              context 'with partial version' do
                let(:project_version) { '12.1' }
                let(:expected_version) { '12.1.2' }

                it_behaves_like 'a correct package info'
              end

              context 'with full version' do
                let(:project_version) { '10.24.0' }

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
                let(:expected_version) { '15.1.36' }

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
            let(:expected_platform_version) { '20.04' }

            context 'for i686' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chef }

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for windows' do
          let(:platform) { 'windows' }
          let(:x86_64_only) { %w{ 8 } }

          %w{
            2019
            2016
            2012
            2012r2
            10
            8
          }.each do |windows_platform_version|

            context "for #{windows_platform_version}" do
              let(:platform_version) { windows_platform_version }

              %w{
                i386
                i686
              }.each do |architecture|

                context "for #{architecture}" do
                  let(:architecture) { architecture }
                  let(:expected_architecture) { 'i386' }
                  let(:expected_platform_version) { (windows_platform_version == '2012') ? '2012' : '2012r2' }

                  context 'with specific version' do
                    let(:project_version) { '12.6.0' }

                    it_behaves_like 'a correct package info'
                  end

                  context 'with only a partial version specification' do
                    let(:project_version) { '12.9' }
                    let(:expected_version) { '12.9.41' }

                    it_behaves_like 'a correct package info'
                  end

                  context 'with specific version that has an x86_64 package' do
                    let(:project_version) { '12.7.2' }

                    it_behaves_like 'a correct package info'
                  end
                end
              end

              context "for x86_64" do
                let(:architecture) { "x86_64" }
                let(:exepcted_platform_version) { windows_platform_version }

                context 'without a version' do
                  let(:project_version) { nil }
                  let(:expected_version) { latest_stable_chef }

                  it_behaves_like 'a correct package info'
                end

                context 'with specific version that has an x86_64 package' do
                  let(:project_version) { '15.12.22' }

                  it_behaves_like 'a correct package info'
                end

                context 'with a version only specifying major' do
                  let(:project_version) { "15" }
                  let(:expected_version) { '15.15.1' }

                  it_behaves_like 'a correct package info'
                end

                context 'with a version only specifing major and minor' do
                  let(:project_version) { "15.12" }
                  let(:expected_version) { '15.12.22' }

                  it_behaves_like 'a correct package info'
                end
              end
            end
          end

          [nil, "12", "13.10", "15.0.300"].each do |v|
            context "for version #{v}" do
              let(:project_version) { v }

              context 'with 32 and 64 bit artifacts' do
                let(:platform_version) { "2008r2" }
                let(:endpoint) { "/#{channel}/#{project}/metadata" }

                %w{i386 i686}.each do |arch|
                  context "for #{arch}" do
                    let(:architecture) { arch }

                    it 'should return 32 bit artifact' do
                      get(endpoint, params, "HTTP_ACCEPT" => "application/json")
                      metadata_json = last_response.body
                      parsed_json = JSON.parse(metadata_json)

                      expect(parsed_json['url']).to match(/x86/)
                      expect(parsed_json['url']).not_to match(/i686/)
                      expect(parsed_json['url']).not_to match(/x86_64/)
                    end
                  end
                end

                context "for x86_64" do
                  let(:architecture) { "x86_64" }

                  it 'should return 64 bit artifact' do
                    get(endpoint, params, "HTTP_ACCEPT" => "application/json")
                    metadata_json = last_response.body
                    parsed_json = JSON.parse(metadata_json)

                    expect(parsed_json['url']).not_to match(/i386/)
                    expect(parsed_json['url']).not_to match(/i686/)
                    expect(parsed_json['url']).to match(/x64/)
                  end
                end
              end
            end
          end
        end

        context 'for nexus' do
          let(:platform) { 'nexus' }

          context 'for 7.0(3)I2(2)' do
            let(:platform_version) { '7.0(3)I2(2)' }
            let(:expected_platform_version) { '7' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { '12.19.33' }

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for fedora' do
          let(:platform) { 'fedora' }
          let(:expected_platform) { 'el' }

          context 'for 14 (Arista!)' do
            let(:platform_version) { '14' }
            let(:expected_platform_version) { '6' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chef }

                it_behaves_like 'a correct package info'
              end
            end
          end

          context 'for 28' do
            let(:platform_version) { '28' }
            let(:expected_platform_version) { '7' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chef }

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for ios_xr' do
          let(:platform) { 'ios_xr' }

          context 'for 6.0.0.14I' do
            let(:platform_version) { '6.0.0.14I' }
            let(:expected_platform_version) { '6' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { '12.19.33' }

                it_behaves_like 'a correct package info'
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
              let(:expected_architecture) { 'sparc' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_current_chef }

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
            let(:expected_platform_version) { '10' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_stable_chefdk }

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

          context 'for 10.13' do
            let(:platform_version) { '10.13' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { latest_current_chefdk }

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
                let(:expected_version) { latest_stable_chef_server }

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end
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
                let(:expected_version) { '12.18.31' }

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end

      context 'for stable' do
        let(:channel) { 'stable' }

        context 'for freebsd' do
          let(:platform) { 'freebsd' }

          context 'for 10' do
            let(:platform_version) { '10' }

            context 'for amd64' do
              let(:architecture) { 'amd64' }
              let(:expected_architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_version) { '15.0.293' }

                it_behaves_like 'a correct package info'
              end
            end
          end
        end
      end
    end

    # We need to return all versions of 64-bit artifacts on stable channel
    # except chef after a specific version.
    context "for AngryChef 64-bit artifacts" do
      let(:project) { "angrychef" }
      let(:channel) { 'stable' }
      let(:platform) { 'windows' }
      let(:platform_version) { '2008r2' }
      let(:architecture) { 'x86_64' }
      let(:project_version) { '12.9.38' }

      it_behaves_like 'a correct package info'
    end

  end

  context '/<CHANNEL>/<PROJECT>/packages endpoint' do
    real_projects.each do |project|
      context "for #{project}" do
        let(:endpoint){ "/stable/#{project}/packages" }

        it "exists" do
          get(endpoint)
          expect(last_response).to be_ok
        end

        it "returns the correct JSON data" do
          get(endpoint)
          expect(last_response.header['Content-Type']).to include 'application/json'
          response = JSON.parse(last_response.body)
          # automate/delivery manifests are identical. latest artifacts will always be automate
          project = 'automate' if project == 'delivery'
          expect(last_response.body).to match(project) unless response.empty?
        end
      end
    end

    # Let's test with chefdk because chef manifest have a 12.6.1 entry in it which
    # limits the information we are getting out of this endpoint.
    context "for stable chefdk" do
      let(:endpoint) { '/stable/chefdk/packages' }
      let(:params) { { v: version } }
      let(:versions_output) {
        get(endpoint, params)
        metadata_json = last_response.body
        JSON.parse(metadata_json)
      }

      [ nil, 'latest'].each do |version|
        context "with version #{version.inspect}" do
          let(:version) { version }

          it 'returns the latest version for each platform, platform_version and architecture' do
            expect(versions_output.keys.length).to eq(6)

            versions_output.each do |p, data|
              data.each do |pv, data|
                data.each do |m, metadata|
                  expect(metadata['sha1']).to match /^[0-9a-f]{40}$/
                  expect(metadata['sha256']).to match /^[0-9a-f]{64}$/
                  expect(metadata['url']).to match 'http'
                  expect(metadata['version']).to eq(latest_stable_chefdk)
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
                expect(metadata['sha1']).to match /^[0-9a-f]{40}$/
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
                expect(metadata['sha1']).to match /^[0-9a-f]{40}$/
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
      let(:endpoint) { '/current/chefdk/packages' }
      let(:params) { { v: version } }
      let(:versions_output) {
        get(endpoint, params)
        metadata_json = last_response.body
        JSON.parse(metadata_json)
      }
    end
  end

  context '/<CHANNEL>/<PROJECT>/versions/all endpoint' do
    real_projects.each do |project|
      context "for #{project}" do
        let(:endpoint){ "/stable/#{project}/versions/all" }

        it "exists" do
          get(endpoint)
          expect(last_response).to be_ok
        end

        it "returns the correct JSON data" do
          get(endpoint)
          expect(last_response.header['Content-Type']).to include 'application/json'
          response = JSON.parse(last_response.body)
          expect(response).to be_an_instance_of(Array)
          expect(response.length).to be > 1
        end
      end
    end
  end

  context '/<CHANNEL>/<PROJECT>/versions/latest endpoint' do
    real_projects.each do |project|
      context "for #{project}" do
        let(:endpoint){ "/stable/#{project}/versions/latest" }

        it "exists" do
          get(endpoint)
          expect(last_response).to be_ok
        end

        it "returns the correct JSON data" do
          get(endpoint)
          expect(last_response.header['Content-Type']).to include 'application/json'
          response = JSON.parse(last_response.body)
          expect(response).to be_an_instance_of(String)
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
    let(:expected_timestamp) do
      JSON.parse(File.read(File.join(SPEC_DATA, "stable/chef-manifest.json")))["run_data"]["timestamp"]
    end

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
      expect(JSON.parse(last_response.body)["timestamp"]).to eq(expected_timestamp)
    end
  end

  context "legacy behavior" do
    let(:prerelease){ nil }
    let(:nightlies){ nil }

    let(:params) do
      params = {}
      params[:p] = 'ubuntu'
      params[:pv] = '16.04'
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
          expect(last_response.body).to match("https://packages.chef.io/files/current")
        end
      end

    end

    {
      '/download' => spec_data_record('stable', 'chef', 'ubuntu', '16.04', 'x86_64', latest_stable_chef)['url'],
      '/download-server' => spec_data_record('stable', 'chef-server', 'ubuntu', '16.04', 'x86_64', latest_stable_chef_server)['url'],
      '/chef/download-server' => spec_data_record('stable', 'chef-server', 'ubuntu', '16.04', 'x86_64', latest_stable_chef_server)['url'],
      '/metadata' => spec_data_record('stable', 'chef', 'ubuntu', '16.04', 'x86_64', latest_stable_chef).merge({ 'version' => latest_stable_chef }),
      '/metadata-server' => spec_data_record('stable', 'chef-server', 'ubuntu', '16.04', 'x86_64', latest_stable_chef_server).merge({ 'version' => latest_stable_chef_server }),
      '/chef/metadata-server' => spec_data_record('stable', 'chef-server', 'ubuntu', '16.04', 'x86_64', latest_stable_chef_server).merge({ 'version' => latest_stable_chef_server }),
      '/chef/install.msi' => 'http://example.org/stable/chef/download?p=windows&pv=2008r2&m=i386',
      '/install.msi' => 'http://example.org/stable/chef/download?p=windows&pv=2008r2&m=i386',
      '/full_client_list' => nil,
      '/full_list' => nil,
      '/full_server_list' => nil,
      '/chef/full_client_list' => nil,
      '/chef/full_list' => nil,
      '/chef/full_server_list' => nil,
      '/chef_platform_names' => nil,
      '/chef_server_platform_names' => nil,
      '/chef/chef_platform_names' => nil,
      '/chef/chef_server_platform_names' => nil,
      '/full_chefdk_list' => nil,
      '/full_server_list' => nil,
    }.each do |legacy_endpoint, response_match_data|

      context "legacy endpoint #{legacy_endpoint}" do
        let(:endpoint) { legacy_endpoint }

        it "returns the correct response data" do
          get(endpoint, params)

          if legacy_endpoint =~ /download/ || legacy_endpoint =~ /install\.msi/
            follow_redirect!
            expect(last_request.url).to match(response_match_data)
          elsif legacy_endpoint =~ /metadata/
            parsed_metadata = last_response.body.lines.inject({}) do |metadata, line|
              key, value = line.strip.split("\t")
              metadata[key] = value
              metadata
            end

            expect(parsed_metadata['version']).to eq(response_match_data['version'])
            expect(parsed_metadata['url']).to eq(response_match_data['url'])
            expect(parsed_metadata['sha256']).to eq(response_match_data['sha256'])
            expect(parsed_metadata['sha1']).to eq(response_match_data['sha1'])
          elsif legacy_endpoint =~ /platform_names/
            # we check that response is valid JSON.
            expect{JSON.parse(last_response.body)}.not_to raise_error
          else
            parsed_json = JSON.parse(last_response.body)

            # we check a certain hash structure that needs to be present in these endpoints
            parsed_json.each do |platform, data|
              data.each do |platform_version, data|
                data.each do |architecture, metadata|
                  expect(metadata['url']).to be_a(String)
                  expect(metadata['sha1']).to be_a(String)
                  expect(metadata['sha256']).to be_a(String)
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
