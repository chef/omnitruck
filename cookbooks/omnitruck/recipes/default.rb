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

hab_package 'chef-es/omnitruck-poller' do
  version node['applications']['omnitruck-poller']
end

hab_package 'chef-es/omnitruck-web' do
  version node['applications']['omnitruck-web']
end

hab_package 'chef-es/omnitruck-web-proxy' do
  version node['applications']['omnitruck-web-proxy']
end

hab_sup 'default'

hab_service 'chef-es/omnitruck'
hab_service 'chef-es/omnitruck-poller'
hab_service 'chef-es/omnitruck-web'
hab_service 'chef-es/omnitruck-web-proxy'
