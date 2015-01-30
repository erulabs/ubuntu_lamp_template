# Install and configure Memcached

package 'memcached' do
  action [:upgrade, :install]
end

template '/etc/memcached.conf' do
  source 'memcached.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    nothing: 'here'
  )
  notifies :restart, 'service[memcached]'
end

# Memcached ulimit
user_ulimit 'memcache' do
  filehandle_limit 8192
  core_hard_limit 'unlimited'
end

service 'memcached' do
  service_name 'memcached'
  action [:enable, :start]
  supports restart: true, status: true
end
