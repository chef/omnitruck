#
# Cookbook Name:: omnitruck
# Recipe:: default
#

group 'hab'

user 'hab' do
  group 'hab'
  home '/hab'
  system true
end

hab_install 'habitat' do
  action :upgrade
end

hab_package 'chef-es/omnitruck' do
  version node['applications']['omnitruck']
end

hab_package 'chef-es/omnitruck-unicorn-proxy' do
  version node['applications']['omnitruck-unicorn-proxy']
end

hab_sup 'default'

hab_service 'chef-es/omnitruck'
hab_service 'chef-es/omnitruck-unicorn-proxy'

cookbook_file '/usr/local/bin/poller-cron.sh' do
  mode '0755'
end

cookbook_file '/etc/cron.d/poller-cron' do
  mode '0755'
end
