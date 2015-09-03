include_recipe 'build-cookbook::_handler'
include_recipe 'chef-sugar::default'
include_recipe 'delivery-truck::deploy'

ENV['AWS_CONFIG_FILE'] = File.join(node['delivery']['workspace']['root'], 'aws_config')
fastly_creds = encrypted_data_bag_item_for_environment('cia-creds','fastly')

ssh = encrypted_data_bag_item_for_environment('cia-creds', 'aws-ssh')
ssh_private_key_path =  File.join(node['delivery']['workspace']['cache'], '.ssh', node['delivery']['change']['project'])
ssh_public_key_path =  File.join(node['delivery']['workspace']['cache'], '.ssh', "#{node['delivery']['change']['project']}.pub")

require 'chef/provisioning/aws_driver'
require 'pp'
with_driver 'aws::us-west-2'

with_chef_server Chef::Config[:chef_server_url],
  client_name: Chef::Config[:node_name],
  signing_key_filename: Chef::Config[:client_key],
  trusted_certs_dir: '/var/opt/delivery/workspace/etc/trusted_certs',
  ssl_verify_mode: :verify_none,
  verify_api_cert: false

if node['delivery']['change']['stage'] == 'delivered'
  instance_name = node['delivery']['change']['project'].gsub(/_/, '-')
else
  instance_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}"
end

directory File.join(node['delivery']['workspace']['cache'], '.ssh')

file ssh_private_key_path do
  content ssh['private_key']
  owner node['delivery_builder']['build_user']
  group node['delivery_builder']['build_user']
  mode '0600'
end

file ssh_public_key_path do
  content ssh['public_key']
  owner node['delivery_builder']['build_user']
  group node['delivery_builder']['build_user']
  mode '0644'
end

['current', 'stable'].each do |rel|

  domain_name = 'chef.io'
  fqdn = "#{rel}.#{instance_name}.#{domain_name}"

  machine_batch do
    1.upto(3) do |i|
      machine "#{rel}-#{instance_name}-#{i}" do
        action :converge
        chef_environment delivery_environment
        machine_options CIAInfra.machine_options(node, 'us-west-2')
        files '/etc/chef/encrypted_data_bag_secret' => '/etc/chef/encrypted_data_bag_secret'
        run_list ['recipe[apt::default]', 'recipe[cia_infra::base]', 'recipe[omnitruck::default]']
        converge true
      end
    end
  end

  fastly_service fqdn do
    action :purge_all
    api_key fastly_creds['api_key']
    sensitive true
  end
end

