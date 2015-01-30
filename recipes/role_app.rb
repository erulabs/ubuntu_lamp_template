# The application role, which runs everything needed to power any of the PHP applications

# Default Recipe
include_recipe "#{cookbook_name}::default"

# Gluster shared file system
include_recipe "#{cookbook_name}::_gluster"

# local memory store (used when redis is not possible)
include_recipe "#{cookbook_name}::_memcached"

service 'nginx' do
  action :stop
end
service 'nginx' do
  action :disable
end

# Apache2 - we will use the event MPM and connect to PHP-FPM by default
include_recipe "#{cookbook_name}::_apache2"

# Varnish - Will be VERY safe/default to start with, simply caching
# static requests. TODO: Add prefabs for Wordpress, Drupal, etc.
include_recipe "#{cookbook_name}::_varnish"

# Nginx web server
# include_recipe "#{cookbook_name}::_nginx"

# Configure this server as a PHP web server
include_recipe "#{cookbook_name}::_php56"

# HAProxy for redis
include_recipe "#{cookbook_name}::_haproxy"

# Highly available redis
include_recipe "#{cookbook_name}::_redis"
