#
# Cookbook Name:: an_rails
# License:: _nginx
#

project_name = 'omnitruck'
node.default['nginx']['default_site_enabled'] = false

include_recipe 'nginx'

template "/etc/nginx/sites-available/#{project_name}" do
  source 'nginx.erb'
  variables project_name: project_name
  notifies :restart, 'service[nginx]'
end

nginx_site project_name

cookbook_file '/etc/logrotate.d/nginx' do
  source 'logrotate-nginx'
  owner 'root'
  group 'root'
  mode '0644'
end

file '/etc/nginx/conf.d/default.conf' do
  action :delete
end
