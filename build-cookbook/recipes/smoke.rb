include_recipe 'build-cookbook::_handler'
include_recipe 'chef-sugar::default'

Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

hipchat_creds = encrypted_data_bag_item_for_environment('cia-creds','hipchat')

ENV['AWS_CONFIG_FILE'] = File.join(node['delivery']['workspace']['root'], 'aws_config')

ssh = encrypted_data_bag_item_for_environment('cia-creds', 'aws-ssh')
ssh_private_key_path =  File.join(node['delivery']['workspace']['cache'], '.ssh', node['delivery']['change']['project'])
ssh_public_key_path =  File.join(node['delivery']['workspace']['cache'], '.ssh', "#{node['delivery']['change']['project']}.pub")

if node['delivery']['change']['stage'] == 'delivered'
  bucket_name = node['delivery']['change']['project'].gsub(/_/, '-')
  instance_name = bucket_name
else
  bucket_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}"
  instance_name = bucket_name
end

instance = search(:node, "name:#{instance_name}").first

# This is going to need actual tests
