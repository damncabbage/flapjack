require 'time'
require 'sinatra/base'
require 'rack/fiber_pool'
require 'rack/json_params_parser'
require 'flapjack/rack_logger'
require 'flapjack/redis_pool'

module Flapjack
  module Gateways
    class PagerdutyWebhooks < Sinatra::Base
      include Flapjack::Utility

      set :dump_errors, false

      rescue_error = Proc.new {|status, exception, *msg|
        if !msg || msg.empty?
          trace = exception.backtrace.join("\n")
          msg = "#{exception.class} - #{exception.message}"
          msg_str = "#{msg}\n#{trace}"
        else
          msg_str = msg.join(", ")
        end
        case
        when status < 500
          @logger.warn "Error: #{msg_str}"
        else
          @logger.error "Error: #{msg_str}"
        end
        [status, {}, {:errors => msg}.to_json]
      }

      use Rack::FiberPool, :size => 25, :rescue_exception => (Proc.new {|env, e|
        rescue_error.call(500, e)
#        case e
#        when Flapjack::Gateways::API::ContactNotFound
#          rescue_error.call(403, e, "could not find contact '#{e.contact_id}'")
#        else
#          rescue_error.call(500, e)
#        end
      })
      use Rack::MethodOverride
      use Rack::JsonParamsParser

      class << self
        def start
          @redis = Flapjack::RedisPool.new(:config => @redis_config, :size => 2)
          @logger.info "starting pagerduty_webhooks - class"
          if @config && @config['access_log']
            access_logger = Flapjack::AsyncLogger.new(@config['access_log'])
            use Flapjack::CommonLogger, access_logger
          end
          @shared_key = (@config && @config['shared_key']) or @logger.error("Missing shared_key!")
        end
      end

      def redis
        self.class.instance_variable_get('@redis')
      end

      def logger
        self.class.instance_variable_get('@logger')
      end

      def shared_key
        self.class.instance_variable_get('@shared_key')
      end

      before do
        input = nil
        if logger.debug?
          input = env['rack.input'].read
          logger.debug("#{request.request_method} #{request.path_info}#{request.query_string} #{input}")
        elsif logger.info?
          input = env['rack.input'].read
          input_short = input.gsub(/\n/, '').gsub(/\s+/, ' ')
          logger.info("#{request.request_method} #{request.path_info}#{request.query_string} #{input_short[0..80]}")
        end
        env['rack.input'].rewind unless input.nil?
      end

      after do
        logger.debug("Returning #{response.status} for #{request.request_method} #{request.path_info}#{request.query_string}")
      end

      post '/pagerduty/callback' do
        provided_key = params[:key]
        halt err(401, "Unauthorized") if provided_key.blank?
        halt err(403, "Forbidden") unless provided_key == shared_key
        
        halt err(500, "It Broke")
      end

      not_found do
        err(404, "not routable")
      end

      private

      def err(status, *msg)
        msg_str = msg.join(", ")
        logger.info "Error: #{msg_str}"
        [status, {}, {:errors => msg}.to_json]
      end
    end

  end

end
