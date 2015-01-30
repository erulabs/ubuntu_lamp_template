webserver_user = 'www-data'

app_name = 'symfony.com'
user_account app_name
app_secrets = Chef::EncryptedDataBagItem.load('secrets', app_name)

case node.chef_environment
when 'prd'
  branch = 'staging'
when 'stg'
  branch = 'staging'
when 'dev'
  branch = 'staging'
end

package 'libav-tools' do
  action [:upgrade, :install]
end
package 'imagemagick' do
  action [:upgrade, :install]
end
package 'ncftp' do
  action [:upgrade, :install]
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
  repository 'git@github.com:myrepo/custom_app'
  deploy_key app_secrets['deploy_key']
  revision branch
  before_symlink do
    template "#{release_path}/app/config/parameters.yml" do
      mode '0775'
      owner app_name
      group webserver_user
      source "sites/#{app_name}/parameters.yml.erb"
      variables(
        db_name: app_secrets['db']['name'],
        db_user: app_secrets['db']['user'],
        db_password: app_secrets['db']['pass'],
        db_host: db_host
      )
    end
    directory "/var/www/#{app_name}/shared/cache" do
      mode '0770'
      owner app_name
      group webserver_user
    end
    directory "#{release_path}/app/cache" do
      action :delete
    end
    link "#{release_path}/app/cache" do
      to "/var/www/#{app_name}/shared/cache"
    end
    directory "/var/www/#{app_name}/shared/logs" do
      mode '0770'
      owner app_name
      group webserver_user
    end
    directory "#{release_path}/app/logs" do
      action :delete
    end
    link "#{release_path}/app/logs" do
      to "/var/www/#{app_name}/shared/logs"
    end
    execute 'composer install -n' do
      user app_name
      group webserver_user
      cwd release_path
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
