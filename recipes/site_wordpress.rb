webserver_user = 'www-data'

app_name = 'wordpress.com'
user_account app_name
app_secrets = Chef::EncryptedDataBagItem.load('secrets', app_name)

case node.chef_environment
when 'prd'
  branch = 'production'
when 'stg'
  branch = 'stage'
when 'dev'
  branch = 'master'
end

if tagged?('mysql_master')
  db_host = node['address_map']['my_ip']
else
  db_host = node['address_map']['mysql_masters'].first
end

# Deploy the application - see https://docs.getchef.com/resource_deploy.html
application app_name do
  path "/var/www/#{app_name}"
  owner app_name
  group webserver_user
  repository 'git@github.com:mywordpress/wordpress'
  deploy_key app_secrets['deploy_key']
  revision branch
  before_symlink do
    template "#{release_path}/wp-config.php" do
      mode '0775'
      owner webserver_user
      group webserver_user
      source "sites/#{app_name}/wp-config.php.erb"
      variables(
        db_name: app_secrets['db']['name'],
        db_user: app_secrets['db']['user'],
        db_password: app_secrets['db']['pass'],
        db_host: db_host
      )
    end
    directory "/var/www/#{app_name}/shared/wp-content/uploads" do
      mode '0770'
      owner app_name
      group webserver_user
    end
    link "#{release_path}/wp-content/uploads" do
      to "/var/www/#{app_name}/shared/wp-content/uploads"
    end
    directory "/var/www/#{app_name}/shared/wp-content/cache" do
      mode '0777'
      owner app_name
      group webserver_user
    end
    link "#{release_path}/wp-content/cache" do
      to "/var/www/#{app_name}/shared/wp-content/cache"
    end
    directory "/var/www/#{app_name}/shared/wp-content/w3tc-config" do
      mode '0770'
      owner app_name
      group webserver_user
    end
    link "#{release_path}/wp-content/w3tc-config" do
      to "/var/www/#{app_name}/shared/wp-content/w3tc-config"
    end
    file "#{release_path}/wp-content/advanced-cache.php" do
      owner app_name
      group webserver_user
      mode 0755
      content ::File.open("#{release_path}/wp-content/plugins/w3-total-cache/wp-content/advanced-cache.php").read
      action :create
    end
  end
  after_restart do
    # Because we'll be setting OPCache's revalidate time to never, we'll HAVE to reload PHP-FPM on deployments
    # Otherwise no php files will be reloaded from disk.
    execute 'service php5-fpm reload'
    # We'll also clear Varnishs cache by banning on objects for this site
    execute "clear_varnish_for_#{app_name}" do
      command "varnishadm 'ban req.http.host ~ #{app_name}'"
      ignore_failure true
    end
    # execute "curl -s --user 'api:#{node.default['mailgun_api_key']}' \
    # https://api.mailgun.net/v2/seandonmooy.com/messages \
    # -F from='Chef <chef-client@#{node['address_map']['my_ip']}>' \
    # -F to='seandon.mooy@gmail.com' \
    # -F subject='Chef-client: Deployed #{app_name} to #{node.chef_environment} on #{node.name}' \
    # -F text='This mail was sent by #{node.name} at #{node['address_map']['my_ip']}'"
  end
end
# Configure Apache
template "/etc/apache2/sites-enabled/#{app_name}.conf" do
  source "sites/#{app_name}/#{app_name}.conf.erb"
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    appname: app_name
  )
  notifies :reload, 'service[apache2]'
end

# Configure Nginx (testing)
# template "/etc/nginx/sites-enabled/#{app_name}.conf" do
#   source "sites/#{app_name}/#{app_name}-nginx.erb"
#   owner 'root'
#   group 'root'
#   mode '0644'
#   variables(
#     appname: app_name
#   )
#   notifies :reload, 'service[nginx]'
# end

logrotate_app "#{app_name}-access" do
  path '/var/log/apache2/#{app_name}-access.log'
  rotate 1000
  frequency 'daily'
  options %w(missingok compress dateext copytruncate)
end
