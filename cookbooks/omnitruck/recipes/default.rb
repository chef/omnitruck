#
# Cookbook Name:: omnitruck
# Recipe:: default
#

begin
  release = data_bag_item('omnitruck', node['applications']['omnitruck'])
rescue
  release = nil
end

group 'hab'

user 'hab' do
  group 'hab'
  home '/hab'
end

hab_install 'habitat' do
  action :upgrade
end

hab_package 'chef-es/omnitruck' do
  # TODO: (jtimberman) We need multi-component building, which means
  # we'll have multiple artifacts.
  # if release
  # version version [release['artifact']['pkg_version'], release['artifact']['pkg_release']].join('/')
  # end
end

hab_package 'chef-es/omnitruck-unicorn-proxy' do
  # if release
  # version [release['artifact']['pkg_version'], release['artifact']['pkg_release']].join('/')
  # end
end

hab_service 'chef-es/omnitruck' do
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
    })
  action [:enable, :start]
end

cookbook_file '/etc/cron.d/poller-cron' do
  mode '0755'
end
