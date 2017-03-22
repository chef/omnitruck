################################################################################
# Welcome to the lint phase
#
# This recipe is run as the delivery user
################################################################################

# Run lint against the cookbooks
include_recipe 'delivery-truck::lint'
include_recipe 'habitat-build::lint'
include_recipe 'cia_infra::bundler_install_deps'

#TODO rubocop all the things!
#execute 'lint' do
#  command "rubocop"
#  cwd node['delivery_builder']['repo']
#  environment({
#    "PATH" => '/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games'
#  })
#  user node['delivery_builder']['build_user']
#end
