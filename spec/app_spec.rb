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

  context "products endpoint" do
    it "returns all the products" do
      get("/products")

      response = JSON.parse(last_response.body)
      Chef::Cache::KNOWN_PROJECTS.each do |project|
        response.include?(project)
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
          expect(parsed_json['sha1']).to eq(expected_info[:sha1])
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
          expect(parsed_metadata['sha1']).to eq(expected_info[:sha1])
          expect(parsed_metadata['version']).to eq(expected_info[:version])
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
        context 'without a version' do
          let(:project_version) { nil }
          let(:expected_info) do
            {
              url: 'https://packages.chef.io/files/stable/automate/0.8.5/el/6/automate-0.8.5-1.el6.x86_64.rpm',
              sha256: '8819f97aa63f2ae917aab184e3f76db172ffd580175c680bdcab8d98e40e9234',
              sha1: 'e570e12d3c909896a897b664096e1b6020f3b0aa',
              version: '0.8.5'
            }
          end

          it_behaves_like 'a correct package info'
        end

        context 'latest version' do
          let(:project_version) { 'latest' }
          let(:expected_info) do
            {
              url: 'https://packages.chef.io/files/stable/automate/0.8.5/el/6/automate-0.8.5-1.el6.x86_64.rpm',
              sha256: '8819f97aa63f2ae917aab184e3f76db172ffd580175c680bdcab8d98e40e9234',
              sha1: 'e570e12d3c909896a897b664096e1b6020f3b0aa',
              version: '0.8.5'
            }
          end

          it_behaves_like 'a correct package info'
        end

        context 'automate version' do
          let(:project_version) { '0.7.61' }
          let(:expected_info) do
            {
              url: 'https://packages.chef.io/files/stable/automate/0.7.61/el/6/automate-0.7.61-1.el6.x86_64.rpm',
              sha256: '3f4e43d46b7e0f0e8e767d90e490ad3a1b851457905d6d0d3b3103d8794f045e',
              sha1: 'b2c09fe004dff285c2a522b552938de3bcecf233',
              version: '0.7.61'
            }
          end

          it_behaves_like 'a correct package info'
        end

        context 'delivery version' do
          let(:project_version) { '0.4.199' }
          let(:expected_info) do
            {
              url: 'https://packages.chef.io/files/stable/delivery/0.4.199/el/6/delivery-0.4.199-1.el6.x86_64.rpm',
              sha256: '8d2b908352459033748e6fb9e82e4554f35097a30ad81769d0eba2be3b3c5391',
              sha1: 'f515826ef21192ca33be39771228e1af1c2e7c10',
              version: '0.4.199'
            }
          end

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
                    url: 'https://packages.chef.io/files/stable/chef/12.2.1/mac_os_x/10.7/chef-12.2.1-1.dmg',
                    sha256: '53034d6e1eea0028666caee43b99f43d2ca9dd24b260bc53ae5fad1075e83923',
                    sha1: '57e1b5ef88d0faced5fa68f548d9d827297793d0',
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
                    url: 'https://packages.chef.io/files/stable/chef/13.1.31/mac_os_x/10.12/chef-13.1.31-1.dmg',
                    sha256: '89e36a8fb39104b99dcc591b53264dc58272169fb653d487472c16e8479f1361',
                    sha1: '4b4537616f038cf1941dba42988ba64caa984635',
                    version: '13.1.31'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        # SLES 11 covers use cases in their entirety.
        # Edge cases and basic platform and project version differences
        # are covered as one-off tests.
        context 'for sles' do
          let(:platform) { 'sles' }

          shared_examples_for 'sles artifacts' do

            context 'for 11' do
              let(:platform_version) { '11' }

              context 'for i686' do
                let(:architecture) { 'i686' }

                context 'with a version' do
                  let(:project_version) { '12.0.3' }
                  let(:expected_info) do
                    {
                      url: 'http://packages.chef.io/files/stable/chef/12.0.3/el/5/chef-12.0.3-1.i686.rpm',
                      sha256: '3fb6a9c26af0cc684aa82245b142d6b30ccc5573e9e9cd2dffec0d4e1f671648',
                      sha1: '724ac9fa973e2d34ff02e54111de96dfa73e86c6',
                      version: '12.0.3'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end
              end

              context 'for s390x' do
                let(:architecture) { 's390x' }

                context 'without a version' do
                  let(:project_version) { nil }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/13.1.31/sles/11/chef-13.1.31-1.sles11.s390x.rpm',
                      sha256: '1d830d9a195947f6abe616ac5890f50a5dbb9e7962f13614c1bd22e3118adef7',
                      sha1: '94880c2e0dbe4c9f5b3e334e81b73466cd334a2a',
                      version: '13.1.31'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with pre-native sles build version (no remapping)' do
                  let(:project_version) { '12.20.3' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.20.3/sles/11/chef-12.20.3-1.sles11.s390x.rpm',
                      sha256: '220f0ba4c364d8da16fef6299e08026b76befc786bb4bd9c489cec4d32bcf2e1',
                      sha1: '1922315d51bbeb23b96bde1dc8926b89b6e1668f',
                      version: '12.20.3'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end
              end

              context 'for x86_64' do
                let(:architecture) { 'x86_64' }

                context 'without a version' do
                  let(:project_version) { nil }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/13.1.31/sles/11/chef-13.1.31-1.sles11.x86_64.rpm',
                      sha256: '223878bf9d98a5c42376484608bd293ff472dc4a307318a49a29112932503adb',
                      sha1: 'ef3fc2debe67fea27e9fff2d685b6e37b51a02a6',
                      version: '13.1.31'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with latest version' do
                  let(:project_version) { 'latest' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/13.1.31/sles/11/chef-13.1.31-1.sles11.x86_64.rpm',
                      sha256: '223878bf9d98a5c42376484608bd293ff472dc4a307318a49a29112932503adb',
                      sha1: 'ef3fc2debe67fea27e9fff2d685b6e37b51a02a6',
                      version: '13.1.31'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with first native sles build version' do
                  let(:project_version) { '12.21.1' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.21.1/sles/11/chef-12.21.1-1.sles11.x86_64.rpm',
                      sha256: 'db1d33e8ee5ecc7018b7d0326a5a86b89dcf7f8f73dd26a502becfd6647845eb',
                      sha1: 'da8d8cdd37bbe77700b73d2c81c0b1352582baa3',
                      version: '12.21.1'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with non-native sles build version' do
                  let(:project_version) { '12.20.3' }
                  let(:expected_info) do
                    {
                      url: 'http://packages.chef.io/files/stable/chef/12.20.3/el/5/chef-12.20.3-1.el5.x86_64.rpm',
                      sha256: '1da12ea03604dae3c2ffe77e7c5bf65ed4fccb5d04b3d46423cf6b448208ba65',
                      sha1: '0cf57a2971829e5183baf9426ecf5a33bb2327d5',
                      version: '12.20.3'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'for a latest non-native sles project (manage)' do
                  let(:project) { 'manage' }
                  let(:project_version) { nil }
                  let(:expected_info) do
                    {
                      url: 'http://packages.chef.io/files/stable/chef-manage/2.5.4/el/5/chef-manage-2.5.4-1.el5.x86_64.rpm',
                      sha256: 'c5367f6dbd6b4c08fa11fa589d21b1aacc52e6bd848dc6b1c1cadb7fcd5f59fd',
                      sha1: '0a0e4ec206ec02fe0d23e2759c30e1e0607c1064',
                      version: '2.5.4'
                    }
                  end

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
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.21.1/sles/12/chef-12.21.1-1.sles12.x86_64.rpm',
                      sha256: 'e8705a564e6687e492eca401a5af9613012b991fbe6eba58c414eaedf575d232',
                      sha1: '3d4c90c9b8a2168ba067b89c8c127b21202d8ed1',
                      version: '12.21.1'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 12 project_version' do
                  let(:project_version) { '12' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.21.1/sles/12/chef-12.21.1-1.sles12.x86_64.rpm',
                      sha256: 'e8705a564e6687e492eca401a5af9613012b991fbe6eba58c414eaedf575d232',
                      sha1: '3d4c90c9b8a2168ba067b89c8c127b21202d8ed1',
                      version: '12.21.1'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 12.21 project_version' do
                  let(:project_version) { '12.21' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.21.1/sles/12/chef-12.21.1-1.sles12.x86_64.rpm',
                      sha256: 'e8705a564e6687e492eca401a5af9613012b991fbe6eba58c414eaedf575d232',
                      sha1: '3d4c90c9b8a2168ba067b89c8c127b21202d8ed1',
                      version: '12.21.1'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with non-native sles build version partial version 12.20' do
                  let(:project_version) { '12.20' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.20.3/el/6/chef-12.20.3-1.el6.x86_64.rpm',
                      sha256: '1a0a1e830f95e21bad222b1984cd32e2e76cd856aaf194be27be4b0ad607d1c1',
                      sha1: '06fb16af659a456bab75f1a79733ca7bbd29edf3',
                      version: '12.20.3'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 13 project_version' do
                  let(:project_version) { '13' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/13.1.31/sles/12/chef-13.1.31-1.sles12.x86_64.rpm',
                      sha256: '9f7989cc1207b599dcb13c17bec5bc95073b6c58d76606b4583bda353577ec72',
                      sha1: 'e2625726ae2a8ce6db8b0ffe84091b428185458c',
                      version: '13.1.31'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with partial 13.1 project_version' do
                  let(:project_version) { '13.1' }
                  let(:expected_info) do
                     {
                      url: 'https://packages.chef.io/files/stable/chef/13.1.31/sles/12/chef-13.1.31-1.sles12.x86_64.rpm',
                      sha256: '9f7989cc1207b599dcb13c17bec5bc95073b6c58d76606b4583bda353577ec72',
                      sha1: 'e2625726ae2a8ce6db8b0ffe84091b428185458c',
                      version: '13.1.31'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with 13.1.31 project_version' do
                  let(:project_version) { '13.1.31' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/13.1.31/sles/12/chef-13.1.31-1.sles12.x86_64.rpm',
                      sha256: '9f7989cc1207b599dcb13c17bec5bc95073b6c58d76606b4583bda353577ec72',
                      sha1: 'e2625726ae2a8ce6db8b0ffe84091b428185458c',
                      version: '13.1.31'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with non-native sles build version' do
                  let(:project_version) { '12.20.3' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.20.3/el/6/chef-12.20.3-1.el6.x86_64.rpm',
                      sha256: '1a0a1e830f95e21bad222b1984cd32e2e76cd856aaf194be27be4b0ad607d1c1',
                      sha1: '06fb16af659a456bab75f1a79733ca7bbd29edf3',
                      version: '12.20.3'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'for automate' do
                  let(:project) { 'automate' }

                  context 'with first native sles build version' do
                    let(:project_version) { '0.8.5' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/automate/0.8.5/sles/12/automate-0.8.5-1.sles12.x86_64.rpm',
                        sha256: '09dc068ff7e69264967cad547d79b84b687180b10c40e3713a7660106cf04e10',
                        sha1: '7a57d9f6f026bffb738502f743b881410aa7aa0c',
                        version: '0.8.5'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '0.7.61' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/automate/0.7.61/el/6/automate-0.7.61-1.el6.x86_64.rpm',
                        sha256: '3f4e43d46b7e0f0e8e767d90e490ad3a1b851457905d6d0d3b3103d8794f045e',
                        sha1: 'b2c09fe004dff285c2a522b552938de3bcecf233',
                        version: '0.7.61'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end
                end

                context 'for chef-server' do
                  let(:project) { 'chef-server' }

                  context 'with first native sles build version' do
                    let(:project_version) { '12.15.0' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chef-server/12.15.0/sles/12/chef-server-core-12.15.0-1.sles12.x86_64.rpm',
                        sha256: '7b21f21b47edb47ef2edac8700229dabd2511cbed3a80c18d19a11a9728c8dda',
                        sha1: 'fd9943cefe4d414080afe3c4080d8fd80ddb35f7',
                        version: '12.15.0'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '12.13.0' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chef-server/12.13.0/el/6/chef-server-core-12.13.0-1.el6.x86_64.rpm',
                        sha256: '6e1d0359d5d5db237e5567a74e80e7b8ae63e3d9a59df4f4d1542b348c0281e7',
                        sha1: '66dd986d430684aafe20799491886bb41d8317b0',
                        version: '12.13.0'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end
                end

                context 'for chefdk' do
                  let(:project) { 'chefdk' }

                  context 'with first native sles build version' do
                    let(:project_version) { '1.3.43' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chefdk/1.3.43/sles/12/chefdk-1.3.43-1.sles12.x86_64.rpm',
                        sha256: 'acd50605ce1b691879aaa3077314810444f3142bede7434bb6f9ffa13db8ef13',
                        sha1: '351cbc0384eec6199d1a6771f79fc36520b249e6',
                        version: project_version
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '1.3.40' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chefdk/1.3.40/el/6/chefdk-1.3.40-1.el6.x86_64.rpm',
                        sha256: '6d5d3d74f2aa9c0c55bd8ff74b156a2e68406de8c34f99a6dbd25773bd9856e3',
                        sha1: '81d1c69051b5fa1eddebbaa4d089db4f77510e66',
                        version: project_version
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end
                end

                context 'for inspec' do
                  let(:project) { 'inspec' }

                  context 'with first native sles build version' do
                    let(:project_version) { '1.20.0' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/inspec/1.20.0/sles/12/inspec-1.20.0-1.sles12.x86_64.rpm',
                        sha256: '44a7440375f3a75a2a4733a26b5e391807ed654144bdcaff42f5369a2e80c78f',
                        sha1: '2ac8e14ccbd1741294d624d24f9b2ca93d5e21cc',
                        version: project_version
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with non-native sles build version' do
                    let(:project_version) { '1.19.2' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/inspec/1.19.2/el/6/inspec-1.19.2-1.el6.x86_64.rpm',
                        sha256: '98e90b546a03742c3d706877862f54eee6f2df3f8fa0f504cfc4a809ecc269f0',
                        sha1: '931fa98d83f218a51b389c08bf48b2c2cf485799',
                        version: project_version
                      }
                    end

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
                    url: 'https://packages.chef.io/files/stable/chef/13.1.31/ubuntu/12.04/chef_13.1.31-1_amd64.deb',
                    sha256: 'd8b0a8c012945cda9a2ff1b6b93bd852b06b81c71b4604250dac7c90143fd14d',
                    sha1: '0a9cb607bc5b9189c88a981ee010e1e15a8a9042',
                    version: '13.1.31'
                  }
                end

                it_behaves_like 'a correct package info'
              end

              context 'with "latest"' do
                let(:project_version) { 'latest' }
                let(:expected_info) do
                  {
                    url: 'https://packages.chef.io/files/stable/chef/13.1.31/ubuntu/12.04/chef_13.1.31-1_amd64.deb',
                    sha256: 'd8b0a8c012945cda9a2ff1b6b93bd852b06b81c71b4604250dac7c90143fd14d',
                    sha1: '0a9cb607bc5b9189c88a981ee010e1e15a8a9042',
                    version: '13.1.31'
                  }
                end

                it_behaves_like 'a correct package info'
              end

              context 'with partial version' do
                let(:project_version) { '12.1' }
                let(:expected_info) do
                  {
                    url: 'https://packages.chef.io/files/stable/chef/12.1.2/ubuntu/12.04/chef_12.1.2-1_amd64.deb',
                    sha256: '4a92cdd99d337ac51529ca7fa402e2470e1a4e99a63d4260c81f275e047f4fb4',
                    sha1: 'a20197a38ca24497f99b4975bb9443434e8a43ac',
                    version: '12.1.2'
                  }
                end

                it_behaves_like 'a correct package info'
              end

              context 'with full version' do
                let(:project_version) { '10.24.0' }
                let(:expected_info) do
                  {
                    url: 'https://packages.chef.io/files/stable/chef/10.24.0/ubuntu/12.04/chef_10.24.0-1.ubuntu.11.04_amd64.deb',
                    sha256: '4afb1aae6409a33b511d932ce670d1e1c7c8c69daf36647606d65e6f6ef36313',
                    sha1: 'db28cf433afb5f3f1393513d8c66ba780ecb4e7e',
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
                    url: 'https://packages.chef.io/files/stable/chef/13.1.31/ubuntu/14.04/chef_13.1.31-1_amd64.deb',
                    sha256: 'd8b0a8c012945cda9a2ff1b6b93bd852b06b81c71b4604250dac7c90143fd14d',
                    sha1: '0a9cb607bc5b9189c88a981ee010e1e15a8a9042',
                    version: '13.1.31'
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
                    url: 'https://packages.chef.io/files/stable/chef/13.1.31/ubuntu/16.04/chef_13.1.31-1_amd64.deb',
                    sha256: 'd8b0a8c012945cda9a2ff1b6b93bd852b06b81c71b4604250dac7c90143fd14d',
                    sha1: '0a9cb607bc5b9189c88a981ee010e1e15a8a9042',
                    version: '13.1.31'
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

            context "for #{windows_platform_version}" do
              let(:platform_version) { windows_platform_version }

              %w{i386 i686}.each do |architecture|
                context "for #{architecture}" do
                  let(:architecture) { architecture }

                  context 'without a version' do
                    let(:project_version) { nil }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chef/13.1.31/windows/2012r2/chef-client-13.1.31-1-x86.msi',
                        sha256: '8258a68ad58d056a0070489de2ac3abfcea352598355bdabdfa3c5aa37ff5db9',
                        sha1: '7abd787dd6ed2573bac202b41353462ea5b91c39',
                        version: '13.1.31'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with specific version' do
                    let(:project_version) { '12.6.0' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chef/12.6.0/windows/2012r2/chef-client-12.6.0-1-x86.msi',
                        sha256: '6027cd360f43a2cde90e978ac9891459e8b3b33e4df34cb1a5b78a6c8427c03b',
                        sha1: '2e03235be21742bb6ee64d3d1692b75edbd60aad',
                        version: '12.6.0'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with only a partial version specification' do
                    let(:project_version) { '12.9' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chef/12.9.41/windows/2012r2/chef-client-12.9.41-1-x86.msi',
                        sha256: '89616d496bfc1802f12b37bfd50d813e1aa815fc5c3013b86b2fab5d11dc3abf',
                        sha1: '188df77eeb8ba406215103153c9d113189b30713',
                        version: '12.9.41'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end

                  context 'with specific version that has an x86_64 package' do
                    let(:project_version) { '12.7.2' }
                    let(:expected_info) do
                      {
                        url: 'https://packages.chef.io/files/stable/chef/12.7.2/windows/2012r2/chef-client-12.7.2-1-x86.msi',
                        sha256: 'a430ebbc42c3a49f4ef8715bfc8422620f42eb380a5cd136fe91a5ac5353e8ef',
                        sha1: '8e67a72fa96186f7ef190908a2b238a4c5960033',
                        version: '12.7.2'
                      }
                    end

                    it_behaves_like 'a correct package info'
                  end
                end
              end

              context "for x86_64" do

                let(:architecture) { "x86_64" }

                context 'without a version' do
                  let(:project_version) { nil }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/13.1.31/windows/2012r2/chef-client-13.1.31-1-x64.msi',
                      sha256: '4e55555025a9af26bf77e18ba5aaf262edeaf8acb10580ee3fabff50c83d0d5a',
                      sha1: '730cdd9770297c41c604a81d0be8cdb5c2a068dd',
                      version: '13.1.31'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with specific version without an x86_64 package' do
                  let(:project_version) { '12.6.0' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.6.0/windows/2012r2/chef-client-12.6.0-1-x86.msi',
                      sha256: '6027cd360f43a2cde90e978ac9891459e8b3b33e4df34cb1a5b78a6c8427c03b',
                      sha1: '2e03235be21742bb6ee64d3d1692b75edbd60aad',
                      version: '12.6.0'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with specific version that has an x86_64 package' do
                  let(:project_version) { '12.7.2' }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.7.2/windows/2012r2/chef-client-12.7.2-1-x86.msi',
                      sha256: 'a430ebbc42c3a49f4ef8715bfc8422620f42eb380a5cd136fe91a5ac5353e8ef',
                      sha1: '8e67a72fa96186f7ef190908a2b238a4c5960033',
                      version: '12.7.2'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with a version only specifying major' do
                  let(:project_version) { "12" }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.21.1/windows/2016/chef-client-12.21.1-1-x64.msi',
                      sha256: '46ed24ada86122b411214e632ffc32f5ec3871c5f49808c4418b7d7be1cde56b',
                      sha1: '60f8030f52f3ceb5d4d4cc63156b1f419fadcd25',
                      version: '12.21.1'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end

                context 'with a version only specifing major and minor' do
                  let(:project_version) { "12.9" }
                  let(:expected_info) do
                    {
                      url: 'https://packages.chef.io/files/stable/chef/12.9.41/windows/2012r2/chef-client-12.9.41-1-x64.msi',
                      sha256: '7424b1b1a1043e057478496e92e786335294c9df00e2cb32c65df35e5d2db752',
                      sha1: '80501f6e5fd5a4d606e226b2517bd4cdae335faf',
                      version: '12.9.41'
                    }
                  end

                  it_behaves_like 'a correct package info'
                end
              end

            end
          end
        end

        context 'for nexus' do
          let(:platform) { 'nexus' }

          context 'for 7.0(3)I2(2)' do
            let(:platform_version) { '7.0(3)I2(2)' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://packages.chef.io/files/stable/chef/12.19.33/nexus/7/chef-12.19.33-1.nexus7.x86_64.rpm',
                    sha256: '46abe5cafba112f18b69f13f69ae4c1e85d5d1b789617d7272aca1e02d6c07eb',
                    sha1: '728a8154c3b6b5610760fd65dd0e22513e7e1f22',
                    version: '12.19.33'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for ios_xr' do
          let(:platform) { 'ios_xr' }

          context 'for 6.0.0.14I' do
            let(:platform_version) { '6.0.0.14I' }

            context 'for x86_64' do
              let(:architecture) { 'x86_64' }

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://packages.chef.io/files/stable/chef/12.19.33/ios_xr/6/chef-12.19.33-1.ios_xr6.x86_64.rpm',
                    sha256: '924e93d8131abe1b2ca98639fc029122334b11fbfbca869e47001957d880bd7c',
                    sha1: 'ea51646c2e7de5d188084683e9ef6b9444a55099',
                    version: '12.19.33'
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
                    url: 'https://packages.chef.io/files/current/chef/13.2.18/solaris2/5.11/chef-13.2.18-1.sparc.p5p',
                    sha256: '0fa6e9e335ec80004095ba663426fad01b04c345f88467e247afd329b69809b3',
                    sha1: '6311a636afea51fe37dece6bf0a01c522d31dafc',
                    version: '13.2.18'
                  }
                end

                it_behaves_like 'a correct package info'
              end
            end
          end
        end

        context 'for windows' do
          let(:platform) { 'windows' }

          [nil, "11", "12.6", "12.9.3"].each do |v|
            context "for version #{v}" do
              let(:platform_version) { v }

              context 'current channel with 32 and 64 bit artifacts' do
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
                    url: 'https://packages.chef.io/files/stable/chefdk/1.5.0/windows/2016/chefdk-1.5.0-1-x86.msi',
                    sha256: '7734cfee178edce3c91e310a4d24fdffe77e9c7a78d919084fb2c762739d1c6f',
                    sha1: 'a65e661239754c3234c0f103f5e3511cce793745',
                    version: '1.5.0'
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
                    url: 'https://packages.chef.io/files/current/chefdk/2.0.12/mac_os_x/10.10/chefdk-2.0.12-1.dmg',
                    sha256: '026bd22e0e3e66f01dffdec1d5f2ecf6b9f57741aa4a9cbfe55fabc1d5a57b76',
                    sha1: '4de71158120fcff730ff0bec0260ee870be1a1c7',
                    version: '2.0.12'
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
                    url: 'https://packages.chef.io/files/stable/chef-server/12.15.8/el/6/chef-server-core-12.15.8-1.el6.x86_64.rpm',
                    sha256: 'cb0e1c7dae13526360d75f35625d8794ce641cc399bc084c0bd6b37a757b19f2',
                    sha1: '0e0d2bd29e3b53ebbb9e12cdd3f40fcd4e027499',
                    version: '12.15.8'
                  }
                end

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
                let(:expected_info) do
                  {
                    url: 'https://packages.chef.io/files/stable/angrychef/12.18.31/debian/6/angrychef_12.18.31-1_amd64.deb',
                    sha256: '95888d49c14f9171a2fb29ca8224dc75a2be45992ba18f3fcc64c559d0ecfb1e',
                    sha1: 'b988409b36fcce650a449b8844a336842e4f3f84',
                    version: '12.18.31'
                  }
                end

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

              context 'without a version' do
                let(:project_version) { nil }
                let(:expected_info) do
                  {
                    url: 'https://packages.chef.io/files/stable/angrychef/12.18.31/freebsd/10/angrychef-12.18.31_1.amd64.sh',
                    sha256: '78951411d0ca441a5c07f63d6554456e8f192a98e19124d77f0c94feddda4d77',
                    sha1: '0abb0020733b6a709637a91abfff1656b6597b7a',
                    version: '12.18.31'
                  }
                end

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
      let(:expected_info) do
        {
          url: 'https://packages.chef.io/files/stable/angrychef/12.9.38/windows/2012r2/angrychef-12.9.38-1-x64.msi',
          sha256: '841d6bfc20fb89f7eaa61820d0f5d44bc60e0d67631a58e2920440974e7cba2b',
          sha1: 'aa83af2ecdb6cbec643c1fda1d69c55834e692c2',
          version: '12.9.38'
        }
      end

      it_behaves_like 'a correct package info'
    end

  end

  context '/<CHANNEL>/<PROJECT>/versions endpoint' do
    Chef::Cache::KNOWN_PROJECTS.each do |project|
      context "for #{project}" do
        let(:endpoint){ "/stable/#{project}/versions" }

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
      let(:endpoint) { '/stable/chefdk/versions' }
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
                  expect(metadata['version']).to eq('1.5.0')
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
      let(:endpoint) { '/current/chefdk/versions' }
      let(:params) { { v: version } }
      let(:versions_output) {
        get(endpoint, params)
        metadata_json = last_response.body
        JSON.parse(metadata_json)
      }
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
      expect(JSON.parse(last_response.body)["timestamp"]).to eq("2017-06-22 12:02:57 -0700")
    end
  end

  context "legacy behavior" do
    let(:prerelease){ nil }
    let(:nightlies){ nil }

    let(:params) do
      params = {}
      params[:p] = 'ubuntu'
      params[:pv] = '12.04'
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
      '/download' => 'https://packages.chef.io/files/stable/chef/13.1.31/ubuntu/12.04/chef_13.1.31-1_amd64.deb',
      '/download-server' => 'https://packages.chef.io/files/stable/chef-server/12.15.8/ubuntu/12.04/chef-server-core_12.15.8-1_amd64.deb',
      '/chef/download-server' => 'https://packages.chef.io/files/stable/chef-server/12.15.8/ubuntu/12.04/chef-server-core_12.15.8-1_amd64.deb',
      '/metadata' => {
        url: 'https://packages.chef.io/files/stable/chef/13.1.31/ubuntu/12.04/chef_13.1.31-1_amd64.deb',
        sha256: 'd8b0a8c012945cda9a2ff1b6b93bd852b06b81c71b4604250dac7c90143fd14d',
        sha1: '0a9cb607bc5b9189c88a981ee010e1e15a8a9042',
        version: '13.1.31'
      },
      '/metadata-server' => {
        url: 'https://packages.chef.io/files/stable/chef-server/12.15.8/ubuntu/12.04/chef-server-core_12.15.8-1_amd64.deb',
        sha256: '4351cc42f344292bb89b8d252b66364e79d0eb271967ef9f5debcbf3a5a6faae',
        sha1: '23afe6f682697caa616dc810558a717962fc57b6',
        version: '12.15.8'
      },
      '/chef/metadata-server' => {
        url: 'https://packages.chef.io/files/stable/chef-server/12.15.8/ubuntu/12.04/chef-server-core_12.15.8-1_amd64.deb',
        sha256: '4351cc42f344292bb89b8d252b66364e79d0eb271967ef9f5debcbf3a5a6faae',
        sha1: '23afe6f682697caa616dc810558a717962fc57b6',
        version: '12.15.8'
      },
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

            expect(parsed_metadata['url']).to eq(response_match_data[:url])
            expect(parsed_metadata['sha256']).to eq(response_match_data[:sha256])
            expect(parsed_metadata['sha1']).to eq(response_match_data[:sha1])
            expect(parsed_metadata['version']).to eq(response_match_data[:version])
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
