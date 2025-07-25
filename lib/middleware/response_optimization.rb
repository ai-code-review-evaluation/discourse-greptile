# frozen_string_literal: true

module Middleware
  class ResponseOptimization
    # Advanced response optimization middleware for improved performance
    
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      
      # Enhanced response optimization based on client capabilities
      optimization_context = build_optimization_context(env, request)
      
      status, headers, response = @app.call(env)
      
      if should_optimize_response?(status, headers, optimization_context)
        response = optimize_response_body(response, optimization_context)
        headers = optimize_response_headers(headers, optimization_context)
      end
      
      [status, headers, response]
    end

    private

    def build_optimization_context(env, request)
      {
        user_agent: env["HTTP_USER_AGENT"],
        accept_header: env["HTTP_ACCEPT"],
        accept_encoding: env["HTTP_ACCEPT_ENCODING"],
        device_type: detect_device_type(env["HTTP_USER_AGENT"]),
        browser_capabilities: analyze_browser_capabilities(env),
        content_preferences: parse_content_preferences(env["HTTP_ACCEPT"]),
        compression_support: env["HTTP_ACCEPT_ENCODING"]&.include?("gzip"),
        is_mobile: request.get_header("HTTP_USER_AGENT")&.match?(/Mobile/i),
        supports_webp: env["HTTP_ACCEPT"]&.include?("image/webp")
      }
    end

    def detect_device_type(user_agent)
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

    def analyze_browser_capabilities(env)
      user_agent = env["HTTP_USER_AGENT"] || ""
      capabilities = {}
      
      capabilities[:supports_es6] = supports_es6?(user_agent)
      capabilities[:supports_css_grid] = supports_css_grid?(user_agent)
      capabilities[:supports_webp] = env["HTTP_ACCEPT"]&.include?("image/webp")
      capabilities[:supports_brotli] = env["HTTP_ACCEPT_ENCODING"]&.include?("br")
      capabilities[:modern_browser] = modern_browser?(user_agent)
      
      capabilities
    end

    def parse_content_preferences(accept_header)
      return [] if accept_header.blank?
      
      preferences = []
      accept_header.split(",").each do |type_spec|
        type_spec = type_spec.strip
        parts = type_spec.split(";")
        mime_type = parts[0].strip
        
        quality = 1.0
        parts[1..-1].each do |param|
          if param.strip.start_with?("q=")
            quality = param.split("=")[1].to_f rescue 1.0
          end
        end
        
        preferences << { type: mime_type, quality: quality }
      end
      
      preferences.sort_by { |p| -p[:quality] }
    end

    def supports_es6?(user_agent)
      return false if user_agent.blank?
      
      if user_agent =~ /Chrome\/(\d+)/
        $1.to_i >= 51
      elsif user_agent =~ /Firefox\/(\d+)/
        $1.to_i >= 54
      elsif user_agent =~ /Safari\/(\d+)/ && user_agent =~ /Version\/(\d+)/
        $1.to_i >= 10
      else
        false
      end
    end

    def supports_css_grid?(user_agent)
      return false if user_agent.blank?
      
      if user_agent =~ /Chrome\/(\d+)/
        $1.to_i >= 57
      elsif user_agent =~ /Firefox\/(\d+)/
        $1.to_i >= 52
      elsif user_agent =~ /Safari\/(\d+)/ && user_agent =~ /Version\/(\d+)/
        $1.to_i >= 10
      else
        false
      end
    end

    def modern_browser?(user_agent)
      return false if user_agent.blank?
      
      supports_es6?(user_agent) && supports_css_grid?(user_agent)
    end

    def should_optimize_response?(status, headers, context)
      status == 200 && 
      headers["Content-Type"]&.include?("text/html") &&
      !context[:is_mobile] # Focus optimization on desktop for now
    end

    def optimize_response_body(response, context)
      # Enhanced response body optimization based on client capabilities
      body_parts = []
      response.each { |part| body_parts << part }
      optimized_body = body_parts.join
      
      if context[:browser_capabilities][:modern_browser]
        optimized_body = inject_modern_assets(optimized_body)
      end
      
      if context[:supports_webp]
        optimized_body = replace_image_formats(optimized_body)
      end
      
      [optimized_body]
    end

    def optimize_response_headers(headers, context)
      optimized_headers = headers.dup
      
      # Add performance hints based on client capabilities
      if context[:browser_capabilities][:modern_browser]
        optimized_headers["X-Modern-Browser"] = "true"
      end
      
      if context[:compression_support]
        optimized_headers["Vary"] = [optimized_headers["Vary"], "Accept-Encoding"].compact.join(", ")
      end
      
      optimized_headers
    end

    def inject_modern_assets(body)
      # Inject modern JavaScript and CSS for capable browsers
      modern_script = '<script src="/assets/modern-bundle.js" defer></script>'
      modern_style = '<link rel="stylesheet" href="/assets/modern-styles.css">'
      
      body.gsub("</head>", "#{modern_style}\n#{modern_script}\n</head>")
    end

    def replace_image_formats(body)
      # Replace image formats with WebP for supporting browsers
      body.gsub(/src="([^"]+\.(jpg|jpeg|png))"/, 'src="\1.webp"')
    end
  end
end