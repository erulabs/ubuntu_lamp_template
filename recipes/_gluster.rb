
apt_repository 'ubuntu-glusterfs-3.4' do
  uri 'http://ppa.launchpad.net/semiosis/ubuntu-glusterfs-3.4/ubuntu'
  distribution node['lsb']['codename']
  components ['main']
  keyserver 'keyserver.ubuntu.com'
  key '774BAC4D'
  deb_src true
  not_if do
    File.exist?('/etc/apt/sources.list.d/ubuntu-glusterfs-3.4.list')
  end
end

gluster_packages = ['xfsprogs', 'glusterfs-client', 'glusterfs-server']
gluster_packages.each do |pkg|
  package pkg do
    action [:upgrade, :install]
  end
end

service 'glusterfs-server' do
  action [:enable, :start]
  provider Chef::Provider::Service::Upstart
end

# Volumes to create
node.default['gluster']['volumes'] = []
# Default path to store volumes - note that this by default
# implies that your bricks will be stored on the root partition
# this is not recommened for large Gluster Clusters - instead it recommends
# dedicated disks. However, for typical PHP applications, hosted on small cloud instances
# which have SSDs, there is really no problem using the root filesystem.
# If you'd like - take care of mounting and formatting your filesystem, then override the brick_path
# such that bricks are written to your disk rather than to the root partition.
node.default['gluster']['brick_path'] = '/gluster'

include_recipe "#{cookbook_name}::filesystems"

directory node['gluster']['brick_path'] do
  recursive true
  action :create
end

num_local_peers = Integer(Mixlib::ShellOut.new('ls -1 /var/lib/glusterd/peers/ | wc -l').run_command.stdout)
gluster_member_count = search(:node, "tags:*gluster_member* AND chef_environment:#{node.chef_environment}").length
log "GLUSTER: I currently have #{num_local_peers} peers and Chef sees #{gluster_member_count} gluster members."

# If we have peers, we're part of the cluster, therefore, we can add others
if num_local_peers > 0
  tag('gluster_member')
end

# If we're the second server, and have no peers, and there are no other Gluster servers, we can build the cluster now!
if node['address_map']['other_node_ips'].length == 1 && num_local_peers == 0 && gluster_member_count == 0
  tag('gluster_member')
end

# Ensure the mount points always exist
node['gluster']['mounts'].each do |mount|
  directory mount['path'] do
    recursive true
    action :create
  end
end

# If we're part of the Gluster cluster, we can add other nodes.
# If we're not, don't mount the drives
if tagged?('gluster_member')
  log "GLUSTER: I aim to have #{node['address_map']['other_node_ips'].length} peers."
  node['address_map']['other_node_ips'].each do |peer|
    execute "gluster peer probe #{peer} --mode=script" do
      action :run
      not_if "egrep '^hostname.+=#{peer}$' /var/lib/glusterd/peers/*"
    end
  end

  # Create volumes
  node['gluster']['volumes'].each do |volume|
    next if File.exist?("/var/lib/glusterd/vols/#{volume['name']}/info")
    create_string = ''
    node['address_map']['app_node_ips'].each do |peer|
      create_string += " #{peer}:#{node['gluster']['brick_path']}/#{volume['name']}"
    end
    replica_count = node['address_map']['app_node_ips'].length
    execute "gluster volume create #{volume['name']} replica #{replica_count}#{create_string} --mode=script"
    execute "gluster volume start #{volume['name']}" do
      ignore_failure true
    end
    execute "gluster volume set #{volume['name']} performance.cache-size 256MB"
    execute "gluster volume set #{volume['name']} performance.write-behind-window-size 2MB"
    execute "gluster volume set #{volume['name']} performance.io-thread-count 32"
    execute "gluster volume set #{volume['name']} performance.flush-behind off"
    execute "gluster volume set #{volume['name']} performance.cache-refresh-timeout 4"
  end

  # Mount volumes
  node['gluster']['mounts'].each do |mount|
    if mount['server'].nil?
      mount_server = 'localhost'
    else
      mount_server = mount['server']
    end
    # Mount the partition and add to /etc/fstab
    mount mount['path'] do
      device "#{mount_server}:/#{mount['volume']}"
      fstype 'glusterfs'
      options 'defaults,_netdev'
      pass 0
      action [:mount, :enable]
    end
  end
end
