
node.default['gluster']['volumes'] = [
  { name: 'shared_files' }
]

node.default['gluster']['mounts'] = [
  {
    path: '/var/www/wordpress/shared/wp-content/',
    volume: 'shared_files'
  }
]
