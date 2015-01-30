# Install and configure Varnish

include_recipe 'apt'
apt_repository 'varnish-cache' do
  uri "http://repo.varnish-cache.org/#{node['platform']}"
  distribution node['lsb']['codename']
  components ['varnish-4.0']
  key "http://repo.varnish-cache.org/#{node['platform']}/GPG-key.txt"
  deb_src true
  notifies 'nothing', 'execute[apt-get update]', 'immediately'
end

package 'varnish' do
  action [:upgrade, :install]
end

# Default to assuming our server is a 1gb slice
system_total_mem_mb = '1024'
unless node['memory']['total'].nil?
  system_total_mem_mb = (node['memory']['total'].gsub(/kB/, '').to_i / 1024).round
end

# Configure OP cache template
template '/etc/default/varnish' do
  source 'varnish/varnish.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    malloc: (system_total_mem_mb / 16).round
  )
  notifies :restart, 'service[varnish]'
end

# Configure OP cache template
template '/etc/varnish/default.vcl' do
  source 'varnish/default.vcl.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    malloc: (system_total_mem_mb / 16).round,
    my_ip: node['address_map']['my_ip']
  )
  notifies :restart, 'service[varnish]'
end

# Configure varnish's secret
file '/etc/varnish/secret' do
  content "21347d01-01ec-4e79-870b-fe1a7dfcdf23\n"
  owner 'root'
  group 'root'
  mode '0600'
  notifies :restart, 'service[varnish]'
end

# Varnish ulimit
user_ulimit 'varnish' do
  filehandle_limit 131_072
  core_hard_limit 'unlimited'
end

service 'varnish' do
  service_name 'varnish'
  action [:enable, :start]
  supports restart: true
end

# TODO: Configure varnish
# TODO: Setup prefabs for drupal, wordpress
