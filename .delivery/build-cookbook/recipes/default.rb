################################################################################
#
# Welcome to omnitruck
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

# We setup some github keys so that we can pull down private cookbooks and repos
# from github as the chef-delivery user.
include_recipe 'build-cookbook::_github'

# We include the delivery-truck default recipe so any setup that delivery-truck
# needs gets done.
include_recipe 'delivery-truck::default'

# We want to update slack so we do the setup here.
include_recipe 'chef_slack::default'

# We use the route53 resource later on so we need to include it here to get gems
# and other dependencies installed.
#include_recipe 'route53::default'

chef_gem 'aws-sdk' do
  action :install
  version '~> 2'
  compile_time true
end

include_recipe 'fastly::default'

# We enter client mode, which means we are now talking to the delivery chef server
# instead of the chef-zero invocation this run was started in context of.
Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

# We need slack creds later on, so we get them here.
slack_creds = encrypted_data_bag_item_for_environment('cia-creds','slack')

# We need aws creds so we get them here.
aws_creds = encrypted_data_bag_item_for_environment('cia-creds', 'chef-cia')

cookbook_file 'slack.rb' do
  path File.join(node['chef_handler']['handler_path'], 'slack.rb')
end.run_action(:create)

chef_handler "BuildCookbook::SlackHandler" do
  source File.join(node["chef_handler"]["handler_path"], 'slack.rb')
  arguments [
    :webhook_url => slack_creds['webhook_url'],
    :channels  => slack_creds['channels'],
    :username => slack_creds['username']
  ]
  supports :exception => true
  sensitive true
  action :enable
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

# install brightbox-ruby
# NOTE: ensure the same version is set here as is set in the omnitruck
# cookbook itself to ensure the vendored bundle is built with and
# consumed by the same ruby version.
ruby_version = '2.2'
node.override['brightbox-ruby']['version'] = ruby_version
include_recipe 'brightbox-ruby::default'

%w(ruby gem).each do |pkg|
  execute "update alternatives for #{pkg} to version #{ruby_version}" do
    command "update-alternatives --set #{pkg} /usr/bin/#{pkg}#{ruby_version}"
    action :run
  end
end

# Enable Debug Goodness
chef_gem 'pry-remote'

# Really make sure brightbox got the right ruby
if node['brightbox-ruby']['rubygems_version']
  execute '/usr/bin/gem update --system' do
    command "/usr/bin/gem update -q --system '#{node['brightbox-ruby']['rubygems_version']}'"
    environment 'REALLY_GEM_UPDATE_SYSTEM' => '1'
    not_if "which gem && gem --version | grep -q '#{node['brightbox-ruby']['rubygems_version']}'"
  end
end

# install some default gems, such as bundler and rake.
# While you would expect brightbox-ruby cookbook to do this,
# it will not work properly if you upgrade ruby on the system
# which requires the "update-alternatives" command above.
# So... we do it again! But we don't use gem_package because
# brightbox-ruby::default already used them and resource-cloning
# will bite us.
node['brightbox-ruby']['gems'].each do |gem_name|
  execute "gem install #{gem_name}" do
    command "/usr/bin/gem install #{gem_name}"
    action :run
  end
end

# Regenerate the binstups for rubygems-bundler.
execute "gem regenerate_binstubs" do
  action :nothing
  subscribes :run, resources('gem_package[rubygems-bundler]')
end

# NOKOGIRI!!!!!
package 'zlib1g-dev'
