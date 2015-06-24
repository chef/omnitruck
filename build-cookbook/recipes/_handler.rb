include_recipe 'chef-sugar::default'

Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

hipchat_creds = encrypted_data_bag_item_for_environment('cia-creds','hipchat')

chef_handler "BuildCookbook::HipChatHandler" do
  source File.join(node["chef_handler"]["handler_path"], 'hipchat.rb')
  arguments [hipchat_creds['token'], hipchat_creds['room'], true]
  supports :exception => true
  action :enable
  sensitive true
end

Chef_Delivery::ClientHelper.leave_client_mode_as_delivery
