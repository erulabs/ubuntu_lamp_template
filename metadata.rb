name             'ubuntu_lamp_template'
maintainer       'Seandon Mooy'
maintainer_email 'seandon.mooy@gmail.com'
license          ''
description      'Installs/Configures a modern LAMP stack on Ubuntu 14.04'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.0.0'

# 14.04 LTS is our only target for this cookbook
supports 'ubuntu', '= 14.04'

depends 'apt'
depends 'users'
depends 'solr'
depends 'cron'
depends 'newrelic'
depends 'nodejs'
depends 'newrelic_plugins'
depends 'ulimit'
depends 'application'
depends 'chef-sugar'
depends 'composer'
depends 'sysctl'
depends 'locale'
depends 'redisio'
depends 'hostsfile'
depends 'wp-cli'
depends 'logrotate'

# For Rackspace Customers
depends 'rackops_rolebook'
depends 'platformstack'
