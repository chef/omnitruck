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
    let(:chef_version){ nil }
    let(:prerelease){ nil }
    let(:nightlies){ nil }
    let(:params) do
      params = {}
      params[:v] = chef_version if chef_version
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

    describe "client" do
      let(:endpoint){"/download"}
      let(:metadata_endpoint){"/metadata"}
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"99492c4bb8b0a367666aee10a51b71d1", :sha256=>"a821fef229c6382cf437fad0457ce00ac465280e8f517f2897df3614deef3286" })
              end
            end
          end
        end

        context "10.10" do
          let(:platform_version){"10.10"}
          let(:alt_platform_version){"10.7.2"}

          context "x86_64" do

            let(:architecture){"x86_64"}

            context "without an explicit version" do

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.4", { :md5=>"99492c4bb8b0a367666aee10a51b71d1", :sha256=>"a821fef229c6382cf437fad0457ce00ac465280e8f517f2897df3614deef3286" })
              end
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
            end
          end
        end

        context "10.0" do
          let(:platform_version){"10.0"}
          let(:alt_platform_version){"5"}

          context "x86_64" do

            let(:architecture){"x86_64"}

            context "without an explicit version" do

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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
            let(:chef_version){nil}

            context "pre-releases" do
              let(:prerelease){true}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
            end

            context "releases" do
              let(:prerelease){false}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
            end

            context "releases nightlies" do
              let(:prerelease){false}
              let(:nightlies){true}
              should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
            end
          end # without an explicit version

          context "with a version of 'latest'" do
            let(:chef_version){"latest"}

            context "pre-releases" do
              let(:prerelease){true}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
            end

            context "releases" do
              let(:prerelease){false}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
            end

            context "releases nightlies" do
              let(:prerelease){false}
              let(:nightlies){true}
              should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
            end
          end # with a version of 'latest'

          context "with an explicit version" do
            context "that is a proper release" do
              let(:chef_version){"10.16.0"}

              context "filtering for latest pre-release in this line" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release in this line (i.e., this exact thing)" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
              end

              context "filtering for latest release nightly in this line" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
              end
            end # proper release

            context "that is a pre-release" do
              let(:chef_version){"10.16.0.rc.1"}

              context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end
            end # pre-release

            context "that is ancient and only in a very old version" do
              let(:chef_version){"10.10.0"}  # this is only available in ubuntu 10.04, so we have to search upwards through platform versions to find it
              context "filtering for latest release in this line (i.e., this exact thing)" do
                let(:alt_platform_version){"10.04"}
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.10.0",  {:md5=>"93616058a2ba09a6abccef7651fdae38", :sha256=>"9ee398d806bb377d190e92cd09e7b4a8571d4b328cd580a716425818e6124779"})
              end
            end

            context "that is not fully qualified" do
              let(:chef_version){"10"}

              context "filtering for latest pre-release in this line" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release in this line" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
              end

              context "filtering for latest release nightly in this line" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
              end
            end # pre-release
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
            #let(:architecture_alt){"amd64"}

            context "without an explicit version" do
              let(:chef_version){nil}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("11.8.2.rc.0",  {:iteration => "2", :md5=>"63efd66df27611935ee12bf9cb9912bc", :sha256=>"9eb24c1023f2e512bd8ae8b5cf0d657fb5f40d7dcaa8a29e8b839846d82cf0fe"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("11.8.2",  {:md5=>"9379bb583ec0767463c2b5512c906b73", :sha256=>"f78b708c8aae9c30fe344155c7e3358d6843785815c995a16f92f711d1bd529d"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("11.4.0-18-gdf096fa",  {:md5=>"8cb5496e9ff5228f587960375dc0daed", :sha256=>"ff18820f4b4399df51e7b515cd5881c658a4768d4516c63adaed429aa840b713"})
              end
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

              let(:chef_version){nil}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.0.rc.1", { :md5 => "a4afeaefeec1862d138335664582d90d", :sha256 => "d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9" })
              end

              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0", { :md5 => "d951f01022512a72cfe71060c6267931", :sha256 => "b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575" })
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.2-49-g21353f0", { :md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2" })
              end
            end # without an explicit version

            context "with a version of 'latest'" do

              let(:chef_version){"latest"}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.0.rc.1", {:md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
              end

              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", {:md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.2-49-g21353f0", {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
              end
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:chef_version){"10.16.0"}

                context "filtering for latest pre-release in this line" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1",  {:md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line (i.e., this exact thing)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0", { :md5=>"9103b2024b6f7d6e16ef8c6c0f7c0519", :sha256=>"7905c0298580ce79a549284d7090fa9b72ff4a12127b1fba3b4612023294091d"})
                end

                context "filtering for latest release nightly in this line" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0-49-g21353f0", { :md5=>"e236fdb22ebc9d79ff496791043969c4", :sha256=>"b3c77c18e50633d0b55487ccdc1ccb015449a1673677f9f7eb58b9b36041f2cd"})
                end
              end # proper release

              context "that is a pre-release" do
                let(:chef_version){"10.16.0.rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1", { :md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1",  { :md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end
              end # pre-release

              context "that is a another pre-release that's earlier than the last one" do
                let(:chef_version){"10.16.0.rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1", { :md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  { :md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1",  {:md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end
              end # another pre-release

              context "that is a release nightly" do
                let(:chef_version){"10.16.2-49-g21353f0-1"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.2-49-g21353f0", {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.2-49-g21353f0", { :md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.2-49-g21353f0",  {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.2-49-g21353f0",  {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end
              end # release nightly

              context "that is a pre-release nightly" do
                let(:chef_version){"10.16.0.rc.1-49-g21353f0-1"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end
              end # pre-release nightly

              context "that has multiple build iterations" do
                let(:chef_version){"10.14.4"}
                let(:prerelease){false}
                let(:nightlies){false}

                context "returns the latest build iteration" do
                  should_retrieve_latest_as("10.14.4", {:iteration => 2, :md5=>"040507d279dc7d279768befa39c89970", :sha256=>"0261dc02b14f039cef0b0a144ad14be9de4bcd7f884c17b14d3c25213385bc80"})
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
              let(:chef_version){nil}
              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
            end # without an explicit version
          end # x86_64
        end # 6
      end # EL
    end # /download

    describe "angrychef" do
      let(:endpoint){"/download-angrychef"}
      let(:metadata_endpoint){"/metadata-angrychef"}
      let(:project){ "angrychef" }

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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
            end
          end
        end

        context "10.0" do
          let(:platform_version){"10.0"}
          let(:alt_platform_version){"5"}

          context "x86_64" do

            let(:architecture){"x86_64"}

            context "without an explicit version" do

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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

              let(:chef_version){nil}

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end
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
            let(:chef_version){nil}

            context "pre-releases" do
              let(:prerelease){true}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
            end

            context "releases" do
              let(:prerelease){false}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
            end

            context "releases nightlies" do
              let(:prerelease){false}
              let(:nightlies){true}
              should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
            end
          end # without an explicit version

          context "with a version of 'latest'" do
            let(:chef_version){"latest"}

            context "pre-releases" do
              let(:prerelease){true}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
            end

            context "releases" do
              let(:prerelease){false}
              let(:nightlies){false}
              should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
            end

            context "releases nightlies" do
              let(:prerelease){false}
              let(:nightlies){true}
              should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
            end
          end # with a version of 'latest'

          context "with an explicit version" do
            context "that is a proper release" do
              let(:chef_version){"10.16.0"}

              context "filtering for latest pre-release in this line" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release in this line (i.e., this exact thing)" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
              end

              context "filtering for latest release nightly in this line" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
              end
            end # proper release

            context "that is a pre-release" do
              let(:chef_version){"10.16.0.rc.1"}

              context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end
            end # pre-release

            context "that is ancient and only in a very old version" do
              let(:chef_version){"10.10.0"}  # this is only available in ubuntu 10.04, so we have to search upwards through platform versions to find it
              context "filtering for latest release in this line (i.e., this exact thing)" do
                let(:alt_platform_version){"10.04"}
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.10.0",  {:md5=>"93616058a2ba09a6abccef7651fdae38", :sha256=>"9ee398d806bb377d190e92cd09e7b4a8571d4b328cd580a716425818e6124779"})
              end
            end

            context "that is not fully qualified" do
              let(:chef_version){"10"}

              context "filtering for latest pre-release in this line" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "filtering for latest release in this line" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
              end

              context "filtering for latest release nightly in this line" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
              end
            end # pre-release
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
            #let(:architecture_alt){"amd64"}

            context "without an explicit version" do
              let(:chef_version){nil}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("11.8.2.rc.0",  {:iteration => "2", :md5=>"63efd66df27611935ee12bf9cb9912bc", :sha256=>"9eb24c1023f2e512bd8ae8b5cf0d657fb5f40d7dcaa8a29e8b839846d82cf0fe"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("11.8.2",  {:md5=>"9379bb583ec0767463c2b5512c906b73", :sha256=>"f78b708c8aae9c30fe344155c7e3358d6843785815c995a16f92f711d1bd529d"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("11.4.0-18-gdf096fa",  {:md5=>"8cb5496e9ff5228f587960375dc0daed", :sha256=>"ff18820f4b4399df51e7b515cd5881c658a4768d4516c63adaed429aa840b713"})
              end
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

              let(:chef_version){nil}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.0.rc.1", { :md5 => "a4afeaefeec1862d138335664582d90d", :sha256 => "d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9" })
              end

              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0", { :md5 => "d951f01022512a72cfe71060c6267931", :sha256 => "b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575" })
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", { :md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc" })
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.2-49-g21353f0", { :md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2" })
              end
            end # without an explicit version

            context "with a version of 'latest'" do

              let(:chef_version){"latest"}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.0.rc.1", {:md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
              end

              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("10.16.4", {:md5=>"dab02655a8671e9a2cf782f94fd22ff9", :sha256=>"59b41393af85183c59f8d247df72863f687676ed07d960339d17b727e33ee9bc"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as("10.16.2-49-g21353f0", {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
              end
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:chef_version){"10.16.0"}

                context "filtering for latest pre-release in this line" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1",  {:md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line (i.e., this exact thing)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0", { :md5=>"9103b2024b6f7d6e16ef8c6c0f7c0519", :sha256=>"7905c0298580ce79a549284d7090fa9b72ff4a12127b1fba3b4612023294091d"})
                end

                context "filtering for latest release nightly in this line" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0-49-g21353f0", { :md5=>"e236fdb22ebc9d79ff496791043969c4", :sha256=>"b3c77c18e50633d0b55487ccdc1ccb015449a1673677f9f7eb58b9b36041f2cd"})
                end
              end # proper release

              context "that is a pre-release" do
                let(:chef_version){"10.16.0.rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1", { :md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1",  { :md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end
              end # pre-release

              context "that is a another pre-release that's earlier than the last one" do
                let(:chef_version){"10.16.0.rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1", { :md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  { :md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1",  {:md5=>"a4afeaefeec1862d138335664582d90d", :sha256=>"d1757dfc375c7e4fca9fbd473e85ece37ffff6687f1b2a8cdc4c4c8c7e8705d9"})
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end
              end # another pre-release

              context "that is a release nightly" do
                let(:chef_version){"10.16.2-49-g21353f0-1"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.2-49-g21353f0", {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.2-49-g21353f0", { :md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.2-49-g21353f0",  {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.2-49-g21353f0",  {:md5=>"b5a5b48097c49b82d96b4ddc3c852855", :sha256=>"d3edd44115b36569e353bcb0312d5c9c73a011edd6d119561e9bca8b959203f2"})
                end
              end # release nightly

              context "that is a pre-release nightly" do
                let(:chef_version){"10.16.0.rc.1-49-g21353f0-1"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("10.16.0.rc.1-49-g21353f0",  {:md5=>"d951f01022512a72cfe71060c6267931", :sha256=>"b3b3640a7f769468618027d781cdccab65940f0661cfa577f2c8379bd6473575"})
                end
              end # pre-release nightly

              context "that has multiple build iterations" do
                let(:chef_version){"10.14.4"}
                let(:prerelease){false}
                let(:nightlies){false}

                context "returns the latest build iteration" do
                  should_retrieve_latest_as("10.14.4", {:iteration => 2, :md5=>"040507d279dc7d279768befa39c89970", :sha256=>"0261dc02b14f039cef0b0a144ad14be9de4bcd7f884c17b14d3c25213385bc80"})
                end
              end
            end # with a explicit version

          end # x86_64
        end # 5
      end # EL
    end # /angrychef

    describe "chefdk" do
      let(:endpoint){"/download-chefdk"}
      let(:metadata_endpoint) {"metadata-chefdk"}
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
              let(:chef_version){nil}
#              context "pre-releases" do
#                let(:prerelease){true}
#                let(:nightlies){false}
#                should_retrieve_latest_as("11.0.0-rc.1", { :md5=>"0a858c2effa80bbd6687433fcaa752b7", :sha256=>"dacff5d6c852585b55b49915ed1ad83fd15286a8a21913f52a8ef6d811edbd9c"})
#              end
#              context "pre-release nightlies" do
#                let(:prerelease){true}
#                let(:nightlies){true}
#                should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
#              end
#
#              context "releases" do
#                let(:prerelease){false}
#                let(:nightlies){false}
#                should_retrieve_latest_as("11.0.0",  {:md5=>"9d8040305ca61d88dcd2bb126d8e0289", :sha256=>"b7e6384942609a7930f1ef0ae8574bd87f6db0ea2a456f407d0339ca5b8c7fcf"})
#              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as("11.6.0+20140402075145.git.162.26629e3", {:md5=>"9cb782ac06b1447b1a4b657c4025ff23", :sha256=>"115ea5a53a8da80a7e958d16921f746ab5379d2eee047528b7f5df52c71db641"})
              end
            end
          end
        end
      end
    end

    describe "container" do
      let(:endpoint) {"/download-container"}
      let(:metadata_endpoint) {"metadata-container"}
      let(:project) {"chef-container"}

      describe "Ubuntu" do
        let(:platform) {"ubuntu"}
        let(:package_type) {"deb"}

        context "12.04" do
          let(:platform_version) {"12.04"}
          context "x86_64" do
            let(:alt_platform){"ubuntu"}
            let(:alt_platform_version){"12.04"}
            let(:architecture){"x86_64"}
            let(:architecture_alt){"amd64"}

            context "without an explicit version" do
              let(:chef_version){nil}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
              end
            end # without an explicit version

            context "with a version of 'latest'" do
              let(:chef_version){"latest"}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
              end
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:chef_version){"10.16.0"}

                context "filtering for latest pre-release in this line" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
                end

                context "filtering for latest release in this line (i.e., this exact thing)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
                end

                context "filtering for latest release nightly in this line" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
                end
              end # proper release

              context "that is a pre-release" do
                let(:chef_version){"10.16.0.rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
                end
              end # pre-release

              context "that is not fully qualified" do
                let(:chef_version){"10"}

                context "filtering for latest pre-release in this line" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_metadata_as("10.16.0.rc.1",  {:md5=>"4104b6049b49029a6d3c75f1f0d07b3c", :sha256=>"fe1c2d4692d8419b6ee3b344efe83bfb1dd1c3aef61f70289b74ee5caad1e414"})
                end

                context "filtering for latest release in this line" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_metadata_as("10.16.0",  {:md5=>"4de84ac3683e0c18160e64c00cad6ad6", :sha256=>"29dd37432ca48632671ee493cd366995bd986f94f6384b7ad4c0a411368848d9"})
                end

                context "filtering for latest release nightly in this line" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_metadata_as("10.16.0-49-g21353f0",  {:md5=>"7a55604de777203008f9689e23aae585", :sha256=>"147f678b606a5992fac283306026fabdf799dadda458d6383346a95f42b9f9db"})
                end
              end # pre-release
            end # with a explicit version
          end # x86_64
        end # 12.04
      end # Ubuntu
    end # container


    describe "server" do
      let(:endpoint){"/download-server"}
      let(:metadata_endpoint) {"metadata-server"}
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
              let(:chef_version){nil}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as("11.0.0-rc.1", { :md5=>"0a858c2effa80bbd6687433fcaa752b7", :sha256=>"dacff5d6c852585b55b49915ed1ad83fd15286a8a21913f52a8ef6d811edbd9c"})
              end
              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("11.0.0",  {:md5=>"9d8040305ca61d88dcd2bb126d8e0289", :sha256=>"b7e6384942609a7930f1ef0ae8574bd87f6db0ea2a456f407d0339ca5b8c7fcf"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as("11.0.0+20130101164140.git.207.694b062",  {:md5=>"c782dee98817f43b0227b88b926de29f", :sha256=>"a401655b5fd5dfcccb0811c8059e4ed53d47d264457734c00258f217d26a5e1e"})
              end
            end # without an explicit version

            context "with a version of 'latest'" do
              let(:chef_version){"latest"}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as("11.0.0-rc.1",  {:md5=>"0a858c2effa80bbd6687433fcaa752b7", :sha256=>"dacff5d6c852585b55b49915ed1ad83fd15286a8a21913f52a8ef6d811edbd9c"})
              end
              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as("11.0.0",  {:md5=>"9d8040305ca61d88dcd2bb126d8e0289", :sha256=>"b7e6384942609a7930f1ef0ae8574bd87f6db0ea2a456f407d0339ca5b8c7fcf"})
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as("11.0.0+20130101164140.git.207.694b062", { :md5=>"c782dee98817f43b0227b88b926de29f", :sha256=>"a401655b5fd5dfcccb0811c8059e4ed53d47d264457734c00258f217d26a5e1e"})
              end
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:chef_version){"11.0.0"}

                context "filtering for latest pre-release in this line" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0-rc.1",  {:md5=>"0a858c2effa80bbd6687433fcaa752b7", :sha256=>"dacff5d6c852585b55b49915ed1ad83fd15286a8a21913f52a8ef6d811edbd9c"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
                end

                context "filtering for latest release in this line (i.e., this exact thing)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0",  {:md5=>"9d8040305ca61d88dcd2bb126d8e0289", :sha256=>"b7e6384942609a7930f1ef0ae8574bd87f6db0ea2a456f407d0339ca5b8c7fcf"})
                end

                context "filtering for latest release nightly in this line" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0+20130101164140.git.207.694b062",  {:md5=>"c782dee98817f43b0227b88b926de29f", :sha256=>"a401655b5fd5dfcccb0811c8059e4ed53d47d264457734c00258f217d26a5e1e"})
                end
              end # proper release

              context "that is a pre-release" do
                let(:chef_version){"11.0.0-rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0-rc.1",  {:md5=>"0a858c2effa80bbd6687433fcaa752b7", :sha256=>"dacff5d6c852585b55b49915ed1ad83fd15286a8a21913f52a8ef6d811edbd9c"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0-rc.1",  {:md5=>"0a858c2effa80bbd6687433fcaa752b7", :sha256=>"dacff5d6c852585b55b49915ed1ad83fd15286a8a21913f52a8ef6d811edbd9c"})
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
                end
              end # pre-release

              context "that is a another pre-release that's earlier than the last one" do
                let(:chef_version){"11.0.0-beta.2"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0-beta.2", { :md5=>"db5dcf80210976404e271002d5d7d555", :sha256=>"bb63051ede7f816d1af414aef0d8a31292fdb1d559db38f20ef94fc09decdf66"})
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0-beta.2+build.123",  {:md5=>"d108dfe721e3a684a96a149a5d953751", :sha256=>"c97ea1e9b7e55cc0c4c4251811a41ec963e58f0e9d79145a147181d7b0e60934"})
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0-beta.2", { :md5=>"db5dcf80210976404e271002d5d7d555", :sha256=>"bb63051ede7f816d1af414aef0d8a31292fdb1d559db38f20ef94fc09decdf66"})
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0-beta.2+build.123",  {:md5=>"d108dfe721e3a684a96a149a5d953751", :sha256=>"c97ea1e9b7e55cc0c4c4251811a41ec963e58f0e9d79145a147181d7b0e60934"})
                end
              end # another pre-release

              context "that is a release nightly" do
                let(:chef_version){"11.0.0+20130101164140.git.2.deadbee"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0+20130101164140.git.2.deadbee",  {:md5=>"574dd623e52052d92e3bffa45fbafd1b", :sha256=>"296072ba9560fe70c574b8b45461e5667add7eb688e059fd458262cc4e294c76"})
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0+20130101164140.git.2.deadbee",  {:md5=>"574dd623e52052d92e3bffa45fbafd1b", :sha256=>"296072ba9560fe70c574b8b45461e5667add7eb688e059fd458262cc4e294c76"})
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0+20130101164140.git.2.deadbee",  {:md5=>"574dd623e52052d92e3bffa45fbafd1b", :sha256=>"296072ba9560fe70c574b8b45461e5667add7eb688e059fd458262cc4e294c76"})
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0+20130101164140.git.2.deadbee",  {:md5=>"574dd623e52052d92e3bffa45fbafd1b", :sha256=>"296072ba9560fe70c574b8b45461e5667add7eb688e059fd458262cc4e294c76"})
                end
              end # release nightly

              context "that is a pre-release nightly" do
                let(:chef_version){"11.0.0-rc.1+20121225164140.git.207.694b062"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as("11.0.0-rc.1+20121225164140.git.207.694b062",  {:md5=>"44fd74dfe688c558a6469db2072774fb", :sha256=>"bae7d25d9c9e32b5f1320fda1d82cdba59c574a1838242a4f03366e0007034c6"})
                end
              end # pre-release nightly
            end # with a explicit version

          end # x86_64
        end # 10.04
      end # Ubuntu
    end # /download-server

  end # download endpoints

  describe "full list endpoints" do
    describe "client" do
      let(:endpoint){ "/full_client_list" }

      it "exists" do
        get endpoint
        expect(last_response).to be_ok
      end

      it "returns JSON data" do
        get endpoint
        expect(last_response.header['Content-Type']).to include 'application/json'
      end

      context "legacy version" do
        let(:endpoint){ "/full_list" }

        it "exists" do
          get endpoint
          expect(last_response).to be_ok
        end

        it "returns JSON data" do
          get endpoint
          expect(last_response.header['Content-Type']).to include 'application/json'
        end
      end
    end

    describe "angrychef" do
      let(:endpoint){ "/full_angrychef_list" }

      it "exists" do
        get endpoint
        expect(last_response).to be_ok
      end

      it "returns JSON data" do
        get endpoint
        expect(last_response.header['Content-Type']).to include 'application/json'
      end
    end

    describe "server" do
      let(:endpoint){ "/full_server_list" }

      it "exists" do
        get endpoint
        expect(last_response).to be_ok
      end

      it "returns JSON data" do
        get endpoint
        expect(last_response.header['Content-Type']).to include 'application/json'
      end
    end

    describe "chefdk" do
      let(:endpoint){ "/full_chefdk_list" }

      it "exists" do
        get endpoint
        expect(last_response).to be_ok
      end

      it "returns JSON data" do
        get endpoint
        expect(last_response.header['Content-Type']).to include 'application/json'
      end
    end

    describe "container" do
      let(:endpoint) {"/full_container_list"}

      it "exists" do
        get endpoint
        expect(last_response).to be_ok
      end

      it "returns JSON data" do
        get endpoint
        expect(last_response.header['Content-Type']).to include 'application/json'
      end
    end
  end

  describe "/install.sh" do
    it "exists" do
      get '/install.sh'
      expect(last_response).to be_ok
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
end
