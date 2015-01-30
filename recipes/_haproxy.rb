
if tagged?('redis')
  node.default['address_map']['redis_masters'] << node['address_map']['my_ip']
end

if node['address_map']['redis_masters'].length == 0
  app_nodes = [node['address_map']['my_ip']]
else
  app_nodes = node['address_map']['redis_masters']
end

apt_repository 'haproxy' do
  uri 'ppa:vbernat/haproxy-1.5'
  distribution node['lsb']['codename']
  key '1C61B9CD'
  keyserver 'hkp://keyserver.ubuntu.com:80'
  action :add
end

package 'haproxy' do
  action [:upgrade, :install]
end

template '/etc/haproxy/haproxy.cfg' do
  source 'haproxy.cfg.erb'
  cookbook cookbook_name
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    app_nodes: app_nodes,
    redis_port: node['address_map']['redis_port'],
    listen: node['address_map']['my_ip']
  )
  notifies :restart, 'service[haproxy]'
end

service 'haproxy' do
  supports restart: true, status: true, reload: true
  action [:enable, :start]
end
