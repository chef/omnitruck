
include_recipe 'build-cookbook::_handler'
include_recipe 'chef-sugar::default'

Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

hipchat_creds = encrypted_data_bag_item_for_environment('cia-creds','hipchat')

ENV['AWS_CONFIG_FILE'] = File.join(node['delivery']['workspace']['root'], 'aws_config')

if node['delivery']['change']['stage'] == 'delivered'
  bucket_name = node['delivery']['change']['project'].gsub(/_/, '-')
  instance_name = bucket_name
else
  bucket_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}"
  instance_name = bucket_name
end

case node['delivery']['change']['stage']
when 'acceptance'
  hipchat_msg 'Notify Hipchat' do
    room hipchat_creds['room']
    token hipchat_creds['token']
    nickname 'Delivery'
    message "<strong>[#{node['delivery']['change']['project']}] (#{node['delivery']['change']['stage']}:#{node['delivery']['change']['phase']})</strong> <a href=\"http://#{instance_name}.chefdemo.net\">http://#{instance_name}.chefdemo.net</a> is now ready for delivery! Please visit <a href=\"#{change_url}\">Deliver it!</a>"
    color 'green'
    notify false
    sensitive true
  end

when 'delivered'
  hipchat_msg 'Notify Hipchat' do
    room hipchat_creds['room']
    token hipchat_creds['token']
    nickname 'Delivery'
    message "<strong>[#{node['delivery']['change']['project']}] (#{node['delivery']['change']['stage']}:#{node['delivery']['change']['phase']})</strong> <a href=\"http://#{instance_name}.chefdemo.net\">http://#{instance_name}.chefdemo.net</a> is now Delivered!"
    color 'green'
    notify false
    sensitive true
  end
end
