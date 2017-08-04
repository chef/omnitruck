#
# Cookbook Name:: omnitruck
# Recipe:: stop_services
#

service 'hab-sup-default' do
  action :stop
end
