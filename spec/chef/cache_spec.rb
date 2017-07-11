require 'spec_helper'
require 'tmpdir'

# describe Chef::Cache do
#   let(:cache_path) { Dir.mktmpdir }
#   after { FileUtils.rm_rf(cache_path) }
#
#   it "can update the cache from package router" do
#     Chef::Cache.new(cache_path).update
#
#     Chef::Cache::KNOWN_CHANNELS.each do |channel|
#       Chef::Cache::KNOWN_PROJECTS.each do |project|
#         manifest_path = File.join(cache_path, channel, "#{project}-manifest.json")
#         expect(File.exist?(manifest_path)).to be(true)
#
#         expect(JSON.parse(File.read(manifest_path))["run_data"]["timestamp"]).to be_a(String)
#       end
#     end
#   end
# end
