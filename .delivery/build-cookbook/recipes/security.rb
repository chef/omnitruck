
################################################################################
# Welcome to the security phase
#
# This recipe is run as the delivery user
################################################################################

# Are you seeing a patern yet?
include_recipe 'build-cookbook::_handler'

include_recipe 'cia_infra::bundler_install_deps'

execute 'bundler-audit' do
  command "bundle exec bundle-audit update && bundle exec bundle-audit check"
  cwd node['delivery_builder']['repo']
  environment({
    "PATH" => '/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games'
  })
  user node['delivery_builder']['build_user']
end
