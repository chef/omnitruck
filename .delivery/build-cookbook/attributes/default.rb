# Change the default AMI to Ubuntu 16.04 so we can properly use
# systemd for habitat's services.
default['ciainfra']['image_id'] = 'ami-7ac6491a'
default['ciainfra']['security_groups'] = ['sg-9d9223f9']

default['delivery']['project_apps'] = %w(
  omnitruck-app
  omnitruck-poller
  omnitruck-web
  omnitruck-web-proxy
)
