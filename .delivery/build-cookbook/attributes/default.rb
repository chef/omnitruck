# Change the default AMI to Ubuntu 16.04 so we can properly use
# systemd for habitat's services.
default['ciainfra']['image_id'] = 'ami-7ac6491a'
