# encoding: UTF-8

# The default recipe, included by all other recipes PRIOR to anything else
node.default['chef_client']['locale'] = 'en_US.UTF-8'
# Monitoring - Cloud & Newrelic
cloud_secrets = Chef::EncryptedDataBagItem.load('secrets', 'api_keys')

node.default['mailgun_api_key'] = cloud_secrets['mailgun']
node.default['rackspace'] = {
  cloud_credentials: cloud_secrets['rackspace']
}
node.default['platformstack']['cloud_monitoring']['enabled'] = true
node.default['newrelic']['license'] = cloud_secrets['newrelic']
# Fix for newrelic_plugins
node.default['newrelic']['license_key'] = node['newrelic']['license']

node.default['authorization']['sudo']['passwordless'] = true

include_recipe 'rackops_rolebook'

# Users are defined via Data Bag - look for the "users" data bag
include_recipe 'users::sysadmins'
include_recipe 'apt'
include_recipe 'chef-sugar'
include_recipe 'platformstack::default'
include_recipe 'locale'
ENV['LANG'] = node['locale']['lang']
ENV['LC_ALL'] = node['locale']['lang']
include_recipe 'platformstack::monitors'
unless node.default['newrelic']['license'].nil?
  node.default['newrelic']['application_monitoring']['enabled'] = true
  node.default['newrelic']['application_monitoring']['app_name'] = 'Ubuntu Lamp Template'
  include_recipe 'newrelic'
  user_ulimit 'newrelic' do
    filehandle_soft_limit 8192
    filehandle_hard_limit 8192
  end
end

package 'software-properties-common'
package 'git'

# Address map - a list of all nodes
node.default['address_map']['app_nodes'] = []
node.default['address_map']['app_node_ips'] = []
# And the same list without myself, for ease of use.
node.default['address_map']['other_nodes'] = []
node.default['address_map']['other_node_ips'] = []
node.default['address_map']['redis_masters'] = []
node.default['address_map']['mysql_masters'] = []

node.default['address_map']['redis_port'] = 6379

# If you dont want to use service_net, like some sort of communist (or you use OnMetal)
# Note that this cookbook WILL NOT deal with firewalling for you.
# It is COMPLETELY up to you to firewall approprately.
# I do not open everything up, as we do with a private network.
node.default['address_map']['use_service_net'] = false
node.default['address_map']['service_net_iface'] = 'eth1'

if node['rackspace'].nil?
  # If we're doing testing, bind things locally
  if Chef::Config[:solo]
    node.default['address_map']['my_ip'] = '127.0.0.1'
  # Otherwise, the only reasonable explaination for the rackspace attribute to be missing
  # is that we're on an initial bootstrap. In that case, let's just use the first cloud network attached.
  # This could be more intelligent...
  else
    node.default['address_map']['my_ip'] = '127.0.0.1'
  end
else
  if node['address_map']['use_service_net']
    node.default['address_map']['my_ip'] = node['network']['interfaces'][node['address_map']['service_net_iface']]['addresses'].find {|addr, addr_info| addr_info[:family] == 'inet'}.first
  else
    mynetwork = node['rackspace']['private_networks'].find { |network| network['label'] == node.chef_environment }
    node.default['address_map']['my_ip'] = mynetwork['ips'].first['ip']
    add_iptables_rule('INPUT', '-i eth2 -j ACCEPT', 50, 'allow all traffic on private network')
  end
end

hostsfile_entry node['address_map']['my_ip'] do
  hostname node.name
  unique true
end

if Chef::Config[:solo]
  node.default['address_map']['mysql_masters'] << '127.0.0.1'
else
  all_nodes_raw = search(:node, "chef_environment:#{node.chef_environment}")
  # Sort nodes by name
  all_nodes_raw.sort! { |a, b| a.name <=> b.name }
  if !all_nodes_raw.nil? && !all_nodes_raw.empty? && !all_nodes_raw.first.nil?
    all_nodes_raw.each do |app_node|
      next if app_node.name == node.name
      # This can occur if the foriegn node is _currently_ bootstrapping
      next if app_node['rackspace'].nil?
      if node['address_map']['use_service_net']
        best_ip = app_node['network']['interfaces'][node['address_map']['service_net_iface']]['addresses'].find {|addr, addr_info| addr_info[:family] == 'inet'}.first
      else
        privatenet = app_node['rackspace']['private_networks'].find { |netwrk| netwrk['label'] == node.chef_environment }
        best_ip = privatenet['ips'].first['ip']
      end
      next if best_ip.nil?
      hostsfile_entry best_ip do
        hostname app_node.name
        unique true
      end
      node.default['address_map']['other_nodes'] << app_node.name
      node.default['address_map']['other_node_ips'] << best_ip
      if app_node['tags'].include? 'mysql_master'
        node.default['address_map']['mysql_masters'] << best_ip
      end
      if app_node['tags'].include? 'redis'
        node.default['address_map']['redis_masters'] << best_ip
      end
      if node['address_map']['use_service_net']
        add_iptables_rule('INPUT', "-i #{node['address_map']['service_net_iface']} -s #{best_ip} -j ACCEPT", 50, 'allow all traffic on private network')
      end
    end
  end
  node.default['address_map']['app_nodes'] = node['address_map']['other_nodes']
  node.default['address_map']['app_nodes'] << node.name
  node.default['address_map']['app_node_ips'] = node['address_map']['other_node_ips']
  node.default['address_map']['app_node_ips'] << node['address_map']['my_ip']
end

# Raise the default ulimit for root user - Ubuntu 14.04 sets a very low ulimit -n
user_ulimit 'root' do
  filehandle_limit 4096
end

include_recipe 'sysctl'

# Prevent swapping as much as possible - Cloud providers don't like that
sysctl_param 'vm.swappiness' do
  value 0
end

# Tweak Ubuntu for optimal performance on Cloud Servers
# Increating the receiving and sending TCP window sizes
# The default Ubuntu 14.04 settings are not optimal.
# See http://www.slashroot.in/linux-network-tcp-performance-tuning-sysctl
sysctl_param 'net.ipv4.tcp_window_scaling' do
  value 1
end
sysctl_param 'net.core.rmem_max' do
  value '16777216'
end
sysctl_param 'net.core.wmem_max' do
  value '16777216'
end
sysctl_param 'net.ipv4.tcp_rmem' do
  value '4096 87380 16777216'
end
sysctl_param 'net.ipv4.tcp_wmem' do
  value '4096 16384 16777216'
end
# Do not delay when opening TCP connections
# see https://www.belshe.com/2011/12/03/spdy-configuration-tcp_slow_start_after_idle/
sysctl_param 'net.ipv4.tcp_slow_start_after_idle' do
  value 0
end
