# Default Recipe
include_recipe "#{cookbook_name}::default"

# Configure Galera cluster
include_recipe "#{cookbook_name}::_mysql"

# Configure databases
include_recipe "#{cookbook_name}::databases"
