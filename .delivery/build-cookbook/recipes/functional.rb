return if (workflow_stage?('union') || workflow_stage?('rehearsal'))

include_recipe 'chef-sugar::default'

site_name = 'omnitruck'
domain_name = 'chef.io'

if workflow_stage?('delivered')
  bucket_name = node['delivery']['change']['project'].gsub(/_/, '-')
  fqdn = "#{site_name}.#{domain_name}"
else
  bucket_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}"
  fqdn = "#{site_name}-#{node['delivery']['change']['stage']}.#{domain_name}"
end

ruby_block 'check some things we broke' do
  block do
    require 'net/http'

    endpoints = [
      "/_status",
      "/install.sh",
      "/install.ps1",
    ]

    endpoints.each do |dest|
      URI("https://#{fqdn}#{dest}").tap do |uri|
        response = Net::HTTP.get_response(uri)
        unless response.code.to_i == 200
          fail "GET #{uri} returned #{response.code.to_i} instead of a 200"
        end
      end
    end
  end
end

# Teardown Acceptance, Union, and Reheasal Omnitruck instances.
require 'chef/provisioning/aws_driver'
ENV['AWS_CONFIG_FILE'] = File.join(node['delivery']['workspace']['root'], 'aws_config')

with_driver 'aws::us-west-2'

with_chef_server chef_server_details[:chef_server_url],
                 chef_server_details[:options]

# Once delivered to production we stop acceptance instances
if workflow_stage?('delivered')
  machine_batch do
    1.upto(instance_quantity) do |i|
      machine "omnitruck-acceptance-0#{i}" do
        chef_server chef_server_details
        chef_environment 'acceptance'
        attribute 'delivery_org', workflow_change_organization
        attribute 'project', workflow_change_project
        tags "#{workflow_change_organization}", "#{workflow_change_project}"
        machine_options machine_opts(i)
        action :stop
      end
    end
  end
end
