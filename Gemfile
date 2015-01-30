source 'https://rubygems.org'

gem 'berkshelf'
gem 'serverspec'
gem 'rubocop'
gem 'foodcritic'
gem 'foodcritic-rackspace-rules'

# Uncomment these lines if you want to live on the Edge:
#
# group :plugins do
#   gem "vagrant-berkshelf", github: "berkshelf/vagrant-berkshelf"
#   gem "vagrant-omnibus", github: "schisamo/vagrant-omnibus"
# end

group :kitchen_common do
  gem 'test-kitchen'
  gem 'kitchen-rackspace'
  gem 'kitchen-lxc'
end
group :kitchen_vagrant do
  gem 'kitchen-vagrant'
  gem 'vagrant-wrapper'
end
