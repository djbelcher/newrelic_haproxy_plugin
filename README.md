## New Relic Plugin - HAProxy Monitor

This New Relic plugin enables monitoring of HAProxy and reports the following data:

* Request Rate
* Response Rate \[1xx,2xx,3xx,etc\]
* Response Rate \[Non-2xx\]
* Response Time \[Average\]
* Error Rate \[Connection,Request,Response\]
* Throughput \[Bytes In\Out\]
* Servers \[Active/Backup\]
* Sessions \[Active\Queued\]

### Requirements

* A New Relic account and license key.
* A host to install the plugin with the following:  
  * Ruby (tested with 2.2.6), and support for rubygems.

### Instructions for running the HAProxy plugin

1. Install this gem from RubyGems:

    `sudo gem install newrelic_haproxy_plugin`

2. Install/create configuration file `/etc/newrelic/newrelic_haproxy_plugin.yml`.

    `sudo newrelic_haproxy_plugin install`

3. Edit configuration file `/etc/newrelic/newrelic_haproxy_plugin.yml` (created in #2). 
 
    1. Replace `YOUR_LICENSE_KEY_HERE` with your New Relic license key.

    2. Update agent configuration section (See file comments for more information).

4. Execute

    `sudo newrelic_haproxy_plugin run`
  
5. Click the Plugins page link (at the top) on your New Relic dashboard and after a brief period you will see an HAProxy tab that will contain charts for all metrics collected.


## Keep this process running

You can use services like these to manage this process and run it as a daemon.

- [Upstart](http://upstart.ubuntu.com/)
- [Systemd](http://www.freedesktop.org/wiki/Software/systemd/)
- [Runit](http://smarden.org/runit/)
- [Monit](http://mmonit.com/monit/)


## Support

Please use Github issues for support.