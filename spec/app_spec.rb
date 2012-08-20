require 'spec_helper'

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
    before do
      build_list_json = { 'run_data' => { 'timestamp' => 'Thu Aug 16 11:48:08 -0700 2012' }, 
                          'el' => { '5' => { 'x86_64' => { '10.12.0-1' => '/el/5/x86_64/chef-10.12.0-1.el5.x86_64.rpm',
                                                           '10.14.8-1' => '/el/5/x86_64/chef-10.14.8-1.el5.x86_64.rpm',
                                                           '10.14.8.rc.0-1' => '/el/5/x86_64/chef-10.14.8.rc.0-1.el5.x86_64.rpm' },
                                             'i686' => { '10.12.0-1' => '/el/5/x86_64/chef-10.12.0-1.el5.i686.rpm',
                                                         '10.14.8-1' => '/el/5/x86_64/chef-10.14.8-1.el5.i686.rpm',
                                                         '10.14.8.rc.0-1' => '/el/5/x86_64/chef-10.14.8.rc.0-1.el5.i686.rpm' },
                                           },
                                    '6' => { 'x86_64' => { '10.12.0-1' => '/el/6/x86_64/chef-10.12.0-1.el6.x86_64.rpm',
                                                           '10.12.0-10' => '/el/6/x86_64/chef-10.12.0-10.el6.x86_64.rpm' },
                                             'i686' => { '10.12.0-1' => '/el/6/i686/chef-10.12.0-1.el6.i686.rpm',
                                                         '10.12.0-10' => '/el/6/i686/chef-10.12.0-10.el6.i686.rpm' },
                                           }
                                  }
                        }
      File.stub!(:read).and_return(JSON.generate(build_list_json))
    end

    # This should probably return a 400
    # required: platform, platform_version, machine
    it "should return 404 if required parameters are not passed" do
      get '/download'
      last_response.status.should == 404
    end

    it "should return the version specified" do
      get '/download', :v => "10.12.0-1", :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      last_request.url.should == 'https://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.12.0-1.el5.x86_64.rpm'
    end

    it "should return a rc/beta version if specified" do
      get '/download', :v => "10.14.8.rc.0-1", :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      last_request.url.should == 'https://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.14.8.rc.0-1.el5.x86_64.rpm'
    end

    it "should return the latest stable (numeric) version if version is empty string" do
      get '/download', :v => "", :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      last_request.url.should == 'https://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.14.8-1.el5.x86_64.rpm'
    end

    it "should return the latest stable (numeric) version if no version is specified" do
      get '/download', :p => "el", :pv => "5", :m => "x86_64"
      last_response.should be_redirect
      follow_redirect!
      last_request.url.should == 'https://opscode-omnitruck-test.s3.amazonaws.com/el/5/x86_64/chef-10.14.8-1.el5.x86_64.rpm'
    end

    it "should return the latest iteration if no iteration is specified (x.y.z-iteration)" do
      get '/download', :v => "10.12.0", :p => "el", :pv => "6", :m => "i686"
      last_response.should be_redirect
      follow_redirect!
      last_request.url.should == 'https://opscode-omnitruck-test.s3.amazonaws.com/el/6/i686/chef-10.12.0-10.el6.i686.rpm'
    end

  end

  describe "/full_list" do
    it "endpoint should exist" do
      get '/full_list'
      last_response.should be_ok
    end
  end

  describe "/_status" do
    it "endpoint should exist" do
      get '/_status'
      last_response.should be_ok
    end

    it "returns the timestamp of the last poller run" do
      build_list_json = '{ "run_data": { "timestamp": "Thu Aug 16 11:48:08 -0700 2012" } }'
      File.stub!(:read).and_return(build_list_json)
      get '/_status'
      JSON.parse(last_response.body).should == JSON.parse(build_list_json)['run_data']
    end
  end
end
