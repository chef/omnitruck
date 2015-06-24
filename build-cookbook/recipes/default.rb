################################################################################
#
# Welcome to an_project
#
# This is the default recipe. It is the only recipe that runs as root. Here we
# install all the components we need to be functional or have to be done as 
# root.
#
################################################################################

# We include chef-sugar because it gives us easy ways to interact with encrypted
# data bags. It may go away in the future.
include_recipe 'chef-sugar::default'

# We use the chef_handler recipe/cookbook so that we can register the an
# exception handler. The only issue here is that we register it inside the
# recipe so we are only going to get converge time exceptions.
include_recipe 'chef_handler::default'

# We include the hipchat recipe here so the libraries and such can be in place
# so we are later able to use the hipchat_notify recipe
include_recipe 'hipchat::default'

# We setup some github keys so that we can pull down private cookbooks and repos
# from github as the chef-delivery user.
include_recipe 'build-cookbook::_github'

# We include the delivery-truck default recipe so any setup that delivery-truck
# needs gets done.
include_recipe 'delivery-truck::default'

# We use the route53 resource later on so we need to include it here to get gems
# and other dependencies installed.
include_recipe 'route53::default'

# We enter client mode, which means we are now talking to the delivery chef server
# instead of the chef-zero invocation this run was started in context of.
Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

# We need hipchat creds later on, so we get them here.
hipchat_creds = encrypted_data_bag_item_for_environment('cia-creds','hipchat')

# We need aws creds so we get them here.
aws_creds = encrypted_data_bag_item_for_environment('cia-creds', 'chef-cia')

# This is the actual hipchat handler. We place it on disk so we can register it.
cookbook_file "hipchat.rb" do
  path File.join(node["chef_handler"]["handler_path"], 'hipchat.rb')
end.run_action(:create)

# This actually registers the hipchat handler we wrote out to disk above. It is 
# the firs time we make use of the sensitive attribute. It is important to not 
# expose our creds in the output to the delivery server.
chef_handler "BuildCookbook::HipChatHandler" do
  source File.join(node["chef_handler"]["handler_path"], 'hipchat.rb')
  arguments [hipchat_creds['token'], hipchat_creds['room'], true]
  supports :exception => true
  action :enable
  sensitive true
end

# Here we are installing the aws cli that is needed durring publish. The python
# install is actually done during the setup of the build nodes.
#
# TODO Move the python recipe back into the build cookbook
execute 'install awscli' do
  command 'pip install awscli'
  not_if { File::exists?('/usr/local/bin/aws') }
end

# chef-provisioning requires an aws config file. This generates the content for 
# that file.
aws_config_contents = <<EOF
[default]
region = us-east-1
aws_access_key_id = #{aws_creds['access_key_id']}
aws_secret_access_key = #{aws_creds['secret_access_key']}
EOF

# This figures out where we are going to put the config file.
aws_config_filename = File.join(node['delivery']['workspace']['root'], 'aws_config')

# And here we write it out.
file aws_config_filename do
  sensitive true
  content aws_config_contents
end

# Here we leave client mode. I don't actually understand the implications of not leaving,
# but it seems like a good idea.
Chef_Delivery::ClientHelper.leave_client_mode_as_delivery

include_recipe 'brightbox-ruby::default'

execute 'install bundler' do
  command '/usr/bin/gem install bundler'
  not_if { File::exists?('/usr/local/bin/bundle') }
end
