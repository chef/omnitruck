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

describe 'Omnitruck' do
  def app
    Omnitruck
  end

  describe "download endpoints" do

    # This really sucks but the git describe string embedded in package names differs
    # between platforms. For example:
    #
    #    ubuntu -> chef_10.16.2-49-g21353f0-1.ubuntu.11.04_amd64.deb
    #    el     -> chef-10.16.2_49_g21353f0-1.el5.x86_64.rpm
    #
    def url_regex_for(expected_version)
      expected_version_variations = Regexp.escape(expected_version).gsub(/\\-|_/, "[_-]")
      expected_version_variations.gsub!(/\+/, "%2B")
      mapped_platform =  alt_platform ? alt_platform : platform
      mapped_platform_version = alt_platform_version ? alt_platform_version : platform_version
      if mapped_platform =~ /windows/
        omg_stupid_windows_project = project == 'chef' ? "chef-client" : project
        /#{Regexp.escape(omnitruck_host_path)}\/#{Regexp.escape(mapped_platform)}\/#{Regexp.escape(mapped_platform_version)}\/#{Regexp.escape(architecture)}\/#{Regexp.escape(omg_stupid_windows_project)}[-_]#{expected_version_variations}\-#{iteration_number}\.#{Regexp.escape(mapped_platform)}\.#{package_type}/
      elsif mapped_platform =~ /mac_os_x/
        /#{Regexp.escape(omnitruck_host_path)}\/#{Regexp.escape(mapped_platform)}\/#{Regexp.escape(mapped_platform_version[/^\d+\.\d/])}\/#{Regexp.escape(architecture)}\/#{Regexp.escape(project)}[-_]#{expected_version_variations}[-_]#{iteration_number}\.#{Regexp.escape(mapped_platform)}\.?#{Regexp.escape(mapped_platform_version)}\.#{package_type}/
      else
        /#{Regexp.escape(omnitruck_host_path)}\/#{Regexp.escape(mapped_platform)}\/#{Regexp.escape(mapped_platform_version)}\/#{Regexp.escape(architecture)}\/#{Regexp.escape(project)}[-_]#{expected_version_variations}\-#{iteration_number}\.#{Regexp.escape(mapped_platform)}\.?#{Regexp.escape(mapped_platform_version)}[._]#{Regexp.escape(architecture_alt)}\.#{package_type}/
      end
    end

    def self.should_retrieve_latest_metadata_as(expected_version, options={})
      let(:iteration_number){ options[:iteration] || 1}
      let(:expected_md5) { options[:md5] }
      let(:expected_sha256) { options[:sha256] }
      let(:expected_version) { options[:version] }
      let(:http_type_string) { "http" }
      let(:omnitruck_host_path)  { "#{http_type_string}://#{Omnitruck.aws_packages_bucket}.s3.amazonaws.com" }

      it "should serve JSON metadata with a URI for package #{expected_version}" do
        get(metadata_endpoint, params, "HTTP_ACCEPT" => "application/json")
        metadata_json = last_response.body
        parsed_json = JSON.parse(metadata_json)

        pkg_url = parsed_json["url"]
        expect(pkg_url).to match(url_regex_for(expected_version))

        expect(parsed_json["sha256"]).to eq(expected_sha256)
        expect(parsed_json["md5"]).to eq(expected_md5)
        expect(parsed_json["version"]).to eq(expected_version)
      end

      it "should serve plain text metadata with a URI for package #{expected_version}" do
        get(metadata_endpoint, params, "HTTP_ACCEPT" => "text/plain")
        text_metadata = last_response.body
        parsed_metadata = text_metadata.lines.inject({}) do |metadata, line|
          key, value = line.strip.split("\t")
          metadata[key] = value
          metadata
        end

        pkg_url = parsed_metadata["url"]
        expect(pkg_url).to match(url_regex_for(expected_version))

        expect(parsed_metadata["sha256"]).to eq(expected_sha256)
        expect(parsed_metadata["md5"]).to eq(expected_md5)
        expect(parsed_metadata["version"]).not_to be_nil
      end
    end

    def self.should_retrieve_latest_as(expected_version, options={})
      let(:iteration_number){ options[:iteration] || 1}
      let(:expected_md5) { options[:md5] }
      let(:expected_sha256) { options[:sha256] }
      let(:http_type_string) { "http" }
      let(:omnitruck_host_path)  { "#{http_type_string}://#{Omnitruck.aws_packages_bucket}.s3.amazonaws.com" }

      it "should serve a redirect to the correct URI for package #{expected_version}" do
        get(endpoint, params)
        expect(last_response).to be_redirect
        follow_redirect!

        expect(last_request.url).to match(url_regex_for(expected_version))
      end

      should_retrieve_latest_metadata_as(expected_version, options)
    end

    # Helper lets to make parameter declaration and handling easier
    let(:platform){ nil }
    let(:alt_platform){ nil }
    let(:package_type){ nil }
    let(:platform_version){ nil }
    let(:alt_platform_version){ nil }
    let(:architecture){ nil }
    let(:project_version){ nil }
    let(:prerelease){ nil }
    let(:nightlies){ nil }
    let(:params) do
      params = {}
      params[:v] = project_version if project_version
      params[:p] = platform if platform
      params[:pv] = platform_version if platform_version
      params[:m] = architecture if architecture
      params[:prerelease] = prerelease unless prerelease.nil? # could be false, explicitly
      params[:nightlies] = nightlies unless nightlies.nil?    # could be false, explicitly
      params
    end

    let(:package_type){ fail "Specify a package type! (e.g., 'deb', 'rpm', 'tar.gz')"}

    # To handle situations where e.g., 'x86_64' is used in an installer name as 'amd64'
    let(:architecture_alt){ architecture }

    let(:endpoint){"/stable/#{project}/download"}
    let(:metadata_endpoint){"/stable/#{project}/metadata"}

    describe "chef" do
      let(:project){ "chef" }

      describe "mac_os_x" do
        let(:platform){"mac_os_x"}
        let(:alt_platform){"mac_os_x"}
        let(:package_type){"sh"}

        context "10.7" do
          let(:platform_version){"10.7"}
          let(:alt_platform_version){"10.7.2"}

          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_as(
                "10.16.4",
                md5: "99492c4bb8b0a367666aee10a51b71d1",
                sha256: "a821fef229c6382cf437fad0457ce00ac465280e8f517f2897df3614deef3286"
              )
            end
          end
        end

        context "10.10" do
          let(:platform_version){"10.10"}
          let(:alt_platform_version){"10.7.2"}

          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_metadata_as(
                "10.16.4",
                md5: "99492c4bb8b0a367666aee10a51b71d1",
                sha256: "a821fef229c6382cf437fad0457ce00ac465280e8f517f2897df3614deef3286"
              )
            end
          end
        end
      end

      describe "sles" do
        let(:platform){"sles"}
        let(:alt_platform){"el"}
        let(:package_type){"rpm"}

        context "11.0" do
          let(:platform_version){"11.0"}
          let(:alt_platform_version){"5"}

          context "x86_64" do

            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_as(
                "10.16.4",
                md5: "dab02655a8671e9a2cf782f94fd22ff9",
                sha256: "59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"
              )
            end
          end
        end

        context "10.0" do
          let(:platform_version){"10.0"}
          let(:alt_platform_version){"5"}

          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
            end
          end
        end

      end

      describe "suse" do
        let(:platform){"suse"}
        let(:alt_platform){"el"}
        let(:package_type){"rpm"}

        context "12.1" do
          let(:platform_version){"12.1"}
          let(:alt_platform_version){"5"}

          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_as(
                "10.16.4",
                md5: "dab02655a8671e9a2cf782f94fd22ff9",
                sha256: "59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"
              )
            end
          end
        end

        # 12.0 exercises major_only mode since only 12.1 exists -- this tests matching by major version going forwards
        context "12.0" do
          let(:platform_version){"12.0"}
          let(:alt_platform_version){"5"}

          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_as(
                "10.16.4",
                md5: "dab02655a8671e9a2cf782f94fd22ff9",
                sha256: "59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"
              )
            end
          end
        end

        # 12.2 exercises major_only mode since only 12.1 exists -- this tests matching by major version going backwards
        context "12.2" do
          let(:platform_version){"12.2"}
          let(:alt_platform_version){"5"}

          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_metadata_as(
                "10.16.4",
                md5: "dab02655a8671e9a2cf782f94fd22ff9",
                sha256: "59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"
              )
            end
          end
        end
      end

      shared_examples_for "ubuntu 12.04" do
        context "x86_64" do
          let(:alt_platform){"ubuntu"}
          let(:alt_platform_version){"12.04"}
          let(:architecture){"x86_64"}
          let(:architecture_alt){"amd64"}

          context "without an explicit version" do
            let(:project_version){nil}

            should_retrieve_latest_metadata_as(
              "10.16.0",
              md5: "4de84ac3683e0c18160e64c00cad6ad6",
              sha256: "29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"
            )
          end # without an explicit version

          context "with a version of 'latest'" do
            let(:project_version){"latest"}

            should_retrieve_latest_metadata_as(
              "10.16.0",
              md5: "4de84ac3683e0c18160e64c00cad6ad6",
              sha256: "29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"
            )
          end

          context "with an explicit version" do

            context "that is a proper release" do
              let(:project_version){"10.16.0"}

              should_retrieve_latest_metadata_as(
                "10.16.0",
                md5: "4de84ac3683e0c18160e64c00cad6ad6",
                sha256: "29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"
              )
            end

            context "that is a pre-release" do
              let(:project_version){"10.16.0.rc.1"}

              should_retrieve_latest_metadata_as(
                "10.16.0.rc.1",
                md5: "4104b6049b49029a6d3c75f1f0d07b3c",
                sha256: "fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"
              )
            end

            context "that is ancient and only in a very old version" do
              let(:project_version){"10.10.0"}  # this is only available in ubuntu 10.04, so we have to search upwards through platform versions to find it
              let(:alt_platform_version){"10.04"}

              should_retrieve_latest_metadata_as(
                "10.10.0",
                md5: "93616058a2ba09a6abccef7651fdae38",
                sha256: "9ee398d806bb377d190e92cd09e7b4a8571d4b328cd580a716425818e6124779"
              )
            end

            context "that is not fully qualified" do
              let(:project_version){"10"}

              should_retrieve_latest_metadata_as(
                "10.16.0",
                md5: "4de84ac3683e0c18160e64c00cad6ad6",
                sha256: "29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"
              )
            end
          end # with a explicit version
        end # x86_64
      end # Ubuntu 12.04

      describe "Linux Mint" do
        let(:platform){"linuxmint"}
        let(:package_type){"deb"}
        context "13" do  # this translates to ubuntu 12.04
          let(:platform_version){"13"}

          it_behaves_like "ubuntu 12.04"
        end

        context "16" do  # this is a yolo-mode translated version number download with a twist
          let(:platform_version){"14"}

          it_behaves_like "ubuntu 12.04"
        end
      end

      describe "Ubuntu" do
        let(:platform){"ubuntu"}
        let(:package_type){"deb"}

        context "12.04" do
          let(:platform_version){"12.04"}

          it_behaves_like "ubuntu 12.04"
        end

        context "12.10" do  # yolo mode
          let(:platform_version){"12.10"}

          it_behaves_like "ubuntu 12.04"
        end

        # What we're testing on this next one is if yolo is sorting numerically or lexicographically
        # If we're getting string compares we'll get "10.04" as our yolo version, but we want to do a
        # numeric compare and get 12.04 instead:
        #   String (Wrong): "101" < "10" < "12"
        #   Integer (Right): 10 < 12 < 101
        context "101.04" do
          let(:platform_version){"101.04"}

          it_behaves_like "ubuntu 12.04"
        end
      end

      describe "Windows" do
        let(:platform){"windows"}
        let(:package_type){"msi"}
        context "2008r2" do
          let(:platform_version){"2008r2"}
          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_metadata_as(
                "11.8.2",
                md5: "9379bb583ec0767463c2b5512c906b73",
                sha256: "f78b708c8aae9c30fe344155c7e3358d6843785815c995a16f92f711d1bd529d"
              )
            end # without an explicit version
          end
        end
      end

      describe "el" do
        let(:platform){"el"}
        let(:package_type){"rpm"}

        context "5" do

          let(:platform_version){"5"}

          context "x86_64" do
            let(:architecture){"x86_64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_as(
                "10.16.4",
                md5: "dab02655a8671e9a2cf782f94fd22ff9",
                sha256: "59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"
              )
            end # without an explicit version

            context "with a version of 'latest'" do
              let(:project_version){"latest"}

              should_retrieve_latest_as(
                "10.16.4",
                md5: "dab02655a8671e9a2cf782f94fd22ff9",
                sha256: "59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"
              )
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:project_version){"10.16.0"}

                should_retrieve_latest_as(
                  "10.16.0",
                  md5: "9103b2024b6f7d6e16ef8c6c0f7c0519",
                  sha256: "7905c0298580ce79a549284d7090fa9b72ff4a12127b1fba3b4612023294091d"
                )
              end # proper release

              context "that has multiple build iterations" do
                let(:project_version){"10.14.4"}

                context "returns the latest build iteration" do
                  should_retrieve_latest_as(
                    "10.14.4",
                    iteration: 2,
                    md5: "040507d279dc7d279768befa39c89970",
                    sha256: "0261dc02b14f039cef0b0a144ad14be9de4bcd7f884c17b14d3c25213385bc80"
                  )
                end
              end
            end # with a explicit version

          end # x86_64
        end # 5
        context "6" do
          let(:platform_version){"6"}
          let(:alt_platform_version){"5"}

          context "x86_64" do

            let(:architecture){"x86_64"}

            # in the data we only have 10.16.0 versions for el6, but we expect to see
            # 10.16.4 versions from el5 served up
            context "without an explicit version" do
              let(:project_version){nil}
              context "releases" do

                should_retrieve_latest_as(
                  "10.16.4",
                  md5: "dab02655a8671e9a2cf782f94fd22ff9",
                  sha256: "59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"
                )
              end
            end # without an explicit version
          end # x86_64
        end # 6
      end # EL
    end # /download

    describe "chefdk" do
      let(:project){ "chefdk" }

      describe "Mac OSX" do
        let(:platform){"mac_os_x"}
        let(:package_type){"dmg"}
        context "10.9" do
          let(:platform_version){"10.9"}
          let(:alt_platform_version){"10.9.2"}
          context "x86_64" do
            let(:architecture){"x86_64"}
            context "without an explicit version" do
              let(:project_version){nil}

              #should_retrieve_latest_as("11.0.0",  {:md5=>"9d8040305ca61d88dcd2bb126d8e0289", :sha256=>"b7e6384942609a7930f1ef0ae8574bd87f6db0ea2a456f407d0339ca5b8c7fcf"})
            end
          end
        end
      end
    end

    describe "chef-server" do
      let(:project){ "chef-server" }

      describe "Ubuntu" do
        let(:platform){"ubuntu"}
        let(:package_type){"deb"}

        context "10.04" do
          let(:platform_version){"10.04"}
          context "x86_64" do
            let(:architecture){"x86_64"}
            let(:architecture_alt){"amd64"}

            context "without an explicit version" do
              let(:project_version){nil}

              should_retrieve_latest_as(
                "11.0.0+20130101164140.git.207.694b062",
                md5: "c782dee98817f43b0227b88b926de29f",
                sha256: "a401655b5fd5dfcccb0811c8059e4ed53d47d264457734c00258f217d26a5e1e"
              )
            end # without an explicit version

            context "with a version of 'latest'" do
              let(:project_version){"latest"}

              should_retrieve_latest_as(
                "11.0.0+20130101164140.git.207.694b062",
                md5: "c782dee98817f43b0227b88b926de29f",
                sha256: "a401655b5fd5dfcccb0811c8059e4ed53d47d264457734c00258f217d26a5e1e"
              )
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:project_version){"11.0.0"}

                should_retrieve_latest_as(
                  "11.0.0",
                  md5: "9d8040305ca61d88dcd2bb126d8e0289",
                  sha256: "b7e6384942609a7930f1ef0ae8574bd87f6db0ea2a456f407d0339ca5b8c7fcf"
                )
              end # proper release

              context "that is a pre-release" do
                let(:project_version){"11.0.0-rc.1"}

                should_retrieve_latest_as(
                  "11.0.0-rc.1",
                  md5: "0a858c2effa80bbd6687433fcaa752b7",
                  sha256: "dacff5d6c852585b55b49915ed1ad83fd15286a8a21913f52a8ef6d811edbd9c"
                )
              end # pre-release

              context "that is a release nightly" do
                let(:project_version){"11.0.0+20130101164140.git.2.deadbee"}

                should_retrieve_latest_as(
                  "11.0.0+20130101164140.git.2.deadbee",
                  md5: "574dd623e52052d92e3bffa45fbafd1b",
                  sha256: "296072ba9560fe70c574b8b45461e5667add7eb688e059fd458262cc4e294c76"
                )
              end # release nightly

              context "that is a pre-release nightly" do
                let(:project_version){"11.0.0-rc.1+20121225164140.git.207.694b062"}

                should_retrieve_latest_as(
                  "11.0.0-rc.1+20121225164140.git.207.694b062",
                  md5: "44fd74dfe688c558a6469db2072774fb",
                  sha256: "bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"
                )
              end # pre-release nightly
            end # with a explicit version

          end # x86_64
        end # 10.04
      end # Ubuntu
    end # /download-server

  end # download endpoints

  describe "/<CHANNEL>/<PROJECT>/versions endpoint" do
    Chef::Project::KNOWN_PROJECTS.each do |project|
      describe project do
        let(:endpoint){ "/stable/#{project}/versions" }

        it "exists" do
          get endpoint
          expect(last_response).to be_ok
        end

        it "returns the correct JSON data" do
          get endpoint
          expect(last_response.header['Content-Type']).to include 'application/json'
          expect(last_response.body).to match(project)
        end
      end
    end
  end


  describe "install script" do
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

  describe "/_status" do
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
      expect(JSON.parse(last_response.body)["timestamp"]).to eq("Thu Aug 16 11:48:08 -0700 2012")
    end
  end

  describe "legacy behavior" do
    let(:endpoint){ "/metadata" }
    let(:project){ "chef" }

    let(:platform){ "ubuntu" }
    let(:platform_version){ "10.04" }
    let(:architecture){ "x86_64" }

    let(:prerelease){ nil }
    let(:nightlies){ nil }

    let(:params) do
      params = {}
      params[:p] = platform if platform
      params[:pv] = platform_version if platform_version
      params[:m] = architecture if architecture
      params[:prerelease] = prerelease unless prerelease.nil? # could be false, explicitly
      params[:nightlies] = nightlies unless nightlies.nil?    # could be false, explicitly
      params
    end

    %w(
      nightlies
      prerelease
    ).each do |legacy_param|

      describe "#{legacy_param} param" do
        let(legacy_param.to_sym) { true }

        it "returns a package from the current channel" do
          get(endpoint, params)
          expect(last_response.body).to match("opscode-omnibus-packages-current")
        end
      end

    end

    {
      '/download' => 'http://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef_10.16.0-1.ubuntu.10.04_amd64.deb',
      '/download-server' => 'http://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.0.0%2B20130101164140.git.207.694b062-1.ubuntu.10.04_amd64.deb',
      '/metadata' => 'http://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef_10.16.0-1.ubuntu.10.04_amd64.deb',
      '/metadata-server' => 'http://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.0.0%2B20130101164140.git.207.694b062-1.ubuntu.10.04_amd64.deb',
      '/full_client_list' => '/ubuntu/12.04/x86_64/chef_10.16.0-1.ubuntu.12.04_amd64.deb',
      '/full_list' => '/ubuntu/12.04/x86_64/chef_10.16.0-1.ubuntu.12.04_amd64.deb',
      '/full_server_list' => '/ubuntu/10.04/x86_64/chef-server_11.0.0-1.ubuntu.10.04_amd64.deb',
    }.each do |legacy_endpoint, response_match_data|

      describe "legacy endpoint #{legacy_endpoint}" do
        let(:endpoint) { legacy_endpoint }

        it "returns the correct response data" do
          get(endpoint, params)

          if legacy_endpoint =~ /download/
            follow_redirect!
            expect(last_request.url).to match(response_match_data)
          else
            expect(last_response.body).to match(response_match_data)
          end
        end
      end
    end
  end
end
