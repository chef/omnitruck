require "rubygems"
require "sinatra"

# add lib dir to load path
$:.unshift File.join(File.expand_path(File.dirname(__FILE__)), 'lib')

require "./app.rb"

run Omnitruck
