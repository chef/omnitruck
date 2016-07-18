# WIP/TEMP We only want this pipeline to support an acceptance environment
return unless node['delivery']['change']['stage'] == 'acceptance'

include_recipe 'chef-sugar::default'
include_recipe 'delivery-truck::provision'

load_delivery_chef_config

aws_creds = encrypted_data_bag_item_for_environment('cia-creds','chef-secure')
fastly_creds = encrypted_data_bag_item_for_environment('cia-creds','fastly')

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

aws_key_pair node['delivery']['change']['project']  do
  public_key_path ssh_public_key_path
  private_key_path ssh_private_key_path
  allow_overwrite false
end

domain_name = 'chef.io'
fqdn = "#{instance_name}.#{domain_name}"
origin_fqdn = "#{instance_name}-origin.#{domain_name}"
direct_fqdn = "#{instance_name}-direct.#{domain_name}"

subnets = []
instances = []

machine_batch do
  1.upto(instance_quantity) do |i|
    machine "#{instance_name}-#{i}" do
      action :setup
      chef_environment delivery_environment
      attribute 'delivery_org', node['delivery']['change']['organization']
      attribute 'project', node['delivery']['change']['project']
      tags node['delivery']['change']['organization'], node['delivery']['change']['project']
      machine_options CIAInfra.machine_options(node, 'us-west-2', i)
      files '/etc/chef/encrypted_data_bag_secret' => '/etc/chef/encrypted_data_bag_secret'
      converge false
    end

    subnets << CIAInfra.subnet_id(node, CIAInfra.availability_zone('us-west-2', i))
    instances << "#{instance_name}-#{i}"
  end
end

load_balancer "#{instance_name}-elb" do
  load_balancer_options \
    listeners: [{
      port: 80,
      protocol: :http,
      instance_port: 80,
      instance_protocol: :http
    },
    {
      port: 443,
      protocol: :https,
      instance_port: 80,
      instance_protocol: :http,
      server_certificate: CIAInfra.cert_arn
    }],
    subnets: subnets,
    security_groups: CIAInfra.security_groups(node, 'us-west-2'),
    scheme: 'internet-facing'
  machines instances
end

client = AWS::ELB.new(region: 'us-west-2')

route53_record origin_fqdn do
  name "#{origin_fqdn}."
  value lazy { client.load_balancers["#{instance_name}-elb"].dns_name }
  aws_access_key_id aws_creds['access_key_id']
  aws_secret_access_key aws_creds['secret_access_key']
  type 'CNAME'
  zone_id aws_creds['route53'][domain_name]
  sensitive true
end

route53_record direct_fqdn do
  name "#{direct_fqdn}."
  value lazy { client.load_balancers["#{instance_name}-elb"].dns_name }
  aws_access_key_id aws_creds['access_key_id']
  aws_secret_access_key aws_creds['secret_access_key']
  type 'CNAME'
  zone_id aws_creds['route53'][domain_name]
  sensitive true
end

### Fastly Setup
fastly_service = fastly_service fqdn do
  api_key fastly_creds['api_key']
  sensitive true
end

fastly_domain fqdn do
  api_key fastly_creds['api_key']
  service fastly_service.name
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

use_https = fastly_condition 'use_https' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  type 'request'
  statement 'req.http.Fastly-SSL'
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

use_http = fastly_condition 'use_http' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  type 'request'
  statement '!req.http.Fastly-SSL'
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

fastly_backend "#{origin_fqdn}-80" do
  api_key fastly_creds['api_key']
  service fastly_service.name
  address origin_fqdn
  port 80
  request_condition use_http.name
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

fastly_backend "#{origin_fqdn}-443" do
  api_key fastly_creds['api_key']
  service fastly_service.name
  address origin_fqdn
  port 443
  ssl true
  request_condition use_https.name
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

fastly_request_setting 'cache_key' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  hash_keys 'req.url, req.http.host, req.http.Fastly-SSL, req.http.accept, req.http.Accept-Encoding'
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

fastly_cache_setting 'ttl' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  ttl 600 # 10 mins
  stale_ttl 21600 # 6 hrs
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

fastly_s3_logging 's3_logging' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  gzip_level 9
  access_key fastly_creds['logging']['s3']['access_key']
  secret_key fastly_creds['logging']['s3']['secret_key']
  bucket_name fastly_creds['logging']['s3']['bucket_name']
  path "/#{fqdn}"
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

embargo = fastly_condition 'embargo' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  type 'request'
  statement 'geoip.country_code == "CU" || geoip.country_code == "SD" || geoip.country_code == "SY" || geoip.country_code == "KP" || geoip.country_code == "IR"'
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

fastly_response 'embargo' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  request_condition embargo.name
  status 404
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

app_status = fastly_condition 'app_status' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  type 'cache'
  statement 'req.url ~ "^/_status"'
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

fastly_cache_setting 'app_status' do
  api_key fastly_creds['api_key']
  service fastly_service.name
  ttl 0
  stale_ttl 0
  cache_action 'pass'
  cache_condition app_status.name
  sensitive true
  notifies :activate_latest, "fastly_service[#{fqdn}]", :delayed
end

route53_record fqdn do
  name "#{fqdn}."
  value 'g.global-ssl.fastly.net'
  aws_access_key_id aws_creds['access_key_id']
  aws_secret_access_key aws_creds['secret_access_key']
  type 'CNAME'
  zone_id aws_creds['route53'][domain_name]
  sensitive true
end
