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
