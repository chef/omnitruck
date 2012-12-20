require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'sinatra'
require 'rack/test'

Sinatra::Base.set :virtual_path, ''
Sinatra::Base.set :build_list, './build_list.json'
Sinatra::Base.set :aws_access_key_id, ''
Sinatra::Base.set :aws_secret_access_key, ''
Sinatra::Base.set :aws_bucket, 'opscode-omnitruck-test'

module Opscode
  module Omnitruck
    module RSpec

      SPEC_DATA = File.expand_path(File.join(File.dirname(__FILE__), "data"))
      
      # Returns the contents of the given server data JSON file as a string
      def server_data(name)
        File.join(SPEC_DATA, "server_data", "#{name}.json")
      end

    end
  end
end

RSpec.configure do |conf|
  conf.include Opscode::Omnitruck::RSpec
  conf.include Rack::Test::Methods
  
  conf.filter_run :focus => true
  conf.run_all_when_everything_filtered = true
  conf.treat_symbols_as_metadata_keys_with_true_values = true
end


