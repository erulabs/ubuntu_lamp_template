Ubuntu Lamp Template
===================

Intro
----------
  This cookbook installs and configures everything required to run Drupal, Wordpress, Joomla, or any other PHP application.

  Core Stack:

  - Ubuntu 14.04 LTS - This is the _only_ supported platform
  - PHP5.6 via ppa:ondrej/php5-5.6
  - Apache 2.4 via ppa:ondrej/apache2
  - A very simple Nginx recipe if you'd like LNMP instead
  - MariaDB Galera 10 via http://ftp.osuosl.org/pub/mariadb/repo/10.0/ubuntu in a Galera Cluster
  - Varnish 4.0 from http://repo.varnish-cache.org
  - HAProxy 1.5 from ppa:vbernat/haproxy-1.5
  - Redis 2.8 via the redisio cookbook

  Sites and databases are configured in ```recipes/site_NAME.rb``` and ```recipes/databases.rb``` respectively. ```recipes/filesystems.rb``` sets up gluster mounts.

  Most common tweaks and changes will take place directly in the template. For instance, ```templates/default/apache2/apache2.conf.erb``` and ```templates/default/php/php.ini.erb``` are exactly what you'd expect.

  Some templates are heavily customized. See ```templates/default/mysql/my.cnf.erb``` - Many settings are dynamically set based on systems available memory. Please read and understand ```recipes/_mysql.rb``` before making big changes to that template.

  It's also important to note that this cookbook REQUIRES a cloud network. It will not only assume to look for an 'eth2' (check default.rb) on initial bootstrap, but it opens the firewall COMPLETELY for that interface. See the bootstrap example for how to bootstrap a server with a cloud network attached. The cloud network is assumed to be named the same as the chef environment. You can use servicenet if you want, but this cookbook will not deal with the complexity of firewalling on a shared network. It will whitelist other nodes in the environment, but bootstrapping Galera and Gluster will not work unless you manually whitelist a new servers IP before bootstrapping it. Using a Cloud Network (or any private network) is by far preferred.

Philosopy
----------
  Unlike others, who settle for PHP applications being riddled with single points of failure, this cookbook aims to provide highly available solutions to _all_ common PHP problems, include: memory/session store (HA redis), disk (gluster), database (mysql master-master Galera replication).

  While this mission is far from complete (and obviously ambitious), we're most of the way there.

Bootstrapping new nodes
----------
### Using knife rackspace:
    knife rackspace server create -N"dev-1" -r"role[app]" -E"dev" -I"598a4282-f14b-4e50-af4c-b3e52749d9f9" -f"performance1-4" --no-tcp-test-ssh --ssh-wait-timeout 60 -S"dev-1" --secret-file path/to/secret --bootstrap-version 11.16.4 --network "dev" --rackspace-version v2

### Bootstrap
    knife bootstrap IP_ADDR -N"dev-2" -r"role[app]" -E"dev" --secret-file path/to/secret --bootstrap-version 11.16.4 --network "dev" --rackspace-version v2

Bootstrapping a new environment
----------
Take a peek at "dev" and make note of the set MySQL password and chef version. Use this on any new environment.

### The database
You'll also want to run mysql_secure_installation on MySQL masters as well. Automation is no replacement for a properly setup MySQL master! Assuming you're making use of Galera, DB syncing happens automagically!

### Redis
Each application node (role_app) will have its own redis instance, but a single small shared redis instance must exist for PHP sessions to be shared properly.

Mark one server with a "redis_master" role or checkout the default recipe to override the address_map attribute.

### The static assets
You can use the cloudsink utility: https://github.com/erulabs/cloudsink

An example of syncing all the static files in Drupal (should be carefully studied) from an existing file server to Cloud Files.

Note that performance is _far_ greater when uploading to a NON CDN container than to a CDN container. You can enable CDN after the fact - so if doing an initial build, ALWAYS use a private container for the initial upload (and enable CDN after the fact).

```
    cloudsink -S -t CONTAINER -u USERNAME -k API_KEY -r IAD -F -s sites -f "*.js"
    cloudsink -S -t CONTAINER -u USERNAME -k API_KEY -r IAD -F -s sites -f "*.css"
    cloudsink -S -t CONTAINER -u USERNAME -k API_KEY -r IAD -F -s modules -f "*.js"
    cloudsink -S -t CONTAINER -u USERNAME -k API_KEY -r IAD -F -s modules -f "*.css"
    cloudsink -S -t CONTAINER -u USERNAME -k API_KEY -r IAD -F -s sites/default/files
```

Wordpress
----------
Am example recipe at "site_wordpress.rb" has been provided which deploys a fake wordpress application. The wp-config template is included, with some hints, although you'll almost certainly not want to use this example one (most likely a real wordpress app will have it's own wp-config).

As with all other PHP applications, the real key to performance is to use Redis above all other resources. Every query shipped to Redis instead of to MySQL is a huge win. Even compaired to Memcached.

I strongly recommend using the Redis object cache available here: https://github.com/alleyinteractive/wp-redis

You can use a redis full page cache (as opposed to heavily using Varnish) if you'd like, but I have not vetted this plugin as thourghly as the object cache plugin: https://github.com/BenjaminAdams/wp-redis-cache

Other things to note about wordpress is that you should closely monitor the number of plugins which hammer the database - in particular applications which log to the database. Disable as many as humanly possible.

After this, install W3 Total Cache so that you can use a CDN for your assets. CloudSink (see above) can be used to ship initial loads of files to Cloud Files.

Drupal
----------
Again, simply Redis as many things as humanly possible. The core redis module works fairly well: https://www.drupal.org/project/redis

For CDN, The Rackspace Cloud Files plugin is good, but needs a ton of patches. I've done the lions share of this work here: https://github.com/erulabs/drupal7_cloud_files - but you should check the "issues" list here from time to time: https://www.drupal.org/project/cloud_files
