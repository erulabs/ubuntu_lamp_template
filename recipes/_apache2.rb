# Install and configure Apache2

# Use Apache 2.4.9, which includes the UDS patch for Unix Socket Support
apt_repository 'apache2' do
  uri 'ppa:ondrej/apache2'
  distribution node['lsb']['codename']
  key 'E5267A6C'
  keyserver 'hkp://keyserver.ubuntu.com:80'
  action :add
end

apache2_modules = ['remoteip', 'proxy_fcgi', 'headers', 'rewrite', 'mpm_event', 'expires']
# Disable mod_php and the prefork MPM since we'll be using EVENT
disabled_apache2_modules = ['mpm_prefork', 'php5']

package 'apache2' do
  action [:upgrade, :install]
end

package 'libapache2-mod-fastcgi' do
  action [:upgrade, :install]
end

# Apache2.conf
template '/etc/apache2/apache2.conf' do
  source 'apache2/apache2.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[apache2]'
end

# ports.conf
template '/etc/apache2/ports.conf' do
  source 'apache2/ports.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    my_ip: node['address_map']['my_ip']
  )
  notifies :restart, 'service[apache2]'
end

# Disable the default site
file '/etc/apache2/sites-enabled/000-default.conf' do
  action :delete
  notifies :restart, 'service[apache2]'
end

# Disabled Apache2 modules
disabled_apache2_modules.each do |mod|
  execute "disable apache module #{mod}" do
    command "a2dismod #{mod}"
    only_if { File.exist?("/etc/apache2/mods-enabled/#{mod}.load") }
    notifies :restart, 'service[apache2]'
  end
end
# Apache2 modules
apache2_modules.each do |mod|
  execute "enable apache module #{mod}" do
    command "a2enmod #{mod}"
    only_if { !File.exist?("/etc/apache2/mods-enabled/#{mod}.load") }
    notifies :restart, 'service[apache2]'
  end
end

template '/etc/apache2/mods-available/mpm_event.conf' do
  source 'apache2/mpm_event.conf.erb'
  notifies :restart, 'service[apache2]'
  mode '0644'
  owner 'root'
  group 'root'
end

add_iptables_rule('INPUT', '-p tcp --dport 80 -j ACCEPT', 50, 'allow HTTP')

user_ulimit 'www-data' do
  filehandle_limit 8192
end

file '/etc/apache2/.htpasswd' do
  owner 'www-data'
  group 'www-data'
  mode '0600'
  content 'mdc:$apr1$0whthoGU$8KOb99kbq13cUDqH2JQIq1'
end

# Apache2 service
service 'apache2' do
  service_name 'apache2'
  action [:enable, :start]
  supports restart: true, reload: true, status: true
end
