require 'rspec/core/rake_task'

# we need this to resolve files required by lib/
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

RSpec::Core::RakeTask.new(:spec)

# Refresh all of our spec data fixtures
task :refresh_data do |t|
  require 'chef/cache'

  Chef::Cache::KNOWN_PROJECTS.each do |project|
    Chef::Cache::KNOWN_CHANNELS.each do |channel|
      manifest = Chef::ProjectManifest.new(project, channel)
      manifest.generate
      File.open("spec/data/#{channel}/#{project}-manifest.json", 'w') { |f| f.write(manifest.serialize) }
    end
  end
end