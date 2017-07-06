name             'build-cookbook'
maintainer       'The Authors'
maintainer_email 'you@example.com'
license          'all_rights'
description      'Installs/Configures build-cookbook'
long_description 'Installs/Configures build-cookbook'
version          '0.1.0'

depends 'delivery-sugar'
depends 'delivery-truck'
depends 'chef_handler'
depends 'chef-sugar'
depends 'route53'
depends 'remote_install'
depends 'brightbox-ruby'
depends 'cia_infra'
depends 'fastly'
depends 'fancy_execute'
depends 'habitat-build'
depends 'expeditor'

gem 'aws-sdk', '~> 2'
