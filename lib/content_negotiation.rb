# frozen_string_literal: true

module ContentNegotiation
  SUPPORTED_MIME_TYPES = %w[
    text/html
    application/json
    application/xml
    text/xml
    text/plain
    application/rss+xml
    application/atom+xml
  ].freeze

  MOBILE_PREFERENCES = %w[
    application/vnd.wap.xhtml+xml
    application/xhtml+xml
    text/html
  ].freeze

  class << self
    def best_content_type(accept_header, available_types = SUPPORTED_MIME_TYPES)
      return available_types.first if accept_header.blank?

      parsed_types = parse_accept_header(accept_header)
      
      parsed_types.each do |type_info|
        mime_type = type_info[:type]
        if available_types.include?(mime_type)
          return mime_type
        end
      end

      available_types.first
    end

    def mobile_optimized_type(accept_header, user_agent = nil)
      return MOBILE_PREFERENCES.first if accept_header.blank?

      parsed_types = parse_accept_header(accept_header)
      
      parsed_types.each do |type_info|
        mime_type = type_info[:type]
        if MOBILE_PREFERENCES.include?(mime_type)
          return mime_type
        end
      end

      MOBILE_PREFERENCES.first
    end

    private

    def parse_accept_header(accept_header)
      types = []
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
        
        types << { type: mime_type, quality: quality }
      end
      
      types.sort_by { |t| -t[:quality] }
    end
  end
end