#
#
#

execute 'install deps' do
  command "bundle install --deployment"
  cwd node['delivery_builder']['repo']
  environment({
    "PATH" => '/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games'
  })
  user node['delivery_builder']['build_user']
end
