include_recipe 'chef-sugar::default'

fastly_creds = with_server_config { encrypted_data_bag_item_for_environment('cia-creds','fastly') }

ENV['AWS_CONFIG_FILE'] = File.join(node['delivery']['workspace']['root'], 'aws_config')

ssh = with_server_config { encrypted_data_bag_item_for_environment('cia-creds', 'aws-ssh') }
ssh_private_key_path =  File.join(node['delivery']['workspace']['cache'], '.ssh', node['delivery']['change']['project'])
ssh_public_key_path =  File.join(node['delivery']['workspace']['cache'], '.ssh', "#{node['delivery']['change']['project']}.pub")

require 'chef/provisioning/aws_driver'
require 'pp'
with_driver 'aws::us-west-2'

with_chef_server chef_server_details[:chef_server_url],
                 chef_server_details[:options]

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


domain_name = 'chef.io'
fqdn = "#{instance_name}.#{domain_name}"

# Instances using latest omnitruck habitat packages
# Prepended instance number with a "0" to force creation of new instances
machine_batch do
  1.upto(instance_quantity) do |i|
    machine "#{instance_name}-0#{i}" do
      chef_server chef_server_details
      chef_environment delivery_environment
      attribute 'delivery_org', node['delivery']['change']['organization']
      attribute 'project', node['delivery']['change']['project']
      tags node['delivery']['change']['organization'], node['delivery']['change']['project']
      machine_options machine_opts(i)
      files '/etc/chef/encrypted_data_bag_secret' => '/etc/chef/encrypted_data_bag_secret'
      run_list ['recipe[apt::default]', 'recipe[cia_infra::base]', 'recipe[omnitruck::default]']
      converge true
      action :converge
    end
  end
end

# Resources for managing old instances
# These will eventually be destroyed
# Keeping them to prevent downtime
# action has been changed to :nothing
machine_batch do
  1.upto(instance_quantity) do |i|
    machine "#{instance_name}-#{i}" do
      chef_server chef_server_details
      chef_environment delivery_environment
      attribute 'delivery_org', node['delivery']['change']['organization']
      attribute 'project', node['delivery']['change']['project']
      tags node['delivery']['change']['organization'], node['delivery']['change']['project']
      machine_options machine_opts(i)
      files '/etc/chef/encrypted_data_bag_secret' => '/etc/chef/encrypted_data_bag_secret'
      run_list ['recipe[build-essential]', 'recipe[apt::default]', 'recipe[cia_infra::base]', 'recipe[omnitruck::default]']
      converge true
      action :nothing
    end
  end
end

fastly_service fqdn do
  action :purge_all
  api_key fastly_creds['api_key']
  sensitive true
end

# Monitoring
ruby_block 'Add ELB Monitoring' do
  block do

    require 'aws-sdk'

    cloudwatch = ::Aws::CloudWatch::Client.new(
      region: 'us-west-2',
      credentials: ::Aws::SharedCredentials.new(path: ENV["AWS_CONFIG_FILE"])
    )

    cloudwatch.put_metric_alarm({
      alarm_name: "#{instance_name}-elb-500s",
      alarm_description: "Sum of 500s is Greater than 50 for the last 2 minutes on #{instance_name}-elb",
      actions_enabled: true,
      ok_actions: [sns_topic],
      alarm_actions: [sns_topic],
      metric_name: "HTTPCode_Backend_5XX",
      namespace: "AWS/ELB",
      statistic: "Sum",
      dimensions: [
        {
          name: "LoadBalancerName",
          value: "#{instance_name}-elb",
        },
      ],
      period: 60,
      evaluation_periods: 2,
      threshold: 50.0,
      comparison_operator: "GreaterThanOrEqualToThreshold",
    })

    cloudwatch.put_metric_alarm({
      alarm_name: "#{instance_name}-elb-latency",
      alarm_description: "Average latency on #{instance_name}-elb is greater than 500ms for the last 2 minutes",
      actions_enabled: true,
      ok_actions: [sns_topic],
      alarm_actions: [sns_topic],
      metric_name: "Latency",
      namespace: "AWS/ELB",
      statistic: "Average",
      dimensions: [
        {
          name: "LoadBalancerName",
          value: "#{instance_name}-elb",
        },
      ],
      period: 60,
      unit: "Seconds",
      evaluation_periods: 2,
      threshold: 0.5,
      comparison_operator: "GreaterThanOrEqualToThreshold",
    })
  end
end
