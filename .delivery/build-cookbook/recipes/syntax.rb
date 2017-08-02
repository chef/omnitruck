################################################################################
# Welcome to the syntax phase
#
# This recipe is executed as the delivery user
################################################################################

# Check the syntax on the cookbooks in cookbooks/
include_recipe 'delivery-truck::syntax'

execute 'syntax' do
  command "find . -name \\*.rb -exec ruby -c {} \\;"
  cwd node['delivery_builder']['repo']
  environment({
    "PATH" => '/opt/chefdk/embedded/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games'
  })
  user node['delivery_builder']['build_user']
end

include_recipe 'habitat-build::syntax'
