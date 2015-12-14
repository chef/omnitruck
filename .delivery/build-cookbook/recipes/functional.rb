include_recipe 'build-cookbook::_handler'
include_recipe 'chef-sugar::default'

Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

slack_creds = encrypted_data_bag_item_for_environment('cia-creds','slack')

if ['union', 'rehearsal', 'delivered'].include?(node['delivery']['change']['stage'])
  slack_channels = slack_creds['channels'].push('#operations')
else
  slack_channels = slack_creds['channels']
end

site_name = 'omnitruck'
domain_name = 'chef.io'

if node['delivery']['change']['stage'] == 'delivered'
  bucket_name = node['delivery']['change']['project'].gsub(/_/, '-')
  fqdn = "#{site_name}.#{domain_name}"
else
  bucket_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}"
  fqdn = "#{site_name}-#{node['delivery']['change']['stage']}.#{domain_name}"
end

ruby_block 'check some things we broke' do
  block do
    require 'net/http'
    URI("https://#{fqdn}/chef/metadata-chefdk?p=ubuntu&pv=12.04&m=x86_64").tap do |uri|
      response = Net::HTTP.get_response(uri)
      unless response.code.to_i == 200
        fail "GET #{uri} returned #{response.code.to_i} instead of a 200"
      end
    end

    # Legacy endpoints that are not real should 404
    URI("https://#{fqdn}/chef/metadata-foo?p=ubuntu&pv=12.04&m=x86_64").tap do |uri|
      response = Net::HTTP.get_response(uri)
      unless response.code.to_i == 404
        fail "GET #{uri} returned #{response.code.to_i} instead of a 404"
      end
    end
  end
end

case node['delivery']['change']['stage']
when 'acceptance'
  chef_slack_notify 'Notify Slack' do
    channels slack_channels
    webhook_url slack_creds['webhook_url']
    username slack_creds['username']
    message "*[#{node['delivery']['change']['project']}] (#{node['delivery']['change']['stage']}:#{node['delivery']['change']['phase']})* <a href=\"https://#{fqdn}\">https://#{fqdn}</a> is now ready for delivery! Please visit <a href=\"#{change_url}\">Deliver it!</a>"
    sensitive true
  end

when 'delivered'
  chef_slack_notify 'Notify Slack' do
    channels slack_channels
    webhook_url slack_creds['webhook_url']
    username slack_creds['username']
    message "*[#{node['delivery']['change']['project']}] (#{node['delivery']['change']['stage']}:#{node['delivery']['change']['phase']})* <a href=\"https://#{fqdn}\">https://#{fqdn}</a> is now Delivered!"
    sensitive true
  end
end
