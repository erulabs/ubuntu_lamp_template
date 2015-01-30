package 'nginx' do
  action [:upgrade, :install]
end

# Disable the default site
file '/etc/nginx/sites-enabled/default' do
  action :delete
  notifies :restart, 'service[nginx]'
end

# nginx.conf
template '/etc/nginx/nginx.conf' do
  source 'nginx/nginx.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[nginx]'
end

add_iptables_rule('INPUT', '-p tcp --dport 80 -j ACCEPT', 50, 'allow HTTP')

user_ulimit 'www-data' do
  filehandle_limit 8192
end

# Apache2 service
service 'nginx' do
  service_name 'nginx'
  action [:enable, :start]
  supports restart: true, reload: true, status: true
end
