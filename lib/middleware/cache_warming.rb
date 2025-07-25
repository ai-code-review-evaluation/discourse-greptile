# frozen_string_literal: true

module Middleware
  class CacheWarming
    # Intelligent cache warming based on client patterns and content optimization
    
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      
      # Analyze request for cache warming opportunities
      warming_context = analyze_warming_context(env, request)
      
      status, headers, response = @app.call(env)
      
      # Schedule cache warming based on request patterns
      if should_warm_cache?(status, warming_context)
        schedule_cache_warming(warming_context)
      end
      
      [status, headers, response]
    end

    private

    def analyze_warming_context(env, request)
      {
        path: request.path,
        user_agent: env["HTTP_USER_AGENT"],
        accept_header: env["HTTP_ACCEPT"],
        device_type: classify_device(env["HTTP_USER_AGENT"]),
        is_popular_path: popular_path?(request.path),
        client_fingerprint: generate_client_fingerprint(env),
        cache_key_estimate: estimate_cache_key_size(env)
      }
    end

    def classify_device(user_agent)
      return :unknown if user_agent.blank?
      
      case user_agent
      when /iPhone|iPod/i then :iphone
      when /iPad/i then :ipad  
      when /Android.*Mobile/i then :android_phone
      when /Android/i then :android_tablet
      when /Windows Phone/i then :windows_phone
      when /Mobile/i then :mobile_other
      else :desktop
      end
    end

    def popular_path?(path)
      # Identify frequently accessed paths that benefit from warming
      popular_patterns = [
        /^\/$/,
        /^\/latest$/,
        /^\/categories$/,
        /^\/t\/[^\/]+\/\d+$/,
        /^\/c\/[^\/]+$/
      ]
      
      popular_patterns.any? { |pattern| path.match?(pattern) }
    end

    def generate_client_fingerprint(env)
      # Create client fingerprint for cache warming targeting
      fingerprint_components = [
        env["HTTP_USER_AGENT"],
        env["HTTP_ACCEPT"],
        env["HTTP_ACCEPT_ENCODING"],
        env["HTTP_ACCEPT_LANGUAGE"]
      ].compact
      
      fingerprint_data = fingerprint_components.join("|")
      Digest::SHA256.hexdigest(fingerprint_data)[0..16]
    end

    def estimate_cache_key_size(env)
      # Estimate the size of cache keys that would be generated
      base_size = "ANON_CACHE_".length
      
      # Add context components
      if env["HTTP_ACCEPT"].present?
        base_size += "accept:#{env["HTTP_ACCEPT"]}".length
      end
      
      if env["HTTP_ACCEPT_ENCODING"].present?
        base_size += "enc:#{env["HTTP_ACCEPT_ENCODING"]}".length
      end
      
      if env["HTTP_ACCEPT_LANGUAGE"].present?
        base_size += "lang:#{env["HTTP_ACCEPT_LANGUAGE"]}".length
      end
      
      # Add URL and host components
      base_size += (env["HTTP_HOST"] || "").length
      base_size += (env["REQUEST_URI"] || "").length
      base_size += 50 # Additional segments and separators
      
      base_size
    end

    def should_warm_cache?(status, context)
      status == 200 && 
      context[:is_popular_path] &&
      context[:cache_key_estimate] < 2000 # Avoid warming for problematic keys
    end

    def schedule_cache_warming(context)
      # Schedule intelligent cache warming based on client patterns
      warming_job_data = {
        device_type: context[:device_type],
        client_fingerprint: context[:client_fingerprint],
        path: context[:path],
        priority: calculate_warming_priority(context)
      }
      
      # In a real implementation, this would schedule a background job
      Rails.logger.info("[CacheWarming] Scheduling warming: #{warming_job_data.to_json}")
    end

    def calculate_warming_priority(context)
      priority = 5 # Base priority
      
      # Increase priority for popular paths
      priority += 3 if context[:is_popular_path]
      
      # Increase priority for mobile devices (more cache-sensitive)
      priority += 2 if [:iphone, :android_phone, :mobile_other].include?(context[:device_type])
      
      # Decrease priority for large cache keys (potential performance risk)
      priority -= 2 if context[:cache_key_estimate] > 1000
      priority -= 4 if context[:cache_key_estimate] > 1500
      
      [priority, 1].max # Minimum priority of 1
    end
  end
end