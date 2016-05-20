################################################################################
# Welcome to the unit phase
#
# This phase is run as the delivery user
################################################################################

# Setup the handler goodness as was discussed in the default recipe
include_recipe 'build-cookbook::_handler'

# Run unit tests on the cookbooks that are in cookbooks/
include_recipe 'delivery-truck::unit'

include_recipe 'cia_infra::bundler_install_deps'

execute 'run rspec' do
  command "bundle exec rake spec"
  cwd node['delivery_builder']['repo']
  environment({
    "PATH" => '/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games'
  })
  user node['delivery_builder']['build_user']
end
