# set the brightbox-ruby package version
# NOTE: ensure this is set to the same version as
# what is set in the default recipe in the build cookbook
# to ensure the vendored bundle is built by and consumed
# by the same ruby version.
ruby_version = '2.2'
node.override['brightbox-ruby']['version'] = ruby_version
include_recipe 'brightbox-ruby::default'

%w(ruby gem).each do |pkg|
  execute "update alternatives for #{pkg} to version #{ruby_version}" do
    command "update-alternatives --set #{pkg} /usr/bin/#{pkg}#{ruby_version}"
    action :run
  end
end

execute '/usr/bin/gem update --system' do
  command "/usr/bin/gem update -q --system '#{ruby_version}'"
  environment 'REALLY_GEM_UPDATE_SYSTEM' => '1'
end

# install some default gems, such as bundler and rake.
# While you would expect brightbox-ruby cookbook to do this,
# it will not work properly if you upgrade ruby on the system
# which requires the "update-alternatives" command above.
# So... we do it again! But we don't use gem_package because
# brightbox-ruby::default already used them and resource-cloning
# will bite us.
node['brightbox-ruby']['gems'].each do |gem_name|
  execute "gem install #{gem_name}" do
    command "/usr/bin/gem install #{gem_name}"
    action :run
  end
end
