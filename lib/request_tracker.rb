# frozen_string_literal: true

class RequestTracker
  # Enhanced request tracking with performance metrics
  
  def self.track_request(env)
    return if env["discourse.request_tracker.skip"]
    
    # Extract enhanced client information for performance analysis
    client_info = extract_client_info(env)
    request_metrics = calculate_request_metrics(env, client_info)
    
    # Log performance data for analysis
    log_performance_metrics(request_metrics) if should_log_metrics?
  end

  def self.extract_client_info(env)
    {
      user_agent: env["HTTP_USER_AGENT"],
      accept_header: env["HTTP_ACCEPT"],
      accept_encoding: env["HTTP_ACCEPT_ENCODING"],
      accept_language: env["HTTP_ACCEPT_LANGUAGE"],
      host: env["HTTP_HOST"],
      referer: env["HTTP_REFERER"],
      ip: env["REMOTE_ADDR"],
      method: env["REQUEST_METHOD"],
      uri: env["REQUEST_URI"],
      xhr: env["HTTP_X_REQUESTED_WITH"]&.casecmp("XMLHttpRequest") == 0
    }
  end

  def self.calculate_request_metrics(env, client_info)
    metrics = {
      timestamp: Time.current,
      client_fingerprint: generate_client_fingerprint(client_info),
      cache_key_length: estimate_cache_key_length(env),
      device_classification: classify_device(client_info[:user_agent]),
      content_negotiation_complexity: assess_content_complexity(client_info[:accept_header])
    }
    
    metrics[:performance_risk] = assess_performance_risk(metrics)
    metrics
  end

  def self.generate_client_fingerprint(client_info)
    # Create comprehensive client fingerprint for analytics
    fingerprint_data = [
      client_info[:user_agent],
      client_info[:accept_header],
      client_info[:accept_encoding],
      client_info[:accept_language]
    ].compact.join("|")
    
    Digest::SHA256.hexdigest(fingerprint_data)[0..16]
  end

  def self.estimate_cache_key_length(env)
    # Estimate potential cache key length including headers
    base_length = "ANON_CACHE_".length
    base_length += (env["HTTP_ACCEPT"] || "").length
    base_length += (env["HTTP_HOST"] || "").length  
    base_length += (env["REQUEST_URI"] || "").length
    base_length += 20 # Additional segments
    
    base_length
  end

  def self.classify_device(user_agent)
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

  def self.assess_content_complexity(accept_header)
    return :simple if accept_header.blank?
    
    mime_types = accept_header.split(",").length
    total_length = accept_header.length
    
    if total_length > 500 || mime_types > 10
      :high
    elsif total_length > 200 || mime_types > 5
      :medium
    else
      :simple
    end
  end

  def self.assess_performance_risk(metrics)
    risk_score = 0
    
    # Cache key length risk
    risk_score += 3 if metrics[:cache_key_length] > 1000
    risk_score += 2 if metrics[:cache_key_length] > 500
    risk_score += 1 if metrics[:cache_key_length] > 250
    
    # Content complexity risk
    risk_score += 2 if metrics[:content_negotiation_complexity] == :high
    risk_score += 1 if metrics[:content_negotiation_complexity] == :medium
    
    case risk_score
    when 0..1 then :low
    when 2..3 then :medium
    when 4..5 then :high
    else :critical
    end
  end

  def self.log_performance_metrics(metrics)
    Rails.logger.info("[RequestTracker] Performance metrics: #{metrics.to_json}")
  end

  def self.should_log_metrics?
    # Only log in development or when specifically enabled
    Rails.env.development? || GlobalSetting.enable_request_performance_logging
  end
end