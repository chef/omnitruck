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
      /#{Regexp.escape(omnitruck_host_path)}\/#{Regexp.escape(platform)}\/#{Regexp.escape(platform_version)}\/#{Regexp.escape(architecture)}\/#{Regexp.escape(project)}[-_]#{expected_version_variations}\-#{iteration_number}\.#{Regexp.escape(platform)}\.?#{Regexp.escape(platform_version)}[._]#{Regexp.escape(architecture_alt)}\.#{package_type}/
    end

    def self.should_retrieve_latest_as(expected_version, options={})
      let(:iteration_number){ options[:iteration] || 1}
      let(:expected_md5) { options[:md5] }
      let(:expected_sha256) { options[:sha256] }
      let(:http_type_string) { "http" }
      let(:omnitruck_host_path)  { "#{http_type_string}://#{Omnitruck.aws_packages_bucket}.s3.amazonaws.com" }

      it "should serve a redirect to the correct URI for package #{expected_version}" do
        get(endpoint, params)
        last_response.should be_redirect
        follow_redirect!

        last_request.url.should =~ url_regex_for(expected_version)
      end

      it "should serve JSON metadata with a URI for package #{expected_version}" do
        get(metadata_endpoint, params, "HTTP_ACCEPT" => "application/json")
        metadata_json = last_response.body
        parsed_json = JSON.parse(metadata_json)

        pkg_url = parsed_json["url"]
        pkg_url.should =~ url_regex_for(expected_version)

        parsed_json["sha256"].should == expected_sha256
        parsed_json["md5"].should == expected_md5
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
        pkg_url.should =~ url_regex_for(expected_version)

        parsed_metadata["sha256"].should == expected_sha256
        parsed_metadata["md5"].should == expected_md5
      end
    end

    # Helper lets to make parameter declaration and handling easier
    let(:platform){ nil }
    let(:package_type){ nil }
    let(:platform_version){ nil }
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
    end # /download

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
        last_response.should be_ok
      end

      it "returns JSON data" do
        get endpoint
        last_response.header['Content-Type'].should include 'application/json'
      end

      context "legacy version" do
        let(:endpoint){ "/full_list" }

        it "exists" do
          get endpoint
          last_response.should be_ok
        end

        it "returns JSON data" do
          get endpoint
          last_response.header['Content-Type'].should include 'application/json'
        end
      end
    end

    describe "server" do
      let(:endpoint){ "/full_server_list" }

      it "exists" do
        get endpoint
        last_response.should be_ok
      end

      it "returns JSON data" do
        get endpoint
        last_response.header['Content-Type'].should include 'application/json'
      end
    end
  end

  describe "/install.sh" do
    it "exists" do
      get '/install.sh'
      last_response.should be_ok
    end
  end

  describe "/_status" do
    let(:endpoint){"/_status"}

    it "exists" do
      get endpoint
      last_response.should be_ok
    end

    it "returns JSON data" do
      get endpoint
      last_response.header['Content-Type'].should include 'application/json'
    end

    it "returns the timestamp of the last poller run" do
      get endpoint
      JSON.parse(last_response.body)["timestamp"].should == "Thu Aug 16 11:48:08 -0700 2012"
    end
  end
end
