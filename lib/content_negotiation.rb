class ContentNegotiation
  
  def self.best_content_type(request_env, available_types = ['text/html', 'application/json'])
    accept_header = request_env["HTTP_ACCEPT"]
    return available_types.first unless accept_header
    
    accepted_types = parse_accept_header(accept_header)
    
    # Find the best matching content type based on quality scores
    best_match = nil
    best_quality = 0
    
    available_types.each do |available|
      accepted_types.each do |accepted|
        if content_type_matches?(available, accepted[:type])
          if accepted[:quality] > best_quality
            best_match = available
            best_quality = accepted[:quality]
          end
        end
      end
    end
    
    best_match || available_types.first
  end
  
  def self.parse_accept_header(accept_header)
    types = []
    accept_header.split(',').each do |type_string|
      parts = type_string.strip.split(';')
      media_type = parts[0].strip
      
      quality = 1.0
      parts[1..-1].each do |param|
        if param.strip.start_with?('q=')
          quality = param.strip[2..-1].to_f
          break
        end
      end
      
      types << { type: media_type, quality: quality }
    end
    
    types.sort_by { |t| -t[:quality] }
  end
  
  def self.content_type_matches?(available, requested)
    return true if available == requested
    return true if requested == '*/*'
    return true if requested.end_with?('/*') && available.start_with?(requested[0..-3])
    false
  end
  
  def self.supports_compression?(request_env)
    encoding = request_env["HTTP_ACCEPT_ENCODING"]
    return false unless encoding
    
    encodings = encoding.split(',').map(&:strip)
    encodings.any? { |enc| enc.match(/gzip|deflate/) }
  end
  
end