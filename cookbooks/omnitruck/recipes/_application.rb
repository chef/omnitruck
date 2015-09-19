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
    :virtual_path => "",
    :metadata_dir => s3_poller_path,
    :stable_aws_metadata_bucket => 'opscode-omnibus-package-metadata',
    :stable_aws_packages_bucket => 'opscode-omnibus-packages',
    :current_aws_metadata_bucket => 'opscode-omnibus-package-metadata-current',
    :current_aws_packages_bucket => 'opscode-omnibus-packages-current',
  )
  action :create
  owner 'omnitruck'
  group 'omnitruck'
  mode '0755'

  notifies :restart, 'runit_service[omnitruck]', :delayed
end

# Omnitruck webapp configuration
unicorn_config "/srv/omnitruck/shared/unicorn.rb" do
  listen '/tmp/.omnitruck.sock.0' => { :backlog => 1024, :tcp_nodelay => true }
  worker_processes 8
  owner 'omnitruck'
  group 'omnitruck'
  mode  '0755'

  notifies :restart, 'runit_service[omnitruck]', :delayed
end

release = data_bag_item('omnitruck', node['applications']['omnitruck'])

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
      retries 3
      retry_delay 10
    end
  }

  notifies :restart, 'runit_service[omnitruck]', :delayed
end

cookbook_file '/etc/cron.d/s3_poller-cron' do
  mode '0755'
end

runit_service 'omnitruck' do
  default_logger true
  log_timeout 3600
end

ruby_block 'wait for service' do
  block do
    [1, 2, 4].take_while do |s|
      sleep(s)
      !::File.exists?('/etc/sv/omnitruck/supervise/ok')
    end

    raise "Timed out waiting for service" unless ::File.exists?('/etc/sv/omnitruck/supervise/ok')
  end
  not_if do
    ::File.exists?('/etc/sv/omnitruck/supervise/ok')
  end
end
