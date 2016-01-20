# set the brightbox-ruby package version
# NOTE: ensure this is set to the same version as
# what is set in the default recipe in the build cookbook
# to ensure the vendored bundle is built by and consumed
# by the same ruby version.
ruby_version = '2.2'
node.override['brightbox-ruby']['version'] = ruby_version
include_recipe 'brightbox-ruby::default'

execute "update alternatives to ruby #{ruby_version}" do
  command "update-alternatives --set ruby /usr/bin/ruby#{ruby_version}"
  action :run
end

execute '/usr/bin/gem update --system' do
  command "/usr/bin/gem update -q --system '#{ruby_version}'"
  environment 'REALLY_GEM_UPDATE_SYSTEM' => '1'
end

# install some default gems, such as bundler, rake, etc.
# While you would expect brightbox-ruby cookbook to do this,
# it will not work properly if you upgrade ruby on the system
# which requires the "update-alternatives" command above.
# So... we do it again!
node['brightbox-ruby']['gems'].each do |gem|
  gem_package gem do
    action :upgrade
    gem_binary '/usr/bin/gem'
  end
end
