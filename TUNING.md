LAMP Tuning guide - WIP
===========================
By Seandon Mooy

This guide will help you optimize your environment for speed. The author enjoys cranking out every last ounce of performance from his services. This guide will help you do just that.

It is broken down into 6 sections: [MariaDB](#mariadb-100-tuning-guide), [Varnish](#varnish-tuning-guide), [Memcache](#memcached-tuning-guide), [Apache](#apache-24-tuning-guide), [PHP](#php-56-tuning-guide) and the [Application](#applicationmisc-tuning-guide) itself

While this guide will target _this cookbook_, it will also contain general information regarding my experience with optimizing a modern LAMP stack on Ubuntu 14.04. The good news? There really isn't much to do. The default settings provided by this guide will make production servers quite happy. It might be a bit intense for a small <1GB server though, so be careful.

The following options and notes are the result of the changes I've made from the default services, and hopefully some idea of why they were changed. There should be no need to change any of these settings, except the innodb_buffer_pool_size which should be decided upon after considering the production dataset. Other "GOTO" settings include Varnish's cache size and PHP-FPM's worker pool settings.

MariaDB 10.0 tuning guide
---------------------
###### templates/default/mysql/my.cnf.erb

#### MySQL secure installation and auditing

  Make sure to log on and run mysql_secure_installation. After designing your cookbook, make sure you audit both the firewall on both MySQL servers and the MySQL users table. Chef will not get everything perfect, and there is no substitute for a proper audit before going to production.

#### Pool of threads

    thread_handling=pool-of-threads

  "Threadpools are most efficient in situations where queries are relatively short and the load is CPU bound (OLTP workloads). If the workload is not CPU bound, you might still want to limit the number of threads to save memory for the database memory buffers." This applies generally to PHP applications - in which we have a large number of concurrent reads and typically all load/backlog is CPU bound. Pool of threads greatly increases performance in these situations. Consider lowering thread_pool_max_threads on VERY busy servers, or disabling entirely on purely batch-task worker databases.

  The thread_pool_size should not be adjusted without great care - increase slightly on dedicated database servers on real metal hardware [Reference](https://mariadb.com/kb/en/mariadb/documentation/optimization-and-tuning/buffers-caches-and-threads/thread-pool/threadpool-in-55/)

#### INNODB buffer pool size

    innodb_buffer_pool_size= {{ Most of your RAM }}

  "InnoDB buffer pool size in bytes. The primary value to adjust on a database server with entirely/primarily XtraDB/InnoDB tables, can be set up to 80% of the total memory in these environments." [Reference](https://mariadb.com/kb/en/mariadb/documentation/storage-engines/xtradb-and-innodb/xtradbinnodb-server-system-variables/) You may be tuned, after reading various guides, to change INNODB buffer pool instances, but in MariaDB 10.0 this is self-tuning. Leave it alone!

#### Save and reload buffer pool cache on MySQL restart

    innodb_buffer_pool_load_at_startup=1
    innodb_buffer_pool_dump_at_shutdown=1

  These two settings are enabled by default in this cookbook, but not in MariaDB 10. This has MySQL flush the INNODB buffer pool to disk before restarting, and loading it back during startup. In practice, it means a slightly longer MySQL restart time (for the OPs user, actual MySQL downtime is unchanged), and a warm buffer pool when making MYSQL tweaks. [Reference](https://mariadb.com/kb/en/mariadb/documentation/storage-engines/xtradb-and-innodb/xtradbinnodb-server-system-variables/#innodb_buffer_pool_dump_at_shutdown) This setting should be TURNED OFF when you're done tuning the database. It's not worthwhile if the DB is never being reset.

#### Log file size tuning

    innodb_log_file_size

  "Size in bytes of each log file in the log group. The combined size can be no more than 4GB. Larger values mean less disk I/O due to less flushing checkpoint activity, but also slower recovery from a crash." - If find this setting is fine by default. If you have a mysterious load spike every 5, 10, 15 min (short regular intervals), look at increasing the size of the log file size. [Reference](https://mariadb.com/kb/en/mariadb/documentation/storage-engines/xtradb-and-innodb/xtradbinnodb-server-system-variables/#innodb_log_file_size)

#### The query cache

  The query cache is an interesting beast. Leave the default settings defined in the example for at least 24 hours and then study the cache hit rate. One can do this manually, but the mysqltuner.pl script also does the calculation for you. If the Query Cache hit rate is lower than 25%, you should disable the query cache entirely. If the number of prunes is very high, MySQL is constantly contending to keep queries in the cache - and you should consider increasing the query_cache_size. If you raise the size to 512MB and you still see a huge number of prunes after about 24 hours, you should stop growing the query_cache_size and look at lowering the query_cache_limit. Watch the NewRelic graphs, make small changes once per 24 hours. [Reference](https://mariadb.com/kb/en/mariadb/documentation/optimization-and-tuning/buffers-caches-and-threads/query-cache/)

#### Monitoring disk usage

  This is very important for new builds - often times the binary logging will exhaust a lot more disk space than one might imagine. Make sure you monitor the disk usage closely for at least 48 hours - making sure the binary log expire time is low enough as to keep a fair amount of disk space free. The default for this guide will keep 3 days of INNODB activity, which is more than enough for most applications.s

Varnish tuning guide
---------------------
#### File open limit
###### recipes/varnish.rb

    ulimit -n

  Ensure the systems file open limit is high enough for Varnish to cope with incoming connections - this cookbook will set the limit to 8192, which is normally _way_ more than required - but make sure to monitor the logs for file open limit errors after about 24 hours of production traffic. It is technically possible that Varnish could be serving 10,000 connections at the same time - YOU NEVER KNOW! Most likely MySQL would have exploded by then.

#### Varnish cache size
###### templates/default/varnish/varnish.erb

    -s malloc,256m

  Varnish's cache size should ideally be as small as possible, but should be large enough to contain the entirety of the applications static resources. If the application is 500MB, a Varnish cache size of 1GB should be enough to contain not only all static assets, but a good number of the dynamic pages as well. The smaller the Varnish cache size, the lower the Time To First Byte - since Varnish will need to scan less memory to determine if a file is in cache or not. Ensure Varnish isn't quickly reaching its cache and fighting for memory - if that is the case, increase the cache and look into the Purge functionality.

#### VCL Purge functionality
###### templates/default/varnish/default.vcl.erb

  To keep the varnish cache small and efficient, ensure your application purges assets from Varnish when they expire. Wordpress and Drupal both have plugins to this effect. The idea is that when a file or page is no longer needed, the application can notify Varnish, thus freeing up memory intelligently, rather than flushing some older (but still useful) document from cache.

#### Caching static files

  The default Varnish configuration this recipe provides will help cache static files - but consider ALSO using a service like CloudFlare.com or a Static Content Cache on a Rackspace Cloud Load Balancer

#### Grace time

  The default Varnish configuration will include a "grace" time, which allows Varnish to serve old content if the backend is replying slowly. This setting causes a very quick user experience, but can mask downtime in a fairly strange way. Make sure you understand what is happening!

Memcached tuning guide
---------------------
###### templates/default/memcached.conf.erb

#### Using Memcached for sessions, or more?

  Assuming the application is a custom PHP application which makes no use of Memcached, keep memcached's memory limit small - as it will be used only for PHP sessions. Otherwise, make sure you monitor it and ensure it's not quickly reaching its cap. 256MB is plenty for most people - but a very heavily trafficked and complex Drupal site with Memcached configured in the application can use up to 1GB.

Apache 2.4 tuning guide
---------------------
###### templates/default/apache2/apache2.conf.erb

#### MPM Event
#### Disabling modules, PHP, SSL
#### Working to disable mod_rewrite
#### htaccess files

PHP 5.6 tuning guide
---------------------
###### templates/default/php/05_opcache.ini.erb
###### templates/default/php/php-fpm.conf.erb
###### templates/default/php/php.ini.erb
###### templates/default/php/pool.conf.erb

#### PHP-FPM via Unix Socket
#### Tuning PHP-FPM's pool
#### Understanding threads


Application/Misc tuning guide
---------------------
#### Using Varnish PURGE
#### Using Memcached
#### Reading from the Slave DB
#### Using Load Balancer caching
#### Logging and fixing bad queries
#### NewRelic for the Application Developer
#### Fixing bad queries - the easy way(s) or the hard way(s)
#### Asset minification and bundling
#### Using a CDN
