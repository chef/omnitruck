require 'spec_helper'

describe 'Omnitruck' do
  def app
    Omnitruck
  end

  describe "/_status" do
    it "returns the timestamp of the last poller run" do
      build_list_json = '{ "run_data": { "timestamp": "Thu Aug 16 11:48:08 -0700 2012" } }'
      File.stub!(:read).and_return(build_list_json)
      get '/_status'
      JSON.parse(last_response.body).should == JSON.parse(build_list_json)['run_data']
    end
  end
end
