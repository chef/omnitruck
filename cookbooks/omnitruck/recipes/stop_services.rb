#
# Cookbook Name:: omnitruck
# Recipe:: stop_services
#

hab_service 'chef-es/omnitruck-app' do
  action :stop
end

hab_service 'chef-es/omnitruck-poller' do
  action :stop
end

hab_service 'chef-es/omnitruck-web' do
  action :stop
end

hab_service 'chef-es/omnitruck-web-proxy' do
  action :stop
end
