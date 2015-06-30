include_recipe 'runit::default'

directory '/srv/omnitruck/shared' do
  owner 'omnitruck'
  group 'omnitruck'
end

directory '/srv/omnitruck/shared/pids' do
  owner 'omnitruck'
  group 'omnitruck'
end

# S3 Poller configuration
s3_poller_path = "/srv/omnitruck/shared/s3_poller_data/"
s3_poller_cache_path = "#{s3_poller_path}/cache"

directory s3_poller_path do
  owner 'omnitruck'
  group 'omnitruck'
end

directory s3_poller_cache_path do
  owner 'omnitruck'
  group 'omnitruck'
end


template "/srv/omnitruck/shared/s3_poller_config.yml" do
  source "s3_poller_config.yml.erb"
  variables(
    :app_environment => "production",
    :virtual_path => "/chef",
    :build_list_v1 => "#{s3_poller_path}/build_list_v1.json",
    :build_list_v2 => "#{s3_poller_path}/build_list_v2.json",
    :build_server_list_v1 => "#{s3_poller_path}/build_server_list_v1.json",
    :build_server_list_v2 => "#{s3_poller_path}/build_server_list_v2.json",
    :build_chefdk_list_v1 => "#{s3_poller_path}/build_chefdk_list_v1.json",
    :build_chefdk_list_v2 => "#{s3_poller_path}/build_chefdk_list_v2.json",
    :build_container_list_v1 => "#{s3_poller_path}/build_container_list_v1.json",
    :build_container_list_v2 => "#{s3_poller_path}/build_container_list_v2.json",
    :build_angrychef_list_v1 => "#{s3_poller_path}/build_angrychef_list_v1.json",
    :build_angrychef_list_v2 => "#{s3_poller_path}/build_angrychef_list_v2.json",
    :chef_platform_names => "#{s3_poller_path}/chef-platform-names.json",
    :chef_server_platform_names => "#{s3_poller_path}/chef-server-platform-names.json",
    :chefdk_platform_names => "#{s3_poller_path}/chefdk-platform-names.json",
    :chef_container_platform_names => "#{s3_poller_path}/chef-container-platform-names.json",
    :angrychef_platform_names => "#{s3_poller_path}/angrychef-platform-names.json",
    :aws_metadata_bucket => 'opscode-omnibus-package-metadata',
    :aws_packages_bucket => 'opscode-omnibus-packages'
  )
  action :create
  owner 'omnitruck'
  group 'omnitruck'
  mode '0755'
end

# Omnitruck webapp configuration
unicorn_config "/srv/omnitruck/shared/unicorn.rb" do
  listen 4880 => { :backlog => 1024, :tcp_nodelay => true }
  worker_processes 8
  owner 'omnitruck'
  group 'omnitruck'
  mode  '0755'
end

release = {
  'version' => '2015-06-24_1829',
  'artifact_location' => 'https://s3.amazonaws.com/omnitruck-artifacts/omnitruck-2015-06-24_1829.tar.gz'
}

artifact_deploy 'omnitruck' do
  version release['version']
  artifact_location release['artifact_location']
  deploy_to '/srv/omnitruck'
  owner 'omnitruck'
  group 'omnitruck'
  action :deploy

  symlinks(
    'unicorn.rb' => 'config/unicorn.rb',
    's3_poller_config.yml' => 'config/config.yml',
    's3_poller_data/cache' => 'release-metadata-cache'
  )

  configure Proc.new {
    execute 's3_poller' do
      command "env PATH=/usr/local/bin:$PATH bundle exec ./s3_poller -e production"
      action  :run
      user    "omnitruck"
      group   "omnitruck"
      cwd     release_path
    end
  }
end

cookbook_file '/etc/cron.d/s3_poller-cron' do
  mode '0755'
end
