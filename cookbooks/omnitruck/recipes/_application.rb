include_recipe 'runit::default'

directory '/srv/omnitruck/shared' do
  owner 'omnitruck'
  group 'omnitruck'
end

directory '/srv/omnitruck/shared/pids' do
  owner 'omnitruck'
  group 'omnitruck'
end

# Poller configuration
poller_path = "/srv/omnitruck/shared/poller_data/"
poller_cache_path = "#{poller_path}/cache"

directory poller_path do
  owner 'omnitruck'
  group 'omnitruck'
end

directory poller_cache_path do
  owner 'omnitruck'
  group 'omnitruck'
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
    'poller_config.yml' => 'config/config.yml',
    'poller_data/cache' => 'release-metadata-cache'
  )

  before_symlink Proc.new {
    # Omnitruck webapp configuration
    unicorn_config "/srv/omnitruck/shared/unicorn.rb" do
      listen '/tmp/.omnitruck.sock.0' => { :backlog => 1024, :tcp_nodelay => true }
      worker_processes 8
      owner 'omnitruck'
      group 'omnitruck'
      mode  '0755'
    end

    template "/srv/omnitruck/shared/poller_config.yml" do
      source "poller_config.yml.erb"
      variables(
        :app_environment => "production",
        :virtual_path => "",
        :metadata_dir => poller_path
      )
      action :create
      owner 'omnitruck'
      group 'omnitruck'
      mode '0755'
    end

    cookbook_file '/etc/cron.d/poller-cron' do
      mode '0755'
    end

    # remove the historical s3_poller cron job.
    file '/etc/cron.d/s3_poller-cron' do
      action :delete
    end
  }

  restart Proc.new {
    execute 'poller' do
      command "env PATH=/usr/local/bin:$PATH bundle exec ./poller -e production"
      user    "omnitruck"
      group   "omnitruck"
      cwd     release_path
      retries 3
      retry_delay 10
    end

    runit_service 'omnitruck' do
      default_logger true
      log_timeout 3600
      action :enable
      options({
        :release_path => release_path
      })
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

    runit_service 'omnitruck' do
      action :restart
    end
  }
end
