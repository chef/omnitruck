require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'sinatra'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end


