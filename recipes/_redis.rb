
# # Default to assuming our server is a 1gb slice
system_total_mem_mb = '1024'
unless node['memory']['total'].nil?
  system_total_mem_mb = (node['memory']['total'].gsub(/kB/, '').to_i / 1024).round
end

node.default['redisio']['default_settings']['maxmemory'] = "#{(system_total_mem_mb / 4).round}M"
node.default['redisio']['default_settings']['maxmemorypolicy'] = 'allkeys-lru'
node.default['redisio']['default_settings']['save'] = nil

node.default['redisio']['default_settings']['address'] = node['address_map']['my_ip']

redis_master_address = node['address_map']['app_node_ips'].first

redis_port = node['address_map']['redis_port'] + 1

if redis_master_address == node['address_map']['my_ip'] || redis_master_address.nil?
  node.default['redisio']['servers'] = [
    {
      name: 'pool0',
      port: redis_port
    }
  ]
else
  node.default['redisio']['servers'] = [
    {
      name: 'pool0',
      port: redis_port,
      slaveof: {
        address: redis_master_address,
        port: redis_port
      }
    }
  ]
end

unless redis_master_address.nil?
  node.default['redisio']['sentinels'] = [{
    name: 'pool0',
    sentinel_port: 26_379,
    master_ip: redis_master_address,
    master_port: redis_port
  }]
end

if node.default['address_map']['app_node_ips'].length > 0
  if tagged?('redis_sentinel')
    node.default['redisio']['sentinel']['manage_config'] = false
  end
  tag('redis_sentinel')
  tag('redis')
end

include_recipe 'redisio'
include_recipe 'redisio::enable'
include_recipe 'redisio::sentinel'
include_recipe 'redisio::sentinel_enable'
