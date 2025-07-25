# frozen_string_literal: true

class ApiContentNegotiation
  # Advanced API content negotiation for improved client experience
  
  SUPPORTED_API_FORMATS = %w[
    application/json
    application/xml
    text/xml
    application/vnd.api+json
    application/hal+json
    text/plain
    text/csv
  ].freeze

  MOBILE_API_PREFERENCES = %w[
    application/json
    text/plain
  ].freeze

  class << self
    def negotiate_content_type(request)
      accept_header = request.headers["Accept"]
      user_agent = request.headers["User-Agent"]
      
      return default_content_type if accept_header.blank?
      
      # Enhanced content negotiation with mobile optimization
      if mobile_client?(user_agent)
        negotiate_mobile_content(accept_header)
      else
        negotiate_desktop_content(accept_header)
      end
    end

    def analyze_api_client_capabilities(request)
      {
        accept_header: request.headers["Accept"],
        user_agent: request.headers["User-Agent"],
        supports_compression: supports_compression?(request),
        preferred_format: negotiate_content_type(request),
        client_type: determine_client_type(request),
        api_version_preference: extract_api_version(request),
        supports_pagination: supports_pagination?(request),
        bandwidth_preference: assess_bandwidth_preference(request)
      }
    end

    def optimize_response_for_client(data, capabilities)
      format = capabilities[:preferred_format]
      client_type = capabilities[:client_type]
      
      optimized_data = data.dup
      
      case client_type
      when :mobile
        optimized_data = optimize_for_mobile(optimized_data)
      when :api_client
        optimized_data = optimize_for_api_client(optimized_data)
      when :webhook
        optimized_data = optimize_for_webhook(optimized_data)
      end
      
      serialize_response(optimized_data, format)
    end

    private

    def default_content_type
      "application/json"
    end

    def mobile_client?(user_agent)
      return false if user_agent.blank?
      user_agent.match?(/Mobile|Android|iPhone|iPad/i)
    end

    def negotiate_mobile_content(accept_header)
      preferences = parse_accept_header(accept_header)
      
      preferences.each do |pref|
        return pref[:type] if MOBILE_API_PREFERENCES.include?(pref[:type])
      end
      
      MOBILE_API_PREFERENCES.first
    end

    def negotiate_desktop_content(accept_header)
      preferences = parse_accept_header(accept_header)
      
      preferences.each do |pref|
        return pref[:type] if SUPPORTED_API_FORMATS.include?(pref[:type])
      end
      
      default_content_type
    end

    def parse_accept_header(accept_header)
      preferences = []
      
      accept_header.split(",").each do |type_spec|
        type_spec = type_spec.strip
        parts = type_spec.split(";")
        mime_type = parts[0].strip
        
        quality = 1.0
        parameters = {}
        
        parts[1..-1].each do |param|
          param = param.strip
          if param.start_with?("q=")
            quality = param.split("=")[1].to_f rescue 1.0
          else
            key, value = param.split("=", 2)
            parameters[key] = value if key && value
          end
        end
        
        preferences << {
          type: mime_type,
          quality: quality,
          parameters: parameters
        }
      end
      
      preferences.sort_by { |p| [-p[:quality], p[:type]] }
    end

    def supports_compression?(request)
      encoding = request.headers["Accept-Encoding"]
      return false if encoding.blank?
      
      encoding.include?("gzip") || encoding.include?("deflate") || encoding.include?("br")
    end

    def determine_client_type(request)
      user_agent = request.headers["User-Agent"] || ""
      
      return :webhook if webhook_client?(user_agent)
      return :mobile if mobile_client?(user_agent)
      return :api_client if api_client?(user_agent)
      return :browser if browser_client?(user_agent)
      
      :unknown
    end

    def webhook_client?(user_agent)
      user_agent.match?(/webhook|bot|crawler/i)
    end

    def api_client?(user_agent)
      user_agent.match?(/curl|postman|insomnia|httpie|rest|api/i)
    end

    def browser_client?(user_agent)
      user_agent.match?(/Mozilla|Chrome|Safari|Firefox|Edge/i)
    end

    def extract_api_version(request)
      # Check various API version indicators
      version = request.headers["API-Version"] ||
                request.headers["X-API-Version"] ||
                request.params["api_version"]
      
      return version if version.present?
      
      # Extract from Accept header
      accept = request.headers["Accept"]
      if accept&.include?("version=")
        match = accept.match(/version=([^;,]+)/)
        return match[1] if match
      end
      
      nil
    end

    def supports_pagination?(request)
      # Check if client supports pagination headers
      accept = request.headers["Accept"]
      return true if accept&.include?("application/vnd.api+json")
      return true if request.headers["Accept-Ranges"].present?
      
      false
    end

    def assess_bandwidth_preference(request)
      user_agent = request.headers["User-Agent"] || ""
      
      # Mobile clients typically prefer minimal bandwidth
      return :minimal if mobile_client?(user_agent)
      
      # API clients usually want complete data
      return :complete if api_client?(user_agent)
      
      # Webhook clients need efficient data
      return :efficient if webhook_client?(user_agent)
      
      :standard
    end

    def optimize_for_mobile(data)
      # Reduce data payload for mobile clients
      optimized = data.dup
      
      # Remove unnecessary fields for mobile
      if optimized.is_a?(Hash)
        optimized.delete("debug_info")
        optimized.delete("admin_fields") unless admin_request?
        optimized["meta"]&.delete("detailed_stats")
      elsif optimized.is_a?(Array)
        optimized.map! { |item| optimize_for_mobile(item) if item.is_a?(Hash) }
      end
      
      optimized
    end

    def optimize_for_api_client(data)
      # API clients usually want complete, structured data
      optimized = data.dup
      
      # Add API-specific metadata
      if optimized.is_a?(Hash)
        optimized["_api_metadata"] = {
          version: "v1",
          timestamp: Time.current.iso8601,
          format: "application/json"
        }
      end
      
      optimized
    end

    def optimize_for_webhook(data)
      # Webhook clients need efficient, minimal data
      optimized = data.dup
      
      # Focus on essential data for webhooks
      if optimized.is_a?(Hash)
        essential_keys = %w[id type action timestamp data]
        optimized = optimized.slice(*essential_keys)
      end
      
      optimized
    end

    def serialize_response(data, format)
      case format
      when "application/json", "application/vnd.api+json", "application/hal+json"
        JSON.pretty_generate(data)
      when "application/xml", "text/xml"
        data.to_xml
      when "text/csv"
        convert_to_csv(data)
      when "text/plain"
        data.to_s
      else
        JSON.pretty_generate(data)
      end
    end

    def convert_to_csv(data)
      return "" unless data.is_a?(Array) && data.first.is_a?(Hash)
      
      headers = data.first.keys
      csv_data = [headers.join(",")]
      
      data.each do |row|
        csv_data << headers.map { |h| row[h] }.join(",")
      end
      
      csv_data.join("\n")
    end

    def admin_request?
      # This would normally check current user permissions
      false
    end
  end
end