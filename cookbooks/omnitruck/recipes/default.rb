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

packages = %w(omnitruck-app omnitruck-poller omnitruck-web omnitruck-web-proxy)

# The supervisor must be running before we can send an unload since the
# resource will try to hit the supervisors http management endpoint.
hab_sup 'default'

packages.each do |pkg|
  hab_package "chef-es/#{pkg}" do
    version node['applications'][pkg]
    notifies :unload, "hab_service[chef-es/#{pkg}]", :immediately
  end
end

packages.each do |pkg|
  hab_service "chef-es/#{pkg}"
end
