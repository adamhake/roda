# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The heartbeat handles heartbeat/status requests.  If a request for
    # the heartbeat path comes in, a 200 response with a
    # text/plain Content-Type and a body of "OK" will be returned.
    # The default heartbeat path is "/heartbeat", so to use that:
    #
    #   plugin :heartbeat
    #
    # You can also specify a custom heartbeat path:
    #
    #   plugin :heartbeat, path: '/status'
    module Heartbeat
      HEADER_CLASS = (defined?(Rack::Headers) && Rack::Headers.is_a?(Class)) ? Rack::Headers : Hash
      HEARTBEAT_RESPONSE = [200, {'Content-Type'=>'text/plain'}.freeze, ['OK'.freeze].freeze].freeze

      # Set the heartbeat path to the given path.
      def self.configure(app, opts=OPTS)
        app.opts[:heartbeat_path] = (opts[:path] || app.opts[:heartbeat_path] || "/heartbeat").dup.freeze
      end

      module InstanceMethods
        private

        # If the request is for a heartbeat path, return the heartbeat response.
        def _roda_before_20__heartbeat
          if env['PATH_INFO'] == opts[:heartbeat_path]
            response = HEARTBEAT_RESPONSE.dup
            response[1] = HEADER_CLASS[response[1]]
            throw :halt, response
          end
        end
      end
    end

    register_plugin(:heartbeat, Heartbeat)
  end
end

