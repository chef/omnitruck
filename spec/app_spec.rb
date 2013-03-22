require 'spec_helper'
require 'uri'

describe 'Omnitruck' do
  def app
    Omnitruck
  end

  describe "download endpoints" do

    def self.should_retrieve_latest_as(expected_version, options={})
      let(:iteration_number){ options[:iteration] || 1}

      it "should serve a redirect to the correct URI for package #{expected_version}" do
        get(endpoint, params)
        last_response.should be_redirect
        follow_redirect!
        http_type_string = URI.split(last_request.url)[0]
        omnitruck_host_path = "#{http_type_string}://#{Omnitruck.aws_packages_bucket}.s3.amazonaws.com"
        # This really sucks but the git describe string embedded in package names differs
        # between platforms. For example:
        #
        #    ubuntu -> chef_10.16.2-49-g21353f0-1.ubuntu.11.04_amd64.deb
        #    el     -> chef-10.16.2_49_g21353f0-1.el5.x86_64.rpm
        #
        expected_version_variations = Regexp.escape(expected_version).gsub(/\\-|_/, "[_-]")
        expected_version_variations.gsub!(/\+/, "%2B")
        last_request.url.should =~ /#{Regexp.escape(omnitruck_host_path)}\/#{Regexp.escape(platform)}\/#{Regexp.escape(platform_version)}\/#{Regexp.escape(architecture)}\/#{Regexp.escape(project)}[-_]#{expected_version_variations}\-#{iteration_number}\.#{Regexp.escape(platform)}\.?#{Regexp.escape(platform_version)}[._]#{Regexp.escape(architecture_alt)}\.#{package_type}/
      end

      it "should serve JSON metadata with a URI for package #{expected_version}" do
        get(metadata_endpoint, params)
        #last_response.should be_redirect
        #follow_redirect!
        metadata_json = last_response.body
        # parse it
        #
        pkg_url = parsed_json["url"]
        http_type_string = URI.split(last_request.url)[0]
        omnitruck_host_path = "#{http_type_string}://#{Omnitruck.aws_packages_bucket}.s3.amazonaws.com"
        # This really sucks but the git describe string embedded in package names differs
        # between platforms. For example:
        #
        #    ubuntu -> chef_10.16.2-49-g21353f0-1.ubuntu.11.04_amd64.deb
        #    el     -> chef-10.16.2_49_g21353f0-1.el5.x86_64.rpm
        #
        expected_version_variations = Regexp.escape(expected_version).gsub(/\\-|_/, "[_-]")
        expected_version_variations.gsub!(/\+/, "%2B")
        pkg_url.should =~ /#{Regexp.escape(omnitruck_host_path)}\/#{Regexp.escape(platform)}\/#{Regexp.escape(platform_version)}\/#{Regexp.escape(architecture)}\/#{Regexp.escape(project)}[-_]#{expected_version_variations}\-#{iteration_number}\.#{Regexp.escape(platform)}\.?#{Regexp.escape(platform_version)}[._]#{Regexp.escape(architecture_alt)}\.#{package_type}/
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
                should_retrieve_latest_as "10.16.0.rc.1"
              end

              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as "10.16.4"
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as "10.16.2-49-g21353f0"
              end
            end # without an explicit version

            context "with a version of 'latest'" do

              let(:chef_version){"latest"}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as "10.16.0.rc.1"
              end

              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as "10.16.4"
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as "10.16.2-49-g21353f0"
              end
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:chef_version){"10.16.0"}

                context "filtering for latest pre-release in this line" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0.rc.1"
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end

                context "filtering for latest release in this line (i.e., this exact thing)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0"
                end

                context "filtering for latest release nightly in this line" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0-49-g21353f0"
                end
              end # proper release

              context "that is a pre-release" do
                let(:chef_version){"10.16.0.rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0.rc.1"
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0.rc.1"
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end
              end # pre-release

              context "that is a another pre-release that's earlier than the last one" do
                let(:chef_version){"10.16.0.rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0.rc.1"
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0.rc.1"
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end
              end # another pre-release

              context "that is a release nightly" do
                let(:chef_version){"10.16.2-49-g21353f0-1"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.2-49-g21353f0"
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.2-49-g21353f0"
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.2-49-g21353f0"
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.2-49-g21353f0"
                end
              end # release nightly

              context "that is a pre-release nightly" do
                let(:chef_version){"10.16.0.rc.1-49-g21353f0-1"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "10.16.0.rc.1-49-g21353f0"
                end
              end # pre-release nightly

              context "that has multiple build iterations" do
                let(:chef_version){"10.14.4"}
                let(:prerelease){false}
                let(:nightlies){false}

                context "returns the latest build iteration" do
                  should_retrieve_latest_as "10.14.4", :iteration => 2
                end
              end
            end # with a explicit version

          end # x86_64
        end # 5
      end # EL
    end # /download

    describe "server" do
      let(:endpoint){"/download-server"}
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
                should_retrieve_latest_as "11.0.0-rc.1"
              end
              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as "11.0.0"
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as "11.0.0+20130101164140.git.207.694b062"
              end
            end # without an explicit version

            context "with a version of 'latest'" do
              let(:chef_version){"latest"}

              context "pre-releases" do
                let(:prerelease){true}
                let(:nightlies){false}
                should_retrieve_latest_as "11.0.0-rc.1"
              end
              context "pre-release nightlies" do
                let(:prerelease){true}
                let(:nightlies){true}
                should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
              end

              context "releases" do
                let(:prerelease){false}
                let(:nightlies){false}
                should_retrieve_latest_as "11.0.0"
              end

              context "releases nightlies" do
                let(:prerelease){false}
                let(:nightlies){true}
                should_retrieve_latest_as "11.0.0+20130101164140.git.207.694b062"
              end
            end # with a version of 'latest'

            context "with an explicit version" do
              context "that is a proper release" do
                let(:chef_version){"11.0.0"}

                context "filtering for latest pre-release in this line" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0-rc.1"
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
                end

                context "filtering for latest release in this line (i.e., this exact thing)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0"
                end

                context "filtering for latest release nightly in this line" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0+20130101164140.git.207.694b062"
                end
              end # proper release

              context "that is a pre-release" do
                let(:chef_version){"11.0.0-rc.1"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0-rc.1"
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0-rc.1"
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
                end
              end # pre-release

              context "that is a another pre-release that's earlier than the last one" do
                let(:chef_version){"11.0.0-beta.2"}

                context "filtering for latest pre-release in this line (i.e., this exact thing)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0-beta.2"
                end

                context "filtering for latest pre-release nightly in this line" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0-beta.2+build.123"
                end

                context "filtering for latest release in this line (i.e., the 'prerelease' parameter is meaningless)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0-beta.2"
                end

                context "filtering for latest release nightly in this line (i.e., the 'prerelease' parameter is meaningless yet again)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0-beta.2+build.123"
                end
              end # another pre-release

              context "that is a release nightly" do
                let(:chef_version){"11.0.0+20130101164140.git.2.deadbee"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0+20130101164140.git.2.deadbee"
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0+20130101164140.git.2.deadbee"
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0+20130101164140.git.2.deadbee"
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0+20130101164140.git.2.deadbee"
                end
              end # release nightly

              context "that is a pre-release nightly" do
                let(:chef_version){"11.0.0-rc.1+20121225164140.git.207.694b062"}

                context "filtering for latest pre-release in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
                end

                context "filtering for latest pre-release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){true}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
                end

                context "filtering for latest release in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){false}
                  should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
                end

                context "filtering for latest release nightly in this line has no effect (returns the exact version)" do
                  let(:prerelease){false}
                  let(:nightlies){true}
                  should_retrieve_latest_as "11.0.0-rc.1+20121225164140.git.207.694b062"
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
