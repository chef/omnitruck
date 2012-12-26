require 'spec_helper'
require 'uri'

describe 'Omnitruck' do
  def app
    Omnitruck
  end

  before do
  end

  describe "/install.sh" do
    it "endpoint should exist" do
      get '/install.sh'
      last_response.should be_ok
    end
  end

  describe "/download" do
    before :each do
      # Use our dummy data
      Omnitruck.stub!(:build_list).and_return(client_data("build_list"))
    end

    # This should probably return a 400
    # required: platform, platform_version, machine
    it "should return 404 if required parameters are not passed" do
      get '/download'
      last_response.status.should == 404
    end

    it "should return 404 an unknown platform is passed" do
      get '/download', :p => "unknown", :pv => "5", :m => "x86_64"
      last_response.status.should == 404
    end

    it "should return 404 an unknown platform version is passed" do
      get '/download', :p => "el", :pv => "unknown", :m => "x86_64"
      last_response.status.should == 404
    end

    it "should return 404 an unknown machine is passed" do
      get '/download', :p => "el", :pv => "5", :m => "unknown"
      last_response.status.should == 404
    end

    it "should return 404 an invalid version is passed" do
      get '/download', :v => "poopypants", :p => "el", :pv => "5", :m => "x86_64"
      last_response.status.should == 404
    end

    it "should return the version specified" do
      get '/download', :v => "10.12.0-1", :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.12.0-1.el5.x86_64.rpm'
    end

    it "should return a rc/beta version if specified" do
      get '/download', :v => "10.14.0.rc.0-1", :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.14.0.rc.0-1.el5.x86_64.rpm'
    end

    it "should return the latest stable (numeric) version if version is empty string" do
      get '/download', :v => "", :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.16.2-1.el5.x86_64.rpm'
    end

    it "should return the latest stable (numeric) version if no version is specified" do
      get '/download', :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.16.2-1.el5.x86_64.rpm'
    end

    it "should return the latest prerelease (numeric) version if no version is specified and prerelease is set" do
      get '/download', :p => "el", :pv => "5", :m => "x86_64", :prerelease => "true"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.16.0.rc.1-1.el5.x86_64.rpm'
    end

    it "should return the latest iteration if no iteration is specified (x.y.z-iteration)" do
      get '/download', :v => "10.14.4", :p => "el", :pv => "6", :m => "i686"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/el/6/i686/chef-10.14.4-2.el6.i686.rpm'
    end

  end

  describe "semantic version support" do

    before :each do
      # Use our dummy data
      Omnitruck.stub!(:build_server_list).and_return(server_data("servers"))
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

    let(:package_type){ fail "Specify a package type! (e.g., 'deb', 'rpm')"}

    # To handle situations where e.g., 'x86_64' is used in an installer name as 'amd64'
    let(:architecture_alt){ architecture }

    # You can ignore this for now... we only have "1" iterations so
    # far.  This is more for self-documenting purposes than anything
    # else.
    let(:iteration_number){1}

    describe "/download-server" do
      let(:endpoint){"/download-server"}

      def self.should_retrieve_latest_as(expected_version)
        it "should retrieve latest as #{expected_version}" do
          get(endpoint, params)
          last_response.should be_redirect
          follow_redirect!
          http_type_string = URI.split(last_request.url)[0]
          last_request.url.should == http_type_string + "://#{Omnitruck.aws_bucket}.s3.amazonaws.com/#{platform}/#{platform_version}/#{architecture}/chef-server_#{expected_version}-#{iteration_number}.#{platform}.#{platform_version}_#{architecture_alt}.#{package_type}"
        end
      end

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
  end # Semantic Versioning Support

  describe "/download-server" do
    before :each do
      # Use our dummy data
      Omnitruck.stub!(:build_server_list).and_return(server_data("servers"))
    end

    # This should probably return a 400
    # required: platform, platform_version, machine
    it "should return 404 if required parameters are not passed" do
      get '/download-server'
      last_response.status.should == 404
    end

    it "should return 404 an unknown platform is passed" do
      get '/download-server', :p => "unknown", :pv => "5", :m => "x86_64"
      last_response.status.should == 404
    end

    it "should return 404 an unknown platform version is passed" do
      get '/download-server', :p => "el", :pv => "unknown", :m => "x86_64"
      last_response.status.should == 404
    end

    it "should return 404 an unknown machine is passed" do
      get '/download-server', :p => "el", :pv => "5", :m => "unknown"
      last_response.status.should == 404
    end

    it "should return 404 an invalid version is passed" do
      get '/download-server', :v => "poopypants", :p => "el", :pv => "5", :m => "x86_64"
      last_response.status.should == 404
    end

    it "should return the version specified" do
      get '/download-server', :v => "10.12.0-1", :p => "ubuntu", :pv => "10.04", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_10.12.0-1.ubuntu.10.04_amd64.deb'
    end

    it "should return a rc version if specified" do
      get '/download-server', :v => "10.14.0.rc.0-1", :p => "ubuntu", :pv => "10.04", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_10.14.0.rc.0-1.ubuntu.10.04_amd64.deb'
    end

    it "should return an alpha version if specified" do
      get '/download-server', :v => "11.0.0-alpha.1", :p => "ubuntu", :pv => "10.04", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.0.0-alpha.1-1.ubuntu.10.04_amd64.deb'
    end

    it "should return the latest stable (numeric) version if version is empty string" do
      get '/download-server', :v => "", :p => "ubuntu", :pv => "10.04", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.0.0-1.ubuntu.10.04_amd64.deb'
    end

    it "should return the latest stable (numeric) version if no version is specified" do
      get '/download-server', :p => "ubuntu", :pv => "10.04", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.0.0-1.ubuntu.10.04_amd64.deb'
    end

    it "should return the latest prerelease (numeric) version if no version is specified and prerelease is set" do
      get '/download-server', :p => "ubuntu", :pv => "10.04", :m => "x86_64", :prerelease => "true"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_11.0.0-rc.1-1.ubuntu.10.04_amd64.deb'
    end

    it "should return the latest iteration if no iteration is specified (x.y.z-iteration)" do
      get '/download-server', :v => "10.14.4", :p => "ubuntu", :pv => "10.04", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      http_type_string = URI.split(last_request.url)[0]
      last_request.url.should == http_type_string + '://opscode-omnitruck-test.s3.amazonaws.com/ubuntu/10.04/x86_64/chef-server_10.14.4-2.ubuntu.10.04_amd64.deb'
    end

  end

  describe "/full_list" do

    before :each do
      # Use our dummy data
      Omnitruck.stub!(:build_list).and_return(client_data("build_list"))
    end

    it "endpoint should exist" do
      get '/full_list'
      last_response.should be_ok
    end
  end

  describe "/_status" do
    let(:endpoint){"/_status"}

    before :each do
      # Use our dummy data
      Omnitruck.stub!(:build_list).and_return(client_data("build_list"))
    end

    it "endpoint should exist" do
      get endpoint
      last_response.should be_ok
    end

    it "returns the timestamp of the last poller run" do
      get endpoint
      JSON.parse(last_response.body)["timestamp"].should == "Thu Aug 16 11:48:08 -0700 2012"
    end
  end
end
