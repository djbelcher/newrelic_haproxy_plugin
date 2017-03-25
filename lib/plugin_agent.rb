require 'csv'
require 'open-uri'
require 'rubygems'
require 'bundler/setup'
require 'newrelic_plugin'

require_relative 'delta_counter.rb'

# noinspection RubyUnnecessaryReturnStatement
module PluginAgent
    VERSION = '1.0.0'

    class Agent < NewRelic::Plugin::Agent::Base

        agent_guid 'com.godaddy.haproxy'
        agent_version PluginAgent::VERSION
        agent_config_options :uri, :name, :proxy, :proxy_type, :user, :password
        agent_human_labels('Haproxy') { '' }

        def instance_label
            return name
        end

        def poll_cycle
            stat_values = parse_stats(load_stats)
            report_stats(stat_values)
        end

        def setup_metrics
            raise("Invalid agent configuration. 'uri' is required.") if uri.nil?
            raise("Invalid agent configuration. 'name' is required.") if name.nil?
            raise("Invalid agent configuration. 'proxy' is required.") if proxy.nil?

            @uri_list = uri.split(',').each { |x| x.strip! }

            # Setup delta counters for those stat values
            # that are incrementally updated.
            @uri_hash = {}
            @uri_list.each do |x|
                @uri_hash[x] = {}
                @uri_hash[x]['stot'] = DeltaCounter.new
                @uri_hash[x]['hrsp_1xx'] = DeltaCounter.new
                @uri_hash[x]['hrsp_2xx'] = DeltaCounter.new
                @uri_hash[x]['hrsp_3xx'] = DeltaCounter.new
                @uri_hash[x]['hrsp_4xx'] = DeltaCounter.new
                @uri_hash[x]['hrsp_5xx'] = DeltaCounter.new
                @uri_hash[x]['hrsp_other'] = DeltaCounter.new
                @uri_hash[x]['ereq'] = DeltaCounter.new
                @uri_hash[x]['eresp'] = DeltaCounter.new
                @uri_hash[x]['econ'] = DeltaCounter.new
                @uri_hash[x]['bin'] = DeltaCounter.new
                @uri_hash[x]['bout'] = DeltaCounter.new
            end
        end

        private def load_stats
            uri_blocks = {}
            @uri_list.each do |uri|
                begin
                    uri_blocks[uri] = open(uri, :http_basic_authentication => [user, password])
                rescue
                    NewRelic::PlatformLogger.error("Unhandled exception reading stats page at #{uri}. The exception: #{$!.message}\n#{$!.backtrace}")
                end
            end

            return uri_blocks
        end

        private def parse_stats(uri_blocks)
            stat_values = {}
            uri_blocks.each do |uri, block|
                CSV.parse(block, :headers => true) do |row|
                    next unless proxy.to_s.strip.downcase == row['# pxname'].downcase

                    if proxy_type =~ /frontend|backend/i
                        next if proxy_type.upcase != row['svname']
                    end if proxy_type

                    NewRelic::PlatformLogger.info("Collecting data from #{uri}")

                    # Requests
                    # --------------------------------------------------------------------------------
                    stat_values['stot'] = 0 unless stat_values['stot']
                    stat_values['stot'] += (@uri_hash[uri]['stot'].process(row['stot'].to_i) || 0)

                    # Responses
                    # --------------------------------------------------------------------------------
                    stat_values['hrsp_1xx'] = 0 unless stat_values['hrsp_1xx']
                    stat_values['hrsp_1xx'] += (@uri_hash[uri]['hrsp_1xx'].process(row['hrsp_1xx'].to_i) || 0)

                    stat_values['hrsp_2xx'] = 0 unless stat_values['hrsp_2xx']
                    stat_values['hrsp_2xx'] += (@uri_hash[uri]['hrsp_2xx'].process(row['hrsp_2xx'].to_i) || 0)

                    stat_values['hrsp_3xx'] = 0 unless stat_values['hrsp_3xx']
                    stat_values['hrsp_3xx'] += (@uri_hash[uri]['hrsp_3xx'].process(row['hrsp_3xx'].to_i) || 0)

                    stat_values['hrsp_4xx'] = 0 unless stat_values['hrsp_4xx']
                    stat_values['hrsp_4xx'] += (@uri_hash[uri]['hrsp_4xx'].process(row['hrsp_4xx'].to_i) || 0)

                    stat_values['hrsp_5xx'] = 0 unless stat_values['hrsp_5xx']
                    stat_values['hrsp_5xx'] += (@uri_hash[uri]['hrsp_5xx'].process(row['hrsp_5xx'].to_i) || 0)

                    stat_values['hrsp_other'] = 0 unless stat_values['hrsp_other']
                    stat_values['hrsp_other'] += (@uri_hash[uri]['hrsp_other'].process(row['hrsp_other'].to_i) || 0)

                    stat_values['ctime'] = 0 unless stat_values['ctime']
                    stat_values['ctime'] += (row['ctime'].to_i || 0)

                    stat_values['qtime'] = 0 unless stat_values['qtime']
                    stat_values['qtime'] += (row['qtime'].to_i || 0)

                    stat_values['rtime'] = 0 unless stat_values['rtime']
                    stat_values['rtime'] += (row['rtime'].to_i || 0)

                    stat_values['ttime'] = 0 unless stat_values['ttime']
                    stat_values['ttime'] += (row['ttime'].to_i || 0)

                    # Errors
                    # --------------------------------------------------------------------------------
                    stat_values['ereq'] = 0 unless stat_values['ereq']
                    stat_values['ereq'] += (@uri_hash[uri]['ereq'].process(row['ereq'].to_i) || 0)

                    stat_values['eresp'] = 0 unless stat_values['eresp']
                    stat_values['eresp'] += (@uri_hash[uri]['eresp'].process(row['eresp'].to_i) || 0)

                    stat_values['econ'] = 0 unless stat_values['econ']
                    stat_values['econ'] += (@uri_hash[uri]['econ'].process(row['econ'].to_i) || 0)

                    # Throughput
                    # --------------------------------------------------------------------------------
                    stat_values['bin'] = 0 unless stat_values['bin']
                    stat_values['bin'] += (@uri_hash[uri]['bin'].process(row['bin'].to_i) || 0)

                    stat_values['bout'] = 0 unless stat_values['bout']
                    stat_values['bout'] += (@uri_hash[uri]['bout'].process(row['bout'].to_i) || 0)

                    # Sessions
                    # --------------------------------------------------------------------------------
                    stat_values['scur'] = 0 unless stat_values['scur']
                    stat_values['scur'] += (row['scur'].to_i || 0)

                    stat_values['qcur'] = 0 unless stat_values['qcur']
                    stat_values['qcur'] += (row['qcur'].to_i || 0)

                    # Servers
                    # --------------------------------------------------------------------------------
                    stat_values['act'] = 0 unless stat_values['act']
                    stat_values['act'] += (row['act'].to_i || 0)

                    stat_values['bck'] = 0 unless stat_values['bck']
                    stat_values['bck'] += (row['bck'].to_i || 0)

                    # Status
                    # --------------------------------------------------------------------------------
                    stat_values['status'] = 0 unless stat_values['status']
                    stat_values['status'] += (%w(UP OPEN).find { |s| s == row['status'] } ? 1 : 0)
                end
            end

            return stat_values
        end

        def report_stats(stat_values)
            # Requests
            # --------------------------------------------------------------------------------
            metric_value = stat_values['stot']
            report_metric 'Requests', 'requests', metric_value
            NewRelic::PlatformLogger.info("Requests[requests] = #{metric_value}")

            # Responses
            # --------------------------------------------------------------------------------
            response_failures = 0

            metric_value = stat_values['hrsp_1xx']
            report_metric 'Response/Codes/1xx', 'responses', metric_value
            NewRelic::PlatformLogger.info("Response/Codes/1xx[responses] = #{metric_value}")

            metric_value = stat_values['hrsp_2xx']
            report_metric 'Response/Codes/2xx', 'responses', metric_value
            NewRelic::PlatformLogger.info("Response/Codes/2xx[responses] = #{metric_value}")

            response_failures += metric_value = stat_values['hrsp_3xx']
            report_metric 'Response/Codes/3xx', 'responses', metric_value
            NewRelic::PlatformLogger.info("Response/Codes/3xx[responses] = #{metric_value}")

            response_failures += metric_value = stat_values['hrsp_4xx']
            report_metric 'Response/Codes/4xx', 'responses', metric_value
            NewRelic::PlatformLogger.info("Response/Codes/4xx[responses] = #{metric_value}")

            response_failures += metric_value = stat_values['hrsp_5xx']
            report_metric 'Response/Codes/5xx', 'responses', metric_value
            NewRelic::PlatformLogger.info("Response/Codes/5xx[responses] = #{metric_value}")

            response_failures += metric_value = stat_values['hrsp_other']
            report_metric 'Response/Codes/Other', 'responses', metric_value
            NewRelic::PlatformLogger.info("Response/Codes/Other[responses] = #{metric_value}")

            report_metric 'Response/Failures', 'responses', response_failures
            NewRelic::PlatformLogger.info("Response/Failures[responses] = #{response_failures}")

            # Do not report if data doesn't exist; it will skew average response times.
            metric_value = stat_values['ctime'] / @uri_list.length
            report_metric 'Response/Time/Connect', 'milliseconds', metric_value if (metric_value > 0)
            NewRelic::PlatformLogger.info("Response/Time/Connect[milliseconds] = #{metric_value}")

            metric_value = stat_values['qtime'] / @uri_list.length
            report_metric 'Response/Time/Queue', 'milliseconds', metric_value if (metric_value > 0)
            NewRelic::PlatformLogger.info("Response/Time/Queue[milliseconds] = #{metric_value}")

            metric_value = stat_values['rtime'] / @uri_list.length
            report_metric 'Response/Time/Response', 'milliseconds', metric_value if (metric_value > 0)
            NewRelic::PlatformLogger.info("Response/Time/Backend[milliseconds] = #{metric_value}")

            metric_value = stat_values['ttime'] / @uri_list.length
            report_metric 'Response/Time/Total', 'milliseconds', metric_value if (metric_value > 0)
            NewRelic::PlatformLogger.info("Response/Time/Total[milliseconds] = #{metric_value}")

            # Errors
            # --------------------------------------------------------------------------------
            metric_value = stat_values['ereq']
            report_metric 'Errors/Request', 'errors', metric_value
            NewRelic::PlatformLogger.info("Errors/Request[errors] = #{metric_value}")

            metric_value = stat_values['eresp']
            report_metric 'Errors/Response', 'errors', metric_value
            NewRelic::PlatformLogger.info("Errors/Response[errors] = #{metric_value}")

            metric_value = stat_values['econ']
            report_metric 'Errors/Connection', 'errors', metric_value
            NewRelic::PlatformLogger.info("Errors/Connection[errors] = #{metric_value}")

            # Throughput
            # --------------------------------------------------------------------------------
            metric_value = stat_values['bin']
            report_metric 'Bytes/Received', 'bytes', metric_value
            NewRelic::PlatformLogger.info("Bytes/Received[bytes] = #{metric_value}")

            metric_value = stat_values['bout']
            report_metric 'Bytes/Sent', 'bytes', metric_value
            NewRelic::PlatformLogger.info("Bytes/Sent[bytes] = #{metric_value}")

            # Sessions
            # --------------------------------------------------------------------------------
            metric_value = stat_values['scur']
            report_metric 'Sessions/Active', 'sessions', metric_value
            NewRelic::PlatformLogger.info("Sessions/Active[sessions] = #{metric_value}")

            metric_value = stat_values['qcur']
            report_metric 'Sessions/Queued', 'sessions', metric_value
            NewRelic::PlatformLogger.info("Sessions/Queued[sessions] = #{metric_value}")

            # Servers
            # --------------------------------------------------------------------------------
            metric_value = stat_values['act'] / @uri_list.length
            report_metric 'Servers/Active', 'servers', metric_value
            NewRelic::PlatformLogger.info("Servers/Active[servers] = #{metric_value}")

            metric_value = stat_values['bck'] / @uri_list.length
            report_metric 'Servers/Backup', 'servers', metric_value
            NewRelic::PlatformLogger.info("Servers/Backup[servers] = #{metric_value}")

            # Status
            # --------------------------------------------------------------------------------
            metric_value = stat_values['status'] / @uri_list.length
            report_metric 'ProxyUp', 'status', metric_value
            NewRelic::PlatformLogger.info("ProxyUp[status] = #{metric_value}")
        end
    end

    def self.run
        NewRelic::Plugin::Config.config.agents.keys.each do |agent|
            NewRelic::Plugin::Setup.install_agent agent, PluginAgent
        end

        #
        # Launch the agent (never returns)
        #
        NewRelic::Plugin::Run.setup_and_run
    end
end
