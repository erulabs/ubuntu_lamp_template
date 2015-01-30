mysql_listen_address = '0.0.0.0'
if !node['rackspace'].nil? && !node['rackspace']['private_ip'].nil? && !Chef::Config[:solo]
  mysql_listen_address = node['rackspace']['private_ip']
end

# Musiccom
app1 = 'wordpress.com'
app1_secrets = Chef::EncryptedDataBagItem.load('secrets', app1)
template "/root/#{app1}.sql" do
  source "sites/#{app1}/#{app1}.sql.erb"
  owner 'root'
  group 'root'
  mode '0600'
  variables(
    db_user: app1_secrets['db']['user'],
    db_pass: app1_secrets['db']['pass'],
    db_name: app1_secrets['db']['name'],
    local_mysql: mysql_listen_address
  )
  notifies :run, 'execute[SQL_constants_for_wordpress]', :delayed
end
execute 'SQL_constants_for_wordpress' do
  command "mysql -uroot -p'#{node['mysql']['server_root_password']}' < /root/#{app1}.sql"
  ignore_failure true
end

# Songflow
app2 = 'symfony.com'
app2_secrets = Chef::EncryptedDataBagItem.load('secrets', app2)
template "/root/#{app2}.sql" do
  source "sites/#{app2}/#{app2}.sql.erb"
  owner 'root'
  group 'root'
  mode '0600'
  variables(
    db_user: app2_secrets['db']['user'],
    db_pass: app2_secrets['db']['pass'],
    db_name: app2_secrets['db']['name'],
    local_mysql: mysql_listen_address
  )
  notifies :run, 'execute[SQL_constants_for_symfony]', :delayed
end
execute 'SQL_constants_for_symfony' do
  command "mysql -uroot -p'#{node['mysql']['server_root_password']}' < /root/#{app2}.sql"
  ignore_failure true
end

# Songflow
app3 = 'drupal.com'
app3_secrets = Chef::EncryptedDataBagItem.load('secrets', app3)
template "/root/#{app3}.sql" do
  source "sites/#{app3}/#{app3}.sql.erb"
  owner 'root'
  group 'root'
  mode '0600'
  variables(
    db_user: app3_secrets['db']['user'],
    db_pass: app3_secrets['db']['pass'],
    db_name: app3_secrets['db']['name'],
    local_mysql: mysql_listen_address
  )
  notifies :run, 'execute[SQL_constants_for_drupal]', :delayed
end
execute 'SQL_constants_for_drupal' do
  command "mysql -uroot -p'#{node['mysql']['server_root_password']}' < /root/#{app3}.sql"
  ignore_failure true
end
