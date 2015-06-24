include_recipe 'build-cookbook::_handler'
include_recipe 'chef-sugar::default'
include_recipe 'delivery-truck::provision'

Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

hipchat_creds = encrypted_data_bag_item_for_environment('cia-creds','hipchat')
aws_creds = encrypted_data_bag_item_for_environment('cia-creds','chef-aws')

if node['delivery']['change']['stage'] == 'acceptance'
  hipchat_msg 'Notify Hipchat' do
    room hipchat_creds['room']
    token hipchat_creds['token']
    nickname 'Delivery'
    message "<strong>[#{node['delivery']['change']['project']}] (#{node['delivery']['change']['stage']}:#{node['delivery']['change']['phase']})</strong> Beginning Provisioning"
    color 'green'
    notify false
    sensitive true
  end
end

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

aws_key_pair node['delivery']['change']['project']  do
  public_key_path ssh_public_key_path
  private_key_path ssh_private_key_path
  allow_overwrite false
end

machine instance_name do
  action :setup
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
  run_list ['recipe[an_project::default]']
  converge false
end

load_balancer "#{instance_name}-elb" do
  load_balancer_options \
    listeners: [{
      port: 80,
      protocol: :http,
      instance_port: 80,
      instance_protocol: :http
    }],
    subnets: ['subnet-d7059db2'],
    security_groups: ['sg-96274af3'],
    scheme: 'internet-facing'
  machines [instance_name]
end

client = AWS::ELB.new(region: 'us-west-2')

route53_record "#{instance_name}.chefdemo.net" do
  name "#{instance_name}.chefdemo.net."
  value lazy { client.load_balancers["#{instance_name}-elb"].dns_name }
  aws_access_key_id aws_creds['access_key_id']
  aws_secret_access_key aws_creds['secret_access_key']
  type 'CNAME'
  zone_id 'Z20GXCA1KGHB6A'
  sensitive true
end
