################################################################################
# Welcome to the syntax phase
#
# This recipe is executed as the delivery user
################################################################################

# This is as DRY as it gets
include_recipe 'build-cookbook::_handler'

# Check the syntax on the cookbooks in cookbooks/
include_recipe 'delivery-truck::syntax'

execute 'syntax' do
  command "find . -name \\*.rb -exec ruby -c {} \\;"
  cwd node['delivery_builder']['repo']
  environment({
    "PATH" => '/opt/chef/embedded/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games'
  })
  user node['delivery_builder']['build_user']
end
