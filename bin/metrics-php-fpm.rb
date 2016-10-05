#!/usr/bin/env ruby
#
# Pull php-fpm metrics from php-fpm status page
# ===
#
# Copyright 2014 Ilari Makela ilari at i28.fi
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/metric/cli'
require 'net/https'
require 'uri'

class PhpfpmMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :url,
         short: '-u URL',
         long: '--url URL',
         description: 'Full URL to php-fpm status page, example: http://yoursite.com/php-fpm-status',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.php_fpm"

  option :agent,
         description: 'User Agent to make the request with',
         short: '-a USERAGENT',
         long: '--agent USERAGENT',
         default: 'Sensu-Agent'

  def run
    found = false
    attempts = 0
    # #YELLOW
    until found || attempts >= 10
      attempts += 1
      url = config[:url]
      if url
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request = Net::HTTP::Get.new(uri.request_uri, 'User-Agent' => config[:agent].to_s)
        response = http.request(request)
        if response.code == '200'
          found = true
        elsif !response.header['location'].nil?
          url = response.header['location']
        end
      end
    end # until

    critical "Unable to load url #{config[:url]}" if response.nil? || response.code != '200'

    stat = %w(start_since
              accepted_conn
              listen_queue
              max_listen_queue
              listen_queue_len
              idle_processes
              active_processes
              total_processes
              max_active_processes
              max_children_reached
              slow_requests)
    response.body.each_line do |line|
      k, v = line.split(':').map(&:strip)
      k.tr! ' ', '_'
      output "#{config[:scheme]}.#{k}", v if stat.include? k
    end
    ok
  end
end
