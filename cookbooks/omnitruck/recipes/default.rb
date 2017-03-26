#
# Cookbook Name:: omnitruck
# Recipe:: default
#

group 'hab'

user 'hab' do
  group 'hab'
  home '/hab'
end

hab_install 'habitat' do
  action :upgrade
end

hab_package 'chef-es/omnitruck' do
  version node['applications']['omnitruck']
end

hab_package 'chef-es/omnitruck-unicorn-proxy' do
  version node['applications']['omnitruck-unicorn-proxy']
end

hab_service 'chef-es/omnitruck' do
  unit_content(lazy {
    {
      Unit: {
        Description: 'omnitruck',
        After: 'network.target audit.service omnitruck.service'
      },
      Service: {
        Environment: [
          "SSL_CERT_FILE=#{hab('pkg', 'path', 'core/cacerts').stdout.chomp}/ssl/cert.pem",
          "HOME=/hab"
        ],
        ExecStart: "/bin/hab start chef-es/omnitruck",
        Restart: "on-failure"
      }
    }
    }
  )
  action [:enable, :start]
end

hab_service 'chef-es/omnitruck-unicorn-proxy' do
  unit_content(lazy {
    {
      Unit: {
        Description: 'Nginx proxy for Unicorn',
        After: 'network.target audit.service omnitruck.service'
      },
      Service: {
        Environment: "SSL_CERT_FILE=#{hab('pkg', 'path', 'core/cacerts').stdout.chomp}/ssl/cert.pem",
        ExecStart: "/bin/hab start chef-es/omnitruck-unicorn-proxy --listen-gossip 0.0.0.0:9639 --listen-http 0.0.0.0:9632",
        Restart: "on-failure"
      }
    }
    }
  )
  action [:enable, :start]
end

cookbook_file '/etc/cron.d/poller-cron' do
  mode '0755'
end
