include_recipe 'build-cookbook::_handler'
include_recipe 'chef-sugar::default'
include_recipe 'delivery-truck::deploy'

Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

hipchat_creds = encrypted_data_bag_item_for_environment('cia-creds','hipchat')

ENV['AWS_CONFIG_FILE'] = File.join(node['delivery']['workspace']['root'], 'aws_config')

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
  bucket_name = node['delivery']['change']['project'].gsub(/_/, '-')
  instance_name = bucket_name
else
  bucket_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}"
  instance_name = bucket_name
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

machine instance_name do
  action :converge
  chef_environment delivery_environment
  machine_options ssh_username: 'ubuntu',
    location: 'us-west-2a',
    convergence_options: {ssl_verify_mode: :verify_none},
    use_private_ip_for_ssh: true,
    bootstrap_options: {
      image_id: 'ami-b9471c89',
      instance_type: 't2.micro',
      subnet_id: 'subnet-d7059db2',
      security_group_ids: ['sg-96274af3'],
      associate_public_ip_address: true,
      key_name: node['delivery']['change']['project']
    }
  run_list ['recipe[apt::default]','recipe[an_project::default]']
  converge true
end
